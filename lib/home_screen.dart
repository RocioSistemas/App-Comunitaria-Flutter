// lib/home_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Nuevos Imports
import 'package:geolocator/geolocator.dart';
import 'utils/location_service.dart';
// Importaciones de otras pantallas
import 'post_offer_screen.dart';
import 'login_screen.dart';
import 'offer_detail_screen.dart';
import 'admin_panel_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isAdmin = false;

  // ESTADO DE UBICACIÓN
  Position? _userPosition;
  bool _isLocationLoaded = false;

  // Distancia máxima de filtro (en kilómetros)
  final double _maxDistanceKm = 50.0;

  // Lista de categorías que coinciden con los filtros en Firestore
  final List<String> categories = [
    'Comida',
    'Tecnología',
    'Ropa',
    'Hogar',
    'Todos'
  ];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Inicializar el TabController con la cantidad de categorías
    _tabController = TabController(length: categories.length, vsync: this);

    // 🛑 NUEVO: Cargar la ubicación del usuario al iniciar
    _loadUserLocation();

    // Escuchar cambios en la autenticación para verificar el rol de administrador
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _checkIfAdmin(user.uid);
      } else {
        setState(() => _isAdmin = false);
      }
    });
  }

  Future<void> _loadUserLocation() async {
    try {
      // Usamos el servicio para verificar permisos y obtener la posición
      final position = await LocationService.determinePosition();
      if (!mounted) return;
      setState(() {
        _userPosition = position;
        _isLocationLoaded = true;
      });
      print(
          '✅ Ubicación del usuario cargada: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLocationLoaded =
            true; // Permite que la pantalla se cargue incluso con error
      });
      // Puedes mostrar un SnackBar aquí si quieres notificar al usuario que no se pudo obtener la ubicación
      print('❌ Error al cargar ubicación: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // === LÓGICA DE FIREBASE / ADMIN
  // ===========================================================================

  Future<void> _checkIfAdmin(String uid) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data()?['role'] == 'admin') {
        setState(() => _isAdmin = true);
      } else {
        setState(() => _isAdmin = false);
      }
    } catch (e) {
      print('Error al verificar el rol de administrador: $e');
      setState(() => _isAdmin = false);
    }
  }

  void _navigateToPostOfferScreen() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Si no está logueado, lo enviamos al login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Debes iniciar sesión para publicar una oferta.')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else {
      // Si está logueado, lo enviamos a la pantalla de publicación
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PostOfferScreen()),
      );
    }
  }

  void _navigateToAdminPanel() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
    );
  }

  // ===========================================================================
  // === WIDGETS DE RENDERIZADO
  // ===========================================================================

  // Construye el cuerpo del TabBarView (una lista de ofertas por categoría)
  Widget _buildCategoryContent(String categoryName) {
    // 🛑 1. MOSTRAR CARGANDO MIENTRAS SE OBTIENE LA UBICACIÓN
    if (!_isLocationLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    // ✅ CORRECCIÓN: Construir la consulta correctamente
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('offers')
        .where('isActive', isEqualTo: true); // Filtrar por ofertas activas

    // ✅ CORRECCIÓN PRINCIPAL: Convertir a minúsculas antes de buscar
    if (categoryName != 'Todos') {
      query = query.where('category', isEqualTo: categoryName.toLowerCase());
    }

    // Ordenar por timestamp
    query = query.orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Text('No hay ofertas en "$categoryName" por el momento.'));
        }

        // 🛑 2. FILTRADO POR PROXIMIDAD EN EL CLIENTE
        final filteredDocs = snapshot.data!.docs.where((doc) {
          final offerData = doc.data() as Map<String, dynamic>;

          // Si no se pudo obtener la ubicación del usuario, o la oferta no tiene coordenadas, la mostramos.
          if (_userPosition == null ||
              offerData['latitude'] == null ||
              offerData['longitude'] == null) {
            return true;
          }

          // Calcular la distancia
          final double distanceInMeters = Geolocator.distanceBetween(
            _userPosition!.latitude,
            _userPosition!.longitude,
            offerData['latitude'] as double,
            offerData['longitude'] as double,
          );

          // Convertir a kilómetros y verificar si está dentro del radio (_maxDistanceKm)
          final double distanceInKm = distanceInMeters / 1000;

          return distanceInKm <= _maxDistanceKm;
        }).toList();

        // Si después del filtro no quedan documentos
        if (filteredDocs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'No hay ofertas en "$categoryName" en un radio de ${_maxDistanceKm.toInt()} km.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          );
        }

        // ✅ CORRECCIÓN PRINCIPAL: Usar filteredDocs en lugar de docs
        return ListView.builder(
          itemCount: filteredDocs.length, // ✅ CAMBIADO: era docs.length
          itemBuilder: (context, index) {
            final offerDoc = filteredDocs[index]; // ✅ CAMBIADO: era docs[index]
            final offerData = offerDoc.data() as Map<String, dynamic>;

            // 🛑 3. CALCULAR DISTANCIA FINAL PARA MOSTRAR EN LA TARJETA
            double? distanceKm;
            if (_userPosition != null && offerData['latitude'] != null) {
              final distMeters = Geolocator.distanceBetween(
                _userPosition!.latitude,
                _userPosition!.longitude,
                offerData['latitude'] as double,
                offerData['longitude'] as double,
              );
              distanceKm = distMeters / 1000;
            }

            return _OfferCard(
              offerId: offerDoc.id,
              title: offerData['title'] ?? 'Sin Título',
              description: offerData['description'] ?? 'Sin descripción.',
              price: offerData['price']?.toString() ?? 'Gratis',
              imageUrl: offerData['imageUrl'],
              distanceKm: distanceKm,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mercado Amigo',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        // Botón para panel de administrador
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
              onPressed: _navigateToAdminPanel,
              tooltip: 'Panel de Administrador',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: categories.map((category) => Tab(text: category)).toList(),
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        children: categories.map((category) {
          return _buildCategoryContent(category);
        }).toList(),
      ),

      // Botón flotante para publicar oferta
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToPostOfferScreen,
        label: const Text(
          'Publicar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
        backgroundColor: Colors.deepPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}

// ===========================================================================
// === WIDGET AUXILIAR: TARJETA DE OFERTA
// ===========================================================================

class _OfferCard extends StatelessWidget {
  final String offerId;
  final String title;
  final String description;
  final String price;
  final String? imageUrl;
  final double? distanceKm;

  const _OfferCard({
    required this.offerId,
    required this.title,
    required this.description,
    required this.price,
    this.imageUrl,
    this.distanceKm,
  });

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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen de la Oferta
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
                color: Colors.grey[200],
                alignment: Alignment.center,
                child: const Icon(Icons.image, size: 50, color: Colors.grey),
              ),

            // Detalles del Texto
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
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Precio: ${price == 'Gratis' ? price : '\$$price'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ✅ Mostrar la distancia
                  if (distanceKm != null)
                    Row(
                      children: [
                        const Icon(Icons.near_me,
                            size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 4),
                        Text(
                          'A ${distanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    )
                  else
                    const Text(
                      'Ubicación no disponible',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
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
