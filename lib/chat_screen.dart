// lib/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Necesario para formatear la hora de los mensajes

class ChatScreen extends StatefulWidget {
  // ID del usuario que publicó la oferta (el destinatario del chat)
  final String recipientId;
  // Nombre del destinatario para mostrar en el AppBar
  final String recipientName;

  const ChatScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController(); // Para scroll automático

  late String _chatId; // El ID único de la conversación
  late String _currentUserId; // Tu ID

  @override
  void initState() {
    super.initState();
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      // Si el usuario no está logueado, redirigir o mostrar un error
      // Por simplicidad, asumimos que OfferDetailScreen ya verificó esto.
      _currentUserId = '';
      _chatId = ''; 
      return; 
    }
    
    _currentUserId = currentUser.uid;

    // Generar el Chat ID único y ordenado para que sea el mismo para ambos usuarios
    final participants = [_currentUserId, widget.recipientId];
    participants.sort(); // Ordenar alfabéticamente
    _chatId = participants.join('_'); // Ejemplo: 'ID123_ID456'
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // === LÓGICA DE MENSAJERÍA
  // ===========================================================================

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId.isEmpty) {
      return; // No enviar mensajes vacíos o sin usuario
    }

    try {
      // 1. Crear el nuevo mensaje
      final message = {
        'senderId': _currentUserId,
        'recipientId': widget.recipientId,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(), // Marca de tiempo de Firestore
      };

      // 2. Guardar el mensaje en la subcolección 'messages' del chat
      await _firestore
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add(message);

      // 3. Actualizar el documento principal del chat para que aparezca en una lista de chats (opcional, pero útil)
      await _firestore.collection('chats').doc(_chatId).set(
        {
          'lastMessage': text,
          'lastMessageSenderId': _currentUserId,
          'lastTimestamp': FieldValue.serverTimestamp(),
          'participants': [_currentUserId, widget.recipientId],
          'uids': {_currentUserId: true, widget.recipientId: true}, // Para consultas más eficientes
        },
        SetOptions(merge: true),
      );

      // 4. Limpiar el campo de texto y hacer scroll
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print('Error al enviar mensaje: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al enviar mensaje. Intenta de nuevo.')),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ===========================================================================
  // === WIDGETS DE RENDERIZADO
  // ===========================================================================

  // Construye el widget individual del mensaje
  Widget _buildMessageItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isMe = data['senderId'] == _currentUserId;
    final timestamp = data['timestamp'] as Timestamp?;
    final timeText = timestamp != null
        ? DateFormat('hh:mm a').format(timestamp.toDate())
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 10.0),
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isMe ? Colors.deepPurple.shade300 : Colors.grey.shade300,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15.0),
            topRight: const Radius.circular(15.0),
            bottomLeft: isMe ? const Radius.circular(15.0) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(15.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75, // Máximo 75% del ancho
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              data['message'] ?? '',
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              timeText,
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.black54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // === WIDGET PRINCIPAL
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
       return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: Text('Necesitas iniciar sesión para chatear.')),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.recipientName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Área de mensajes (StreamBuilder)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true) // Los más nuevos arriba
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.reversed.toList(); // Invertir para mostrar los más nuevos abajo

                // Scroll automático al final después de la carga inicial
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 10.0),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _buildMessageItem(docs[index]);
                  },
                );
              },
            ),
          ),

          // Área de entrada de texto
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.deepPurple,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}