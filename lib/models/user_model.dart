// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? username;
  final String? fullName;
  final String? bio;
  final String? photoUrl;
  final String? phone; // ⬅️ NUEVO: Número de teléfono para WhatsApp
  final Timestamp? createdAt;

  UserModel({
    required this.uid,
    required this.email,
    this.username,
    this.fullName,
    this.bio,
    this.photoUrl,
    this.phone, // ⬅️ NUEVO
    this.createdAt,
  });

  // Constructor para crear un UserModel desde un DocumentSnapshot de Firestore
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      username: data['username'] ?? data['email']?.split('@')[0],
      fullName: data['fullName'],
      bio: data['bio'],
      photoUrl: data['photoUrl'] ?? data['photoURL'],
      phone: data['phone'], // ⬅️ NUEVO
      createdAt: data['createdAt'],
    );
  }

  // Método para convertir un UserModel a un Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'fullName': fullName,
      'bio': bio,
      'photoUrl': photoUrl,
      'phone': phone, // ⬅️ NUEVO
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  // Método para actualizar solo los campos especificados
  Map<String, dynamic> toUpdateMap() {
    final Map<String, dynamic> map = {};
    if (username != null) map['username'] = username;
    if (fullName != null) map['fullName'] = fullName;
    if (bio != null) map['bio'] = bio;
    if (photoUrl != null) map['photoUrl'] = photoUrl;
    if (phone != null) map['phone'] = phone; // ⬅️ NUEVO
    return map;
  }
}
