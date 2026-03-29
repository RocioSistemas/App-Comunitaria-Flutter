// lib/menu_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'category_page.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'post_offer_screen.dart';
import 'admin_panel_screen.dart';
import 'nearby_offers_screen.dart'; // ✅ NUEVO IMPORT
import 'package:geolocator/geolocator.dart';

class MenuPage extends StatefulWidget {
  final Position? userPosition;

  const MenuPage({super.key, this.userPosition});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isAdmin = false;
  late final StreamSubscription<User?> _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _authStateSubscription =
        FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _checkIfAdmin(user.uid);
      } else {
        setState(() => _isAdmin = false);
      }
    });
  }

  Future<void> _checkIfAdmin(String uid) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data()?['role'] == 'admin') {
        if (mounted) {
          setState(() => _isAdmin = true);
        }
      } else {
        if (mounted) {
          setState(() => _isAdmin = false);
        }
      }
    } catch (e) {
      print('Error al verificar admin: $e');
      if (mounted) {
        setState(() => _isAdmin = false);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _authStateSubscription.cancel();
    super.dispose();
  }

  final List<Map<String, dynamic>> categories = const [
    {
      'name': 'Comida',
      'icon': Icons.restaurant_menu,
      'gradient': [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
      'description': 'Alimentos y bebidas',
      'color': Color(0xFFFF6B6B),
    },
    {
      'name': 'Tecnología',
      'icon': Icons.devices,
      'gradient': [Color(0xFF4E54C8), Color(0xFF8F94FB)],
      'description': 'Electrónica y gadgets',
      'color': Color(0xFF4E54C8),
    },
    {
      'name': 'Ropa',
      'icon': Icons.checkroom,
      'gradient': [Color(0xFF11998E), Color(0xFF38EF7D)],
      'description': 'Moda y accesorios',
      'color': Color(0xFF11998E),
    },
    {
      'name': 'Hogar',
      'icon': Icons.home,
      'gradient': [Color(0xFFB06AB3), Color(0xFF4568DC)],
      'description': 'Muebles y decoración',
      'color': Color(0xFFB06AB3),
    },
    {
      'name': 'Ubicación',
      'icon': Icons.location_on,
      'description': 'Ofertas cercanas',
      'gradient': [Colors.red, Color(0xFFFD7E14)],
      'color': Colors.red
    },
    {
      'name': 'Administracion',
      'icon': Icons.people,
      'description': 'Administrar usuarios',
      'gradient': [Colors.deepPurple, Color(0xFF8A2BE2)],
      'color': Colors.deepPurple,
      'admin_only': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final List<Map<String, dynamic>> visibleCategories =
        categories.where((category) {
      final bool isAdminOnly =
          category.containsKey('admin_only') && category['admin_only'] == true;
      return !isAdminOnly || _isAdmin;
    }).toList();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade50,
              Colors.white,
              Colors.green.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                floating: false,
                pinned: true,
                backgroundColor: Colors.deepPurple,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text(
                    'Mercado Amigo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: user == null
                        ? ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              ).then((_) => setState(() {}));
                            },
                            icon: const Icon(Icons.login, size: 18),
                            label: const Text('Iniciar Sesión'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.deepPurple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ProfileScreen(),
                                ),
                              ).then((_) => setState(() {}));
                            },
                            child: Row(
                              children: [
                                Text(
                                  user.displayName?.split(' ').first ??
                                      'Usuario',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white,
                                  backgroundImage: user.photoURL != null
                                      ? NetworkImage(user.photoURL!)
                                      : null,
                                  child: user.photoURL == null
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.deepPurple,
                                          size: 20,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildWelcomeCard(user),
                    const SizedBox(height: 24),
                    _buildPublishButton(context),
                    const SizedBox(height: 32),
                    const Text(
                      'Categorías',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCategoriesGrid(context, visibleCategories),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(User? user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user != null
                ? '¡Hola, ${user.displayName?.split(' ').first ?? 'Amigo'}!'
                : '¡Bienvenido!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Comparte, intercambia o vende productos de forma fácil y segura',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishButton(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PostOfferScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B6B).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_circle_outline,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Publicar Oferta',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '¿Tienes algo para compartir?',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid(
      BuildContext context, List<Map<String, dynamic>> categoriesToShow) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: categoriesToShow.length,
      itemBuilder: (context, index) {
        final category = categoriesToShow[index];
        final animation = Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              index * 0.1,
              1.0,
              curve: Curves.easeOutCubic,
            ),
          ),
        );

        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Transform.scale(
              scale: animation.value,
              child: Opacity(
                opacity: animation.value,
                child: child,
              ),
            );
          },
          child: _buildCategoryCard(context, category),
        );
      },
    );
  }

  Widget _buildCategoryCard(
      BuildContext context, Map<String, dynamic> category) {
    final List<Color> gradientColors = (category['gradient'] as List<Color>?) ??
        [Colors.grey, Colors.grey.shade300];

    return GestureDetector(
      onTap: () {
        switch (category['name']) {
          case 'Comida':
          case 'Tecnología':
          case 'Ropa':
          case 'Hogar':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryPage(
                  categoryName: category['name'] as String,
                  userPosition: widget.userPosition,
                ),
              ),
            );
            break;
          case 'Ubicación':
            // ✅ NAVEGAR A LA NUEVA PANTALLA DE OFERTAS CERCANAS
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NearbyOffersScreen(
                  userPosition: widget.userPosition,
                ),
              ),
            );
            break;
          case 'Administracion':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
            );
            break;
          default:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryPage(
                  categoryName: category['name'] as String,
                  userPosition: widget.userPosition,
                ),
              ),
            );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors[0].withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                category['icon'] as IconData,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              category['name'] as String,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                category['description'] as String? ?? 'Explora y descubre',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
