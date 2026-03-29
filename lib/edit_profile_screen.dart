import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:mi_app_flutter/models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel currentUser;

  const EditProfileScreen({super.key, required this.currentUser});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _fullNameController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  final supabase = Supabase.instance.client;

  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  String? _currentPhotoUrl; // URL actual (de Google o Supabase)

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.currentUser.username,
    );
    _fullNameController = TextEditingController(
      text: widget.currentUser.fullName,
    );
    _bioController = TextEditingController(text: widget.currentUser.bio);
    _phoneController = TextEditingController(
      text: widget.currentUser.phone,
    );

    // IMPORTANTE: Primero intenta usar la foto del modelo
    // Si no existe, usa la foto de Firebase Auth (de Google)
    _currentPhotoUrl =
        widget.currentUser.photoUrl ?? _auth.currentUser?.photoURL;

    print('📸 Foto cargada en initState: $_currentPhotoUrl');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _pickedImageBytes = bytes;
          _pickedImageName = image.name;
        });
        print('✅ Nueva imagen seleccionada: ${image.name}');
      }
    } catch (e) {
      print('❌ Error al seleccionar imagen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al seleccionar la imagen. Intenta de nuevo.'),
        ),
      );
    }
  }

  Future<String?> _uploadImage(String uid) async {
    if (_pickedImageBytes == null || _pickedImageName == null) return null;

    setState(() {
      _isLoading = true;
    });

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _pickedImageName!.split('.').last;
      final uniqueFileName = 'profile_${uid}_$timestamp.$extension';

      await supabase.storage.from('profile-images').uploadBinary(
            uniqueFileName,
            _pickedImageBytes!,
            fileOptions: FileOptions(contentType: 'image/$extension'),
          );

      final imageUrl =
          supabase.storage.from('profile-images').getPublicUrl(uniqueFileName);

      print('✅ Imagen subida a Supabase: $imageUrl');
      return imageUrl;
    } catch (e) {
      print('❌ Error al subir imagen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al subir la imagen. Intenta de nuevo.'),
        ),
      );
      return null;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile({bool restoreToGoogle = false}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? finalPhotoUrl = _currentPhotoUrl; // Mantiene la URL actual

      // << CLAVE: INICIO DEL ARREGLO PARA RESTAURAR A GOOGLE >>
      if (restoreToGoogle) {
        // Forzar el uso de la foto de Google desde Firebase Auth
        finalPhotoUrl = _auth.currentUser!.photoURL;

        // Opcional pero recomendado: Borrar la foto de Supabase Storage si existe
        // Esta lógica de borrado debe ser implementada si quieres liberar espacio.
        // Aquí asumo que la URL de Supabase contiene 'supabase.co'
        if (widget.currentUser.photoUrl != null &&
            widget.currentUser.photoUrl!.contains('supabase.co')) {
          // Lógica para borrar archivo de Supabase Storage si lo deseas.
        }
        print('✅ Restaurando foto a la de Google: $finalPhotoUrl');
      } else if (_pickedImageBytes != null) {
        // Caso: Subir nueva imagen
        final uploadedUrl = await _uploadImage(_auth.currentUser!.uid);
        if (uploadedUrl != null) {
          finalPhotoUrl = uploadedUrl;
          print('✅ Nueva foto de Supabase: $finalPhotoUrl');
        } else {
          throw Exception('No se pudo subir la nueva imagen de perfil.');
        }
      } else {
        // Caso: No hay nueva imagen, manteniendo la actual (Supabase o Google)
        print('ℹ️ No hay nueva imagen, manteniendo: $finalPhotoUrl');
      }
      // << CLAVE: FIN DEL ARREGLO PARA RESTAURAR A GOOGLE >>

      // Crea el objeto actualizado
      final updatedUser = UserModel(
        uid: widget.currentUser.uid,
        email: widget.currentUser.email,
        username: _usernameController.text.trim(),
        fullName: _fullNameController.text.trim(),
        bio: _bioController.text.trim(),
        phone: _phoneController.text.trim(),
        photoUrl: finalPhotoUrl, // ← Siempre tiene un valor (Google o Supabase)
        createdAt: widget.currentUser.createdAt,
      );

      // Actualiza en Firestore
      await _firestore
          .collection('users')
          .doc(widget.currentUser.uid)
          .update(updatedUser.toUpdateMap());

      // IMPORTANTE: Si también actualizas en Supabase (tabla 'perfiles')
      await supabase.from('perfiles').update({
        'nombre': updatedUser.fullName,
        'bio': updatedUser.bio,
        'celular': updatedUser.phone,
        'url_imagen':
            finalPhotoUrl, // Usa 'url_imagen' si es el campo de Supabase
      }).eq('id', updatedUser.uid);

      print('✅ Perfil actualizado en Firestore con foto: $finalPhotoUrl');

      // Actualiza Firebase Auth
      if (_auth.currentUser != null) {
        await _auth.currentUser!.updateDisplayName(updatedUser.username);
        // Actualiza la foto en el token de Firebase Auth con la URL final (la de Google)
        if (finalPhotoUrl != null) {
          await _auth.currentUser!.updatePhotoURL(finalPhotoUrl);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(restoreToGoogle
                ? 'Foto restaurada a la de Google.'
                : 'Perfil actualizado exitosamente.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      // ... (manejo de errores)
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: _pickedImageBytes != null
                                ? MemoryImage(_pickedImageBytes!)
                                : (_currentPhotoUrl != null &&
                                        _currentPhotoUrl!.isNotEmpty
                                    ? NetworkImage(_currentPhotoUrl!)
                                    : null) as ImageProvider?,
                            child: (_pickedImageBytes == null &&
                                    (_currentPhotoUrl == null ||
                                        _currentPhotoUrl!.isEmpty))
                                ? Icon(
                                    Icons.camera_alt,
                                    size: 40,
                                    color: Colors.grey[600],
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre de Usuario',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa un nombre de usuario.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre Completo',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'WhatsApp (con código de país)',
                        hintText: '+54 11 1234-5678',
                        helperText:
                            'Incluye el código de país (ej: +54 para Argentina)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!value.contains(RegExp(r'\d'))) {
                            return 'Ingresa un número válido';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Biografía',
                        hintText: 'Cuéntanos algo sobre ti...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.description),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _updateProfile,
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          'Guardar Cambios',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
