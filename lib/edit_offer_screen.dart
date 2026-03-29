// lib/edit_offer_screen.dart
import 'dart:io'; // Para File
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ Firebase User
import 'package:supabase_flutter/supabase_flutter.dart'
    as supabase_lib; // ✅ Alias para Supabase
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Para detectar si es web
import 'dart:typed_data'; // Para web/supabase

class EditOfferScreen extends StatefulWidget {
  final String offerId; // Necesitamos el ID de la oferta para editarla

  const EditOfferScreen({super.key, required this.offerId});

  @override
  _EditOfferScreenState createState() => _EditOfferScreenState();
}

class _EditOfferScreenState extends State<EditOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final supabase = supabase_lib.Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  // ⬅️ CAMBIO 1: Lista de categorías canónica (Única y con mayúscula inicial para la visualización)
  final List<String> _categories = const [
    'Comida',
    'Tecnología',
    'Ropa',
    'Hogar',
  ];

  // Controladores para los campos del formulario
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;

  String? _selectedCategory;
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes; // Para la carga de imágenes en web
  String? _currentImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _priceController = TextEditingController();
    _loadOffer();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // ⬅️ CAMBIO 2: Lógica para normalizar la categoría de Firestore
  Future<void> _loadOffer() async {
    try {
      final doc =
          await _firestore.collection('offers').doc(widget.offerId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        _titleController.text = data['title'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _priceController.text = (data['price'] ?? 0.0).toString();

        String? categoryFromDb = data['category'] as String?;

        // Normalizar la categoría de la DB para que coincida con la lista _categories (capitalización)
        // Esto resuelve el problema de si en DB se guarda 'ropa' y en la lista tenemos 'Ropa'.
        String? normalizedCategory = categoryFromDb != null
            ? _categories.firstWhere(
                (cat) => cat.toLowerCase() == categoryFromDb.toLowerCase(),
                orElse: () => categoryFromDb,
              )
            : null;

        _currentImageUrl = data['imageUrl'] as String?;

        setState(() {
          // Asigna la categoría normalizada para que coincida con uno de los items del DropdownButton
          _selectedCategory = normalizedCategory ?? categoryFromDb;
          _isLoading = false;
        });
      } else {
        // Manejar el caso en que la oferta no existe
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      print('Error loading offer: $e');
      setState(() => _isLoading = false);
    }
  }

  // (El resto de las funciones _pickImage, _uploadImageToSupabase y _updateOffer se mantienen iguales)
  // ... (código para _pickImage)
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (kIsWeb) {
        _pickedImageBytes = await image.readAsBytes();
      }
      setState(() {
        _pickedImage = image;
      });
    }
  }

  // (código para _uploadImageToSupabase)
  Future<String?> _uploadImageToSupabase() async {
    if (_pickedImage == null) return _currentImageUrl;

    try {
      final String fileName =
          'offers/${_auth.currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (kIsWeb && _pickedImageBytes != null) {
        await supabase.storage.from('offers_bucket').uploadBinary(
              fileName,
              _pickedImageBytes!,
              fileOptions: const supabase_lib.FileOptions(
                  upsert: true, contentType: 'image/jpeg'),
            );
      } else if (!kIsWeb) {
        final File file = File(_pickedImage!.path);
        await supabase.storage.from('offers_bucket').upload(
              fileName,
              file,
              fileOptions: const supabase_lib.FileOptions(
                  upsert: true, contentType: 'image/jpeg'),
            );
      } else {
        return _currentImageUrl;
      }

      final String publicUrl =
          supabase.storage.from('offers_bucket').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      print('Error uploading image to Supabase: $e');
      return null;
    }
  }

  // (código para _updateOffer)
  Future<void> _updateOffer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final newImageUrl = await _uploadImageToSupabase();

      final offerData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        // Usamos la categoría seleccionada (normalizada) y la guardamos en minúsculas si es necesario
        'category': _selectedCategory!.toLowerCase(), 
        'imageUrl': newImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('offers')
          .doc(widget.offerId)
          .update(offerData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oferta actualizada exitosamente')),
        );
        // Regresa a la pantalla anterior indicando que se actualizó
        Navigator.of(context).pop('updated');
      }
    } catch (e) {
      print('Error al actualizar oferta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar oferta: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Editar Oferta'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Oferta'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Título
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa un título';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa una descripción';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ⬅️ CAMBIO 3: Uso de la lista canónica para el DropdownButton
              // Dropdown para Categoría
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                isExpanded: true,
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category, // El valor debe ser único
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, selecciona una categoría';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo de Precio
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Precio (o dejar vacío si es gratis)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                  hintText: 'Ej: 100.00',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (double.tryParse(value) == null) {
                      return 'Por favor, ingresa un número válido';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Previsualización de la imagen
              if (_currentImageUrl != null || _pickedImage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _pickedImage != null
                          ? (kIsWeb && _pickedImageBytes != null
                              ? Image.memory(
                                  _pickedImageBytes!,
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(_pickedImage!.path),
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.cover,
                                ))
                          : Image.network(
                              _currentImageUrl!,
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 200,
                                  height: 200,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image,
                                      size: 50),
                                );
                              },
                            ),
                    ),
                  ),
                ),

              // Botón seleccionar imagen
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.image, color: Colors.white),
                  label: const Text('Cambiar Imagen',
                      style: TextStyle(color: Colors.white)),
                  onPressed: _pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botón de Actualizar Oferta
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _updateOffer,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text(
                    'Actualizar Oferta',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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