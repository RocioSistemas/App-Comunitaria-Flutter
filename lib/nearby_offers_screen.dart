// lib/nearby_offers_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'utils/location_service.dart';
import 'offer_detail_screen.dart';

class NearbyOffersScreen extends StatefulWidget {
  final Position? userPosition;

  const NearbyOffersScreen({super.key, this.userPosition});

  @override
  State<NearbyOffersScreen> createState() => _NearbyOffersScreenState();
}

class _NearbyOffersScreenState extends State<NearbyOffersScreen> {
  Position? _userPosition;
  bool _isLoadingLocation = false;
  double _selectedDistanceKm = 10.0; // Distancia por defecto: 10 km

  // Opciones de distancia en km
  final List<double> _distanceOptions = [1, 5, 10, 20, 50, 100];

  @override
  void initState() {
    super.initState();
    _userPosition = widget.userPosition;

    // Si no se pasó la ubicación, intentar obtenerla
    if (_userPosition == null) {
      _loadUserLocation();
    }
  }

  Future<void> _loadUserLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final position = await LocationService.determinePosition();
      if (mounted) {
        setState(() {
          _userPosition = position;
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al obtener ubicación: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ofertas Cercanas',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.red,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Control de distancia
          _buildDistanceControl(),

          // Lista de ofertas
          Expanded(
            child: _buildOffersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceControl() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.my_location, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                'Radio de búsqueda: ${_selectedDistanceKm.toInt()} km',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Botones de distancia rápida
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _distanceOptions.map((distance) {
              final isSelected = _selectedDistanceKm == distance;
              return ChoiceChip(
                label: Text('${distance.toInt()} km'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedDistanceKm = distance);
                  }
                },
                selectedColor: Colors.red,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),

          // Slider para ajuste fino
          Row(
            children: [
              const Text('1 km', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _selectedDistanceKm,
                  min: 1,
                  max: 100,
                  divisions: 99,
                  activeColor: Colors.red,
                  label: '${_selectedDistanceKm.toInt()} km',
                  onChanged: (value) {
                    setState(() => _selectedDistanceKm = value);
                  },
                ),
              ),
              const Text('100 km', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOffersList() {
    // Mostrar cargando si aún no tenemos la ubicación
    if (_isLoadingLocation || _userPosition == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _isLoadingLocation
                  ? 'Obteniendo tu ubicación...'
                  : 'Ubicación no disponible',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (!_isLoadingLocation && _userPosition == null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: _loadUserLocation,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('isActive', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.red));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No hay ofertas disponibles'),
          );
        }

        // Filtrar ofertas por proximidad
        final nearbyOffers = snapshot.data!.docs.where((doc) {
          final offerData = doc.data() as Map<String, dynamic>;

          // Si la oferta no tiene coordenadas, no la mostramos
          final latitude = offerData['latitude'];
          final longitude = offerData['longitude'];

          if (latitude == null || longitude == null) {
            return false;
          }

          // Calcular distancia manualmente usando Geolocator
          final distanceInMeters = Geolocator.distanceBetween(
            _userPosition!.latitude,
            _userPosition!.longitude,
            (latitude as num).toDouble(),
            (longitude as num).toDouble(),
          );

          final distanceInKm = distanceInMeters / 1000;

          // Verificar si está dentro del radio
          return distanceInKm <= _selectedDistanceKm;
        }).toList();

        // Ordenar por distancia (más cercano primero)
        nearbyOffers.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;

          final distanceA = Geolocator.distanceBetween(
                _userPosition!.latitude,
                _userPosition!.longitude,
                (dataA['latitude'] as num).toDouble(),
                (dataA['longitude'] as num).toDouble(),
              ) /
              1000;

          final distanceB = Geolocator.distanceBetween(
                _userPosition!.latitude,
                _userPosition!.longitude,
                (dataB['latitude'] as num).toDouble(),
                (dataB['longitude'] as num).toDouble(),
              ) /
              1000;

          return distanceA.compareTo(distanceB);
        });

        if (nearbyOffers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay ofertas en un radio de ${_selectedDistanceKm.toInt()} km',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Intenta aumentar el radio de búsqueda',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: nearbyOffers.length,
          itemBuilder: (context, index) {
            final offerDoc = nearbyOffers[index];
            final offerData = offerDoc.data() as Map<String, dynamic>;

            final distance = Geolocator.distanceBetween(
                  _userPosition!.latitude,
                  _userPosition!.longitude,
                  (offerData['latitude'] as num).toDouble(),
                  (offerData['longitude'] as num).toDouble(),
                ) /
                1000; // Convertir a kilómetros

            return _OfferCard(
              offerId: offerDoc.id,
              title: offerData['title'] ?? 'Sin Título',
              description: offerData['description'] ?? 'Sin descripción',
              price: offerData['price']?.toString() ?? 'Gratis',
              imageUrl: offerData['imageUrl'],
              distanceKm: distance,
              category: offerData['category'] ?? '',
            );
          },
        );
      },
    );
  }
}

// Widget de tarjeta de oferta
class _OfferCard extends StatelessWidget {
  final String offerId;
  final String title;
  final String description;
  final String price;
  final String? imageUrl;
  final double distanceKm;
  final String category;

  const _OfferCard({
    required this.offerId,
    required this.title,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.distanceKm,
    required this.category,
  });

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'comida':
        return const Color(0xFFFF6B6B);
      case 'tecnología':
        return const Color(0xFF4E54C8);
      case 'ropa':
        return const Color(0xFF11998E);
      case 'hogar':
        return const Color(0xFFB06AB3);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OfferDetailScreen(offerId: offerId),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            Stack(
              children: [
                if (imageUrl != null && imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(15)),
                    child: Image.network(
                      imageUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey[300],
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image, size: 50),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(15)),
                    ),
                    alignment: Alignment.center,
                    child:
                        const Icon(Icons.image, size: 50, color: Colors.grey),
                  ),

                // Badge de categoría
                if (category.isNotEmpty)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(category),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                // Badge de distancia
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.near_me,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '${distanceKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Información
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        price == 'Gratis' ? '¡Gratis!' : '\$$price',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on,
                                size: 16, color: Colors.red),
                            const SizedBox(width: 4),
                            Text(
                              distanceKm < 1
                                  ? '${(distanceKm * 1000).toInt()} m'
                                  : '${distanceKm.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
