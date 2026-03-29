// lib/category_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart'; 
import 'offer_detail_screen.dart'; 

class CategoryPage extends StatelessWidget {
  final String categoryName;
  final Position? userPosition; 
  
  const CategoryPage({
    super.key, 
    required this.categoryName, 
    this.userPosition, // Recibe la posición del usuario
  });

  static const double _maxDistanceKm = 50.0; 

  // Función auxiliar para formatear la distancia
  String _formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return 'A ${(distanceInKm * 1000).toStringAsFixed(0)} m';
    }
    return 'A ${distanceInKm.toStringAsFixed(1)} km';
  }
  
  // Función para construir la consulta a Firestore
  Stream<QuerySnapshot> _buildStreamQuery(FirebaseFirestore firestore) {
    Query query = firestore.collection('offers')
        .where('isActive', isEqualTo: true)
        // Ordenamos siempre por timestamp para mantener un orden, usando el índice compuesto.
        .orderBy('timestamp', descending: true);

    final lowerCaseCategory = categoryName.toLowerCase();

    // ✅ REGLA 1: Filtrar solo por categoría si NO es 'ubicación' ni 'todos'
    if (lowerCaseCategory != 'ubicación') {
      // Usamos el índice compuesto: isActive, category, timestamp
      query = query.where('category', isEqualTo: lowerCaseCategory);
    }
    
    // Si es 'ubicación' o 'todos', traemos todas las ofertas activas y las filtramos en el cliente.
    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final bool isLocationCategory = categoryName.toLowerCase() == 'ubicación';
    // La categoría 'Todos' no aplica el filtro de ubicación.
    final bool applyLocationFilter = isLocationCategory; 

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _buildStreamQuery(firestore), 
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data!.docs;

          // 🛑 LÓGICA CLAVE DE FILTRADO 🛑
          final filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            
            final num? latNum = data['latitude'] as num?;
            final num? lonNum = data['longitude'] as num?;
            
            final lat = latNum?.toDouble();
            final lon = lonNum?.toDouble();

            // CASO 1: El filtro de ubicación NO aplica para esta categoría ('Comida', 'Ropa', 'Todos')
            if (!applyLocationFilter) {
              return true; // Incluye todas las ofertas que ya filtró Firestore por categoría.
            }
            
            // A PARTIR DE AQUÍ, SOLO SE EJECUTA SI applyLocationFilter ES TRUE (es decir, Categoría 'Ubicación')
            
            // CASO 2: Categoría 'Ubicación', pero el usuario NO tiene posición.
            if (userPosition == null) {
               return false; // No mostramos nada en 'Ubicación' si no sabemos dónde está el usuario.
            }

            // CASO 3: Categoría 'Ubicación', pero la oferta NO tiene coordenadas.
            if (lat == null || lon == null) {
              return false; // Descartamos la oferta en la categoría 'Ubicación'.
            }
            
            // CASO 4: Ambos tienen ubicación. Aplicamos el filtro de distancia.
            final distanceInMeters = Geolocator.distanceBetween(
              userPosition!.latitude,
              userPosition!.longitude,
              lat,
              lon,
            );
            final distanceInKm = distanceInMeters / 1000;

            // Retorna solo si está dentro del radio de 50 km
            return distanceInKm <= _maxDistanceKm;
          }).toList();
          
          if (filteredDocs.isEmpty) {
            final String emptyMessage = isLocationCategory
                ? 'No hay ofertas activas cerca de ti (radio de ${_maxDistanceKm.toStringAsFixed(0)} km).'
                : 'No hay ofertas publicadas en la categoría ${categoryName}.';

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ),
            );
          }

          // Lista de ofertas filtradas
          return ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final offerId = doc.id;
              
              // Recalcular la distancia para mostrarla
              String distanceText = 'Ubicación no registrada';
              
              final num? offerLatNum = data['latitude'] as num?;
              final num? offerLonNum = data['longitude'] as num?;
              
              if (userPosition != null && offerLatNum != null && offerLonNum != null) {
                final distanceInMeters = Geolocator.distanceBetween(
                  userPosition!.latitude,
                  userPosition!.longitude,
                  offerLatNum.toDouble(),
                  offerLonNum.toDouble(),
                );
                distanceText = _formatDistance(distanceInMeters / 1000);
              } else if (!isLocationCategory) {
                 // Si NO es la categoría ubicación, no mostramos distancia si no la tenemos.
                 distanceText = 'Categoría: ${data['category']}'; 
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty
                      ? Image.network(
                          data['imageUrl'],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.image),
                  title: Text(data['title'] ?? 'Sin título'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        distanceText, 
                        style: TextStyle(
                          fontWeight: FontWeight.w500, 
                          color: Colors.deepPurple[400]
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    data['price'] != null ? '\$${data['price']}' : 'Gratis',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OfferDetailScreen(offerId: offerId),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}