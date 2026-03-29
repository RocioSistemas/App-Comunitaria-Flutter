import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
//import 'offer_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:mi_app_flutter/models/user_model.dart';
import 'package:mi_app_flutter/edit_profile_screen.dart';
import 'edit_offer_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _firebaseUser;
  UserModel? _appUser;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _firebaseUser = _auth.currentUser;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    if (_firebaseUser != null) {
      _loadUserData();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (_firebaseUser == null) return;

    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(_firebaseUser!.uid).get();
      if (userDoc.exists) {
        setState(() {
          _appUser = UserModel.fromFirestore(userDoc);
          if (_appUser!.username == null || _appUser!.username!.isEmpty) {
            _appUser = UserModel(
              uid: _appUser!.uid,
              email: _appUser!.email,
              username: _firebaseUser!.email?.split('@')[0],
              fullName: _appUser!.fullName,
              bio: _appUser!.bio,
              photoUrl: _appUser!.photoUrl,
              createdAt: _appUser!.createdAt,
            );
          }
        });
      } else {
        // SANEAR photoUrl antes de guardar
        final String? rawPhotoUrl = _firebaseUser!.photoURL;
        final String? cleanPhotoUrl = (rawPhotoUrl != null &&
                rawPhotoUrl.contains('googleusercontent.com/profile/picture/0'))
            ? null
            : rawPhotoUrl;

        final newUserData = UserModel(
          uid: _firebaseUser!.uid,
          email: _firebaseUser!.email ?? '',
          username:
              _firebaseUser!.displayName ?? _firebaseUser!.email?.split('@')[0],
          photoUrl: cleanPhotoUrl,
          createdAt: Timestamp.now(),
        );
        await _firestore
            .collection('users')
            .doc(_firebaseUser!.uid)
            .set(newUserData.toMap());
        setState(() {
          _appUser = newUserData;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al cargar tu información. Intenta de nuevo.'),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _auth.signOut();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteOffer(String offerId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Oferta'),
        content: const Text(
          '¿Estás seguro? Esta acción no se puede deshacer.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('offers').doc(offerId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oferta eliminada exitosamente.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_firebaseUser == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.deepPurple.shade300, Colors.deepPurple.shade600],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off, size: 80, color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  'No has iniciado sesión',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Iniciar Sesión',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ✅ VALIDACIÓN DE FOTO DE PERFIL
    final bool isPhotoUrlValid = (_appUser?.photoUrl != null &&
        _appUser!.photoUrl!.isNotEmpty &&
        !_appUser!.photoUrl!
            .contains('googleusercontent.com/profile/picture/0'));

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
        child: CustomScrollView(
          slivers: [
            // AppBar con gradiente
            SliverAppBar(
              expandedHeight: 100,
              floating: false,
              pinned: true,
              backgroundColor: Colors.deepPurple,
              flexibleSpace: const FlexibleSpaceBar(
                title: Text(
                  'Mi Perfil',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                centerTitle: false,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final bool? profileUpdated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditProfileScreen(currentUser: _appUser!),
                      ),
                    );
                    if (profileUpdated == true) {
                      _loadUserData();
                    }
                  },
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Sección de información del usuario
                  _buildProfileHeader(isPhotoUrlValid),
                  const SizedBox(height: 24),

                  // Título de ofertas
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_offer,
                          color: Colors.deepPurple.shade700,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Mis Ofertas Publicadas',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Lista de ofertas
                  _buildOffersList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isPhotoUrlValid) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar con validación de URL
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  backgroundImage: isPhotoUrlValid
                      ? NetworkImage(_appUser!.photoUrl!)
                      : null,
                  child: !isPhotoUrlValid
                      ? const Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.deepPurple,
                        )
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Nombre
          Text(
            _appUser?.fullName ??
                _appUser?.username ??
                _firebaseUser!.email?.split('@')[0] ??
                'Usuario',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Email
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _firebaseUser!.email ?? 'Correo no disponible',
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ),

          // Bio
          if (_appUser?.bio != null && _appUser!.bio!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _appUser!.bio!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ],

          // Fecha de registro
          if (_appUser?.createdAt != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.white60,
                ),
                const SizedBox(width: 6),
                Text(
                  'Miembro desde ${DateFormat('dd/MM/yyyy').format(_appUser!.createdAt!.toDate())}',
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Botón de cerrar sesión
          ElevatedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, size: 20),
            label: const Text(
              'Cerrar Sesión',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffersList() {
    return StreamBuilder<QuerySnapshot>(
      // ✅ CORRECCIÓN PRINCIPAL: Cambiar 'createdAt' por 'timestamp'
      stream: _firestore
          .collection('offers')
          .where('userId', isEqualTo: _firebaseUser!.uid)
          .orderBy('timestamp', descending: true) // ✅ CAMBIADO
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aún no has publicado ofertas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '¡Comparte algo con la comunidad!',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var ofertaDoc = snapshot.data!.docs[index];
            var oferta = ofertaDoc.data() as Map<String, dynamic>;

            return _buildOfferCard(ofertaDoc.id, oferta);
          },
        );
      },
    );
  }

  Widget _buildOfferCard(String offerId, Map<String, dynamic> oferta) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditOfferScreen(offerId: offerId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Imagen
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  oferta['imageUrl'] ?? 'https://via.placeholder.com/100',
                  height: 90,
                  width: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 90,
                    width: 90,
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.broken_image,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Información (✅ CORREGIDO: Agregado Expanded para evitar overflow)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      oferta['title'] ?? 'Oferta',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      oferta['description'] ?? 'Sin descripción',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        oferta['price'] != null
                            ? oferta['price'].toString()
                            : 'Gratis',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Menú de opciones
              PopupMenuButton<String>(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditOfferScreen(offerId: offerId),
                      ),
                    ).then((result) {
                      if (result == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Oferta actualizada')),
                        );
                      }
                    });
                  } else if (value == 'delete') {
                    _deleteOffer(offerId);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: Colors.blue,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text('Eliminar'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
