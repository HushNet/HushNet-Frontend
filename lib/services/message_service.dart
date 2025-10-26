import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hushnet_frontend/models/chat_view.dart';
import 'package:hushnet_frontend/models/message_view.dart';
import 'package:hushnet_frontend/services/key_provider.dart';
import 'package:hushnet_frontend/services/node_service.dart';
import 'package:uuid/uuid.dart';

class MessageService {
  final Dio dio = Dio();
  final KeyProvider keyProvider = KeyProvider();
  final NodeService nodeService = NodeService();

  /// 📨 Fetch all pending (undelivered) messages for this device
  Future<List<MessageView>> getPendingMessages() async {
    final FlutterSecureStorage secureStorage = keyProvider.secureStorage;
    final nodeUrl = await nodeService.getCurrentNodeUrl();
    final response = await keyProvider.sendSignedRequest(
      "GET",
      "$nodeUrl/messages/pending",
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Failed to fetch pending messages (status: ${response.statusCode})",
      );
    }

    final List<dynamic> data = response.data;
    final List<MessageView> messages = data
        .map((m) => MessageView.fromJson(m))
        .toList();

    // Déchiffrement + stockage
    for (final msg in messages) {
      try {
        final fromDevice = msg.fromDeviceId;
        final plaintext = await keyProvider.decryptMessage(
          msg.ciphertext,
          fromDevice,
        );

        // 🔹 Incrémenter le compteur de réception
        final recvCounterKey = "session_${fromDevice}_recv_counter";
        final currentCounterStr = await secureStorage.read(key: recvCounterKey);
        int recvCounter = int.tryParse(currentCounterStr ?? "0") ?? 0;
        recvCounter += 1;
        await secureStorage.write(
          key: recvCounterKey,
          value: recvCounter.toString(),
        );

        // 🗂️ Structure de stockage : messages_{chat_id} = [ ... ]
        final chatKey = "messages_${msg.chatId}";
        final existingRaw = await secureStorage.read(key: chatKey);
        List<Map<String, dynamic>> existingMessages = [];

        if (existingRaw != null) {
          existingMessages = List<Map<String, dynamic>>.from(
            jsonDecode(existingRaw),
          );
        }

        // Ajouter le nouveau message déchiffré
        MessageView decryptedMsg = MessageView(
          id: msg.id,
          logicalMsgId: msg.logicalMsgId,
          chatId: msg.chatId,
          fromUserId: msg.fromUserId,
          fromDeviceId: msg.fromDeviceId,
          decryptedText: plaintext,
          ciphertext: msg.ciphertext,
          createdAt: msg.createdAt,
          pending: false,
        );
        existingMessages.add(decryptedMsg.toJson());

        // Réécrire dans SecureStorage
        await secureStorage.write(
          key: chatKey,
          value: jsonEncode(existingMessages),
        );

        print("💾 Stored message in chat ${msg.chatId}");
      } catch (e) {
        print("❌ Failed to decrypt/store message: $e");
      }
    }

    return messages;
  }

  Future<List<MessageView>> getAllMessagesForChat(String chatId) async {
    final FlutterSecureStorage secureStorage = keyProvider.secureStorage;
    final nodeUrl = await nodeService.getCurrentNodeUrl();

    // 1️⃣ Charger les messages locaux stockés
    final existingRaw = await secureStorage.read(key: "messages_$chatId");
    List<MessageView> localMessages = [];
    if (existingRaw != null) {
      final list = jsonDecode(existingRaw) as List;
      localMessages = list
          .map(
            (m) => MessageView.fromJson(m),
          )
          .toList();
    }

    // 2️⃣ Récupérer les nouveaux messages en attente sur le serveur
    final response = await keyProvider.sendSignedRequest(
      "GET",
      "$nodeUrl/messages/pending",
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      for (final m in data) {
        try {
          final msg = MessageView.fromJson(m);
          final plaintext = await keyProvider.decryptMessage(
            msg.ciphertext,
            msg.fromDeviceId,
          );

          // Ajouter au stockage local
          localMessages.add(
            MessageView(
              id: msg.id,
              logicalMsgId: msg.logicalMsgId,
              chatId: msg.chatId,
              fromUserId: msg.fromUserId,
              fromDeviceId: msg.fromDeviceId,
              ciphertext: msg.ciphertext,
              decryptedText: plaintext, // déchiffré
              createdAt: msg.createdAt,
              pending: false,
            ),
          );
        } catch (e) {
          print("❌ Decrypt failed for pending message: $e");
        }
      }
    }

    // 3️⃣ Trier par date
    localMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // 4️⃣ Réécrire la version fusionnée dans le SecureStorage
    final mergedJson = localMessages
        .map(
          (m) => m.toJson(),
        )
        .toList();
    await secureStorage.write(
      key: "messages_$chatId",
      value: jsonEncode(mergedJson),
    );

    return localMessages;
  }

  Future<MessageView> sendMessage({
    required String chatId,
    required String plaintext,
    required String recipientUserId,
    required List<String> recipientDeviceIds,
  }) async {
    final nodeUrl = await nodeService.getCurrentNodeUrl();
    final logicalMsgId = const Uuid().v4();
    final List<Map<String, dynamic>> payloads = [];
    final FlutterSecureStorage storage = keyProvider.secureStorage;
    Map<String, dynamic> localMessage = {
      "id": const Uuid().v4(),
      "logical_msg_id": logicalMsgId,
      "chat_id": chatId,
      "from_user_id": await nodeService.getCurrentUserId(),
      "from_device_id": "SELF_DEVICE", // placeholder
      "decrypted_text": plaintext,
      "created_at": DateTime.now().toUtc().toIso8601String(),
      "pending": true, // flag utile si jamais l’envoi échoue
    };
    List<String> ciphertexts = [];

    final existingRaw = await storage.read(key: "messages_$chatId");
    List<Map<String, dynamic>> existingMessages = [];

    if (existingRaw != null) {
      existingMessages = List<Map<String, dynamic>>.from(
        jsonDecode(existingRaw),
      );
    }
    existingMessages.add(localMessage);
    await storage.write(
      key: "messages_$chatId",
      value: jsonEncode(existingMessages),
    );

    for (final peerDeviceId in recipientDeviceIds) {
      // 🔹 Lire et incrémenter le compteur local
      final counterKey = "session_${peerDeviceId}_send_counter";
      final currentCounterStr = await keyProvider.secureStorage.read(
        key: counterKey,
      );
      int counter = int.tryParse(currentCounterStr ?? "0") ?? 0;

      // 🔹 Chiffrement
      final ciphertext = await keyProvider.encryptMessage(
        plaintext,
        peerDeviceId,
      );
      ciphertexts.add(ciphertext);

      // 🔹 Pubkey du ratchet courant
      final ratchetPub = await keyProvider.getLocalRatchetPub(peerDeviceId);

      // 🔹 Ajouter au tableau de payloads
      payloads.add({
        "to_device_id": peerDeviceId,
        "ciphertext": ciphertext,
        "header": {"ratchet_pub": base64Encode(ratchetPub), "counter": counter},
      });

      // 🔹 Incrémenter et stocker le compteur local
      counter += 1;
      await keyProvider.secureStorage.write(
        key: counterKey,
        value: counter.toString(),
      );
    }

    // 🔹 Corps complet pour le backend
    final payload = {
      "logical_msg_id": logicalMsgId,
      "chat_id": chatId,
      "to_user_id": recipientUserId,
      "payloads": payloads, // ✅ LISTE, pas objet unique
    };

    // 🔹 Envoi en une requête
    try {
      await keyProvider.sendSignedRequest(
        "POST",
        "$nodeUrl/messages",
        payload: payload,
      );
      final updatedRaw = await storage.read(key: "messages_$chatId");
      if (updatedRaw != null) {
        final msgs = List<Map<String, dynamic>>.from(jsonDecode(updatedRaw));
        for (final m in msgs) {
          if (m["logical_msg_id"] == logicalMsgId) {
            m["pending"] = false;
          }
        }
        await storage.write(key: "messages_$chatId", value: jsonEncode(msgs));
      }
      print("✅ Message envoyé à ${recipientDeviceIds.length} device(s)");
      localMessage["local_ciphertext"] = ciphertexts;
      return MessageView.fromJson(localMessage);
    } catch (e) {
      print("❌ Failed to send message to $recipientUserId: $e");
      rethrow;
    }
  }
}
