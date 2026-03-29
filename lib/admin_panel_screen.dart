import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:firebase_storage/firebase_storage.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  _AdminPanelScreenState createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- Funcionalidades de Administración ---

  Future<void> _deactivateUser(String userId, bool isActive) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isActive': isActive,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usuario actualizado. Activo: $isActive')),
      );
    } catch (e) {
      print('Error al desactivar usuario: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar usuario: $e')),
      );
    }
  }

  Future<void> _toggleOfferVisibility(String offerId, bool isHidden) async {
    try {
      await FirebaseFirestore.instance.collection('offers').doc(offerId).update(
        {'isHidden': isHidden},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Oferta actualizada. Oculta: $isHidden')),
      );
    } catch (e) {
      print('Error al actualizar oferta: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al actualizar oferta: $e')));
    }
  }

  Future<void> _deleteOffer(String offerId, String imageUrl) async {
    try {
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(offerId)
          .delete();

      if (imageUrl.isNotEmpty) {
        //final storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
        //await storageRef.delete();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oferta eliminada permanentemente.')),
      );
    } catch (e) {
      print('Error al eliminar oferta: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar oferta: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel de Administración'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Usuarios'),
              Tab(icon: Icon(Icons.food_bank), text: 'Ofertas'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar Sesión (Admin)',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar por nombre o email',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [_buildUsersList(), _buildOffersList()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs.where((doc) {
          final userData = doc.data() as Map<String, dynamic>;
          final name = userData['name']?.toString().toLowerCase() ?? '';
          final email = userData['email']?.toString().toLowerCase() ?? '';
          return name.contains(_searchQuery) || email.contains(_searchQuery);
        }).toList();

        if (users.isEmpty) {
          return const Center(child: Text('No se encontraron usuarios.'));
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            var userDoc = users[index];
            var userData = userDoc.data() as Map<String, dynamic>;
            final userId = userDoc.id;
            final isActive = userData['isActive'] as bool? ?? true;

            return ListTile(
              leading: CircleAvatar(
                child: Text(
                  userData['name']?.isNotEmpty == true
                      ? userData['name'].substring(0, 1)
                      : 'U',
                ),
              ),
              title: Text(userData['username'] ?? 'Usuario sin nombre'),
              subtitle: Text(userData['email'] ?? 'Sin email'),
              trailing: IconButton(
                icon: Icon(
                  isActive ? Icons.person_off : Icons.person_add,
                  color: isActive ? Colors.red : Colors.green,
                ),
                tooltip: isActive ? 'Desactivar Usuario' : 'Activar Usuario',
                onPressed: () => _deactivateUser(userId, !isActive),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOffersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('offers').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final offers = snapshot.data!.docs.where((doc) {
          final offerData = doc.data() as Map<String, dynamic>;
          final title = offerData['title']?.toString().toLowerCase() ?? '';
          final description =
              offerData['description']?.toString().toLowerCase() ?? '';
          return title.contains(_searchQuery) ||
              description.contains(_searchQuery);
        }).toList();

        if (offers.isEmpty) {
          return const Center(child: Text('No se encontraron ofertas.'));
        }

        return ListView.builder(
          itemCount: offers.length,
          itemBuilder: (context, index) {
            var offerDoc = offers[index];
            var offerData = offerDoc.data() as Map<String, dynamic>;
            final offerId = offerDoc.id;
            final isHidden = offerData['isHidden'] as bool? ?? false;

            return ListTile(
              leading: offerData['imageUrl'] != null
                  ? Image.network(
                      offerData['imageUrl'],
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (c, o, s) =>
                          const Icon(Icons.image_not_supported, size: 50),
                    )
                  : const Icon(Icons.fastfood, size: 50),
              title: Text(offerData['title'] ?? 'Oferta sin título'),
              subtitle: Text('Por: ${offerData['userId'] ?? 'Anónimo'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isHidden ? Icons.visibility_off : Icons.visibility,
                      color: isHidden ? Colors.orange : Colors.blue,
                    ),
                    tooltip: isHidden ? 'Mostrar Oferta' : 'Ocultar Oferta',
                    onPressed: () => _toggleOfferVisibility(offerId, !isHidden),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    tooltip: 'Eliminar permanentemente',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Confirmar Eliminación'),
                            content: const Text(
                              '¿Estás seguro de que quieres eliminar esta oferta permanentemente? Esta acción no se puede deshacer.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () {
                                  _deleteOffer(
                                    offerId,
                                    offerData['imageUrl'] ?? '',
                                  );
                                  Navigator.of(context).pop();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
