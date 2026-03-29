import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
// NUEVOS IMPORTS para la Ubicación
import 'package:geolocator/geolocator.dart';
// Asegúrate de que esta ruta sea correcta para tu proyecto
import 'package:mi_app_flutter/utils/location_service.dart';

class PostOfferScreen extends StatefulWidget {
  const PostOfferScreen({super.key});

  @override
  State<PostOfferScreen> createState() => _PostOfferScreenState();
}

class _PostOfferScreenState extends State<PostOfferScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  String selectedCategory = 'Comida';
  Uint8List? pickedImageBytes;
  String? pickedImageName;
  bool _isLoading = false;

  // ESTADO DE UBICACIÓN
  Position? _currentPosition;
  bool _isGettingLocation = false;

  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Obtener cliente de Supabase
  final supabase = Supabase.instance.client;

  Future<void> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          pickedImageBytes = bytes;
          pickedImageName = image.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e')),
      );
    }
  }

  Future<String?> uploadImage(Uint8List imageBytes, String fileName) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    // 1. Limpiar extensión y generar nombre único
    final extension = fileName.split('.').last.toLowerCase();
    final mimeType = (extension == 'jpg' || extension == 'jpeg') ? 'jpeg' : extension;
    final uniqueFileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    // 2. Subir a Supabase Storage con opciones de seguridad
    await supabase.storage.from('offer-images').uploadBinary(
          uniqueFileName,
          imageBytes,
          fileOptions: FileOptions(
            contentType: 'image/$mimeType',
            upsert: true, // 👈 Permite actualizar si el archivo ya existe
          ),
        );

    // 3. Obtener URL pública
    // Nota: getPublicUrl devuelve un String directamente en las últimas versiones del SDK
    final String imageUrl = supabase.storage.from('offer-images').getPublicUrl(uniqueFileName);

    return imageUrl;
  } catch (e) {
    // Es mejor usar debugPrint para no ensuciar la consola en producción
    debugPrint('❌ Error crítico subiendo imagen: $e');
    return null;
  }
}

  // NUEVA FUNCIÓN: CAPTURAR UBICACIÓN
  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Usamos el servicio determinePosition()
      final position = await LocationService.determinePosition();

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Ubicación capturada con éxito.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Manejo de errores de permisos o servicio deshabilitado
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '❌ Error al obtener ubicación: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  Future<void> submitOffer() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión primero')),
      );
      return;
    }

    // 🛑 VALIDACIÓN DE UBICACIÓN
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes capturar la ubicación para publicar la oferta.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String? imageUrl;
    if (pickedImageBytes != null && pickedImageName != null) {
      imageUrl = await uploadImage(pickedImageBytes!, pickedImageName!);
      if (imageUrl == null) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al subir la imagen')),
        );
        return;
      }
    }

    try {
      // ✅ AGREGADOS LOS CAMPOS PARA EL SISTEMA DE ESTADOS
      await FirebaseFirestore.instance.collection('offers').add({
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'price': priceController.text.trim(),
        'category': selectedCategory
            .toLowerCase(), // ✅ CORRECCIÓN: Guardar en minúsculas
        'imageUrl': imageUrl ?? '',
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,

        // ✅ NUEVOS CAMPOS PARA SISTEMA DE ESTADOS (vendida/pausada/activa)
        'isActive': true, // Por defecto la oferta está activa
        'status': 'active', // Estados posibles: 'active', 'paused', 'sold'
        'completedAt': null, // Se llenará cuando se marque como vendida
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oferta publicada correctamente 🎉')),
      );

      // Limpiar formulario
      titleController.clear();
      descriptionController.clear();
      priceController.clear();
      setState(() {
        pickedImageBytes = null;
        pickedImageName = null;
        selectedCategory = 'Comida';
        _currentPosition = null; // Limpiar ubicación también
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al publicar oferta: $e')),
      );
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
        title: const Text('Publicar Oferta'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Título
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese un título' : null,
              ),
              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) => value == null || value.isEmpty
                    ? 'Ingrese una descripción'
                    : null,
              ),
              const SizedBox(height: 16),

              // Precio (con validación numérica)
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Precio (o dejar vacío si es gratis)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (double.tryParse(value) == null) {
                      return 'Por favor, ingrese un número válido.';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Dropdown categoría
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: const [
                  DropdownMenuItem(value: 'Comida', child: Text('Comida')),
                  DropdownMenuItem(
                    value: 'Tecnología',
                    child: Text('Tecnología'),
                  ),
                  DropdownMenuItem(value: 'Ropa', child: Text('Ropa')),
                  DropdownMenuItem(value: 'Hogar', child: Text('Hogar')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedCategory = value;
                    });
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 24),

              // ----------------------------------------------------
              // ✅ NUEVO: BOTÓN PARA CAPTURAR UBICACIÓN
              // ----------------------------------------------------
              ElevatedButton.icon(
                onPressed: _isGettingLocation ? null : _getCurrentLocation,
                icon: const Icon(Icons.location_on),
                label: _isGettingLocation
                    ? const Text('Obteniendo ubicación...')
                    : Text(_currentPosition == null
                        ? 'Capturar Ubicación Actual'
                        : 'Ubicación OK: Lat ${_currentPosition!.latitude.toStringAsFixed(4)}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _currentPosition == null ? Colors.blue : Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              // ----------------------------------------------------

              // Vista previa de la imagen
              if (pickedImageBytes != null)
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        pickedImageBytes!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Imagen seleccionada: $pickedImageName',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                )
              else
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No hay imagen seleccionada',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Botón seleccionar imagen
              ElevatedButton.icon(
                icon: const Icon(Icons.image),
                label: Text(
                  pickedImageBytes != null
                      ? 'Cambiar Imagen'
                      : 'Seleccionar Imagen',
                ),
                onPressed: pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botón publicar (con manejo de estado de carga)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : submitOffer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Publicar Oferta',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    super.dispose();
  }
}
