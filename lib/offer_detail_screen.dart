// lib/offer_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';
import 'chat_screen.dart';

class OfferDetailScreen extends StatefulWidget {
  final String offerId;

  const OfferDetailScreen({super.key, required this.offerId});

  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  bool _isLoading = false;

  // --- Funciones de Contacto ---

  Future<void> _sendEmail(String email, String offerTitle) async {
    try {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: email,
        query:
            'subject=Interesado en: $offerTitle&body=Hola, estoy interesado en tu oferta "$offerTitle". ¿Podemos hablar?',
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        throw 'No se pudo abrir el cliente de email.';
      }
    } catch (e) {
      debugPrint('❌ Error en _sendEmail: $e');
    }
  }

  Future<void> _openWhatsApp(String phone, String offerTitle) async {
    try {
      final cleanedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final message =
          'Hola, estoy interesado en tu oferta "$offerTitle" en Mercado Amigo.';
      final Uri whatsappUri = Uri.parse(
        'https://api.whatsapp.com/send?phone=$cleanedPhone&text=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir WhatsApp.';
      }
    } catch (e) {
      debugPrint('❌ Error en _openWhatsApp: $e');
    }
  }

  Color _getOfferTypeColor(String? offerType) {
    switch (offerType) {
      case 'Comida':
        return const Color(0xFFFF6B6B);
      case 'Tecnología':
        return const Color(0xFF4E54C8);
      case 'Ropa':
        return const Color(0xFF11998E);
      case 'Hogar':
        return const Color(0xFFB06AB3);
      case 'Gratis':
        return Colors.green;
      case 'Precio Sugerido':
        return Colors.blueAccent;
      case 'Intercambio':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _showLoginRequiredModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inicia Sesión'),
        content: const Text(
          'Necesitas iniciar sesión para contactar al vendedor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text('Iniciar Sesión'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleContact(
      BuildContext context, String recipientId, String offerTitle) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showLoginRequiredModal(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          recipientId: recipientId,
          recipientName: 'Vendedor',
        ),
      ),
    );
  }

  // ✅ NUEVAS FUNCIONES PARA GESTIÓN DE OFERTAS

  /// Marca la oferta como vendida/completada
  Future<void> _markAsSold() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como vendida'),
        content: const Text(
          '¿Confirmas que esta oferta ya fue vendida/completada?\n\nLa oferta se archivará y ya no será visible para otros usuarios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(widget.offerId)
          .update({
        'isActive': false,
        'status': 'sold',
        'completedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Oferta marcada como vendida'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Volver a la pantalla anterior
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Pausar/Reactivar oferta
  Future<void> _togglePauseOffer(bool currentlyActive) async {
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(widget.offerId)
          .update({
        'isActive': !currentlyActive,
        'status': currentlyActive ? 'paused' : 'active',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyActive
                  ? '⏸️ Oferta pausada (oculta para otros)'
                  : '▶️ Oferta reactivada',
            ),
            backgroundColor: currentlyActive ? Colors.orange : Colors.green,
          ),
        );
        setState(() {}); // Refrescar la pantalla
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Eliminar oferta permanentemente
  Future<void> _deleteOffer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar oferta'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar esta oferta?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(widget.offerId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Oferta eliminada'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Mostrar menú de opciones para el propietario
  void _showOwnerOptions(bool isActive) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Opciones de la oferta',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Marcar como vendida
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Marcar como vendida'),
              subtitle: const Text('La oferta se archivará'),
              onTap: () {
                Navigator.pop(ctx);
                _markAsSold();
              },
            ),

            const Divider(),

            // Pausar/Reactivar
            ListTile(
              leading: Icon(
                isActive ? Icons.pause_circle : Icons.play_circle,
                color: isActive ? Colors.orange : Colors.green,
              ),
              title: Text(isActive ? 'Pausar oferta' : 'Reactivar oferta'),
              subtitle: Text(
                isActive ? 'Ocultar temporalmente' : 'Hacer visible nuevamente',
              ),
              onTap: () {
                Navigator.pop(ctx);
                _togglePauseOffer(isActive);
              },
            ),

            const Divider(),

            // Eliminar
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Eliminar oferta'),
              subtitle: const Text('Acción permanente'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteOffer();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles de la Oferta'),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('offers')
                  .doc(widget.offerId)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error al cargar la oferta: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(
                    child: Text(
                      'La oferta no existe o fue eliminada.',
                      style: TextStyle(fontSize: 18, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final offerData = snapshot.data!.data() as Map<String, dynamic>;
                final String userId = offerData['userId'];
                final bool isActive = offerData['isActive'] ?? true;
                final String status = offerData['status'] ?? 'active';

                // ✅ Verificar si el usuario actual es el propietario
                final bool isOwner = currentUser?.uid == userId;

                final String title = offerData['title'] ?? 'Oferta Desconocida';
                final String description =
                    offerData['description'] ?? 'Sin descripción.';
                final String offerType = offerData['category'] ?? '';
                final String price = offerData['price']?.toString() ?? 'N/A';
                final String imageUrl = offerData['imageUrl'] ?? '';

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ Banner de estado (si está pausada o vendida)
                      if (!isActive || status == 'sold')
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          color: status == 'sold'
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                status == 'sold'
                                    ? Icons.check_circle
                                    : Icons.pause_circle,
                                color: status == 'sold'
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                status == 'sold'
                                    ? '✅ Esta oferta ya fue vendida'
                                    : '⏸️ Oferta pausada temporalmente',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: status == 'sold'
                                      ? Colors.green.shade900
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Imagen
                      if (imageUrl.isNotEmpty)
                        Image.network(
                          imageUrl,
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      else
                        Container(
                          height: 250,
                          color: Colors.grey[200],
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported,
                              size: 80, color: Colors.grey),
                        ),

                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tipo de Oferta
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getOfferTypeColor(offerType),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                offerType,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Título
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const Divider(height: 20),

                            // Precio
                            Row(
                              children: [
                                const Icon(Icons.monetization_on,
                                    color: Colors.green, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  price == 'Gratis' || price == '0'
                                      ? '¡Gratis!'
                                      : 'Precio: \$$price',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Descripción
                            Text(
                              'Descripción:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: const TextStyle(fontSize: 16, height: 1.5),
                            ),
                            const SizedBox(height: 30),

                            // ✅ BOTONES SEGÚN SEA PROPIETARIO O NO
                            if (isOwner)
                              _buildOwnerActions(isActive)
                            else
                              _buildContactSection(userId, title),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  /// Botones para el propietario de la oferta
  Widget _buildOwnerActions(bool isActive) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepPurple.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.person, color: Colors.deepPurple.shade700),
              const SizedBox(width: 8),
              Text(
                'Esta es tu oferta',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showOwnerOptions(isActive),
            icon: const Icon(Icons.settings),
            label: const Text(
              'Gestionar oferta',
              style: TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Sección de contacto para usuarios interesados
  Widget _buildContactSection(String userId, String title) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (userSnapshot.hasError ||
            !userSnapshot.hasData ||
            !userSnapshot.data!.exists) {
          return const Text(
              'Inicia sesion para contactar con el usuario.',
              style: TextStyle(color: Colors.red));
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final String sellerEmail = userData['email'] ?? '';
        final String sellerPhone = userData['phone'] ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contactar al ofertante:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (FirebaseAuth.instance.currentUser == null) {
                        _showLoginRequiredModal(context);
                      } else if (sellerEmail.isNotEmpty) {
                        _sendEmail(sellerEmail, title);
                      }
                    },
                    icon: const Icon(Icons.email),
                    label: const Text('Email'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (FirebaseAuth.instance.currentUser == null) {
                        _showLoginRequiredModal(context);
                      } else if (sellerPhone.isNotEmpty) {
                        _openWhatsApp(sellerPhone, title);
                      }
                    },
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
