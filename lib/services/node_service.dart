import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hushnet_frontend/services/key_provider.dart';
import 'package:hushnet_frontend/services/secure_storage_service.dart';
import 'package:dio/dio.dart';
import 'package:hushnet_frontend/utils/json_converter.dart';
import 'package:logging/logging.dart';

class NodeService {
  static final NodeService _instance = NodeService._internal();
  factory NodeService() => _instance;
  NodeService._internal();

  final dio = Dio();
  final SecureStorageService _storage = SecureStorageService();
  final log = Logger('NodeService');
  final KeyProvider _keyProvider = KeyProvider();
  



  Future<String?> registerUser(String nodeUrl, String username) async {
    try {
      log.info('Registering user: $username');
      final response = await dio.post(
        '$nodeUrl/users/create',
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: jsonEncode({'username': username}),
      );
      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        final token = data['enrollment_token'] as String;
        final userId = data['user']["id"] as String;
        await _storage.write('enrollment_token', token);
        await _storage.write('node_url', nodeUrl);
        await _storage.write('username', username);
        await _storage.write('user_id', userId);
        return token;
      } else if (response.statusCode == 409) {
        log.warning('User already exists');
        return null;
      } else {
        log.severe('Register failed: ${response.statusCode} ${response.data}');
        return null;
      }
    } catch (e) {
      log.severe('Error registering user: $e');
      rethrow;
    }
  }

  Future<bool> enrollDevice(ValueNotifier<int>? stepNotifier) async {
    try {
      final nodeUrl = await _storage.read('node_url');
      final username = await _storage.read('username');
      final token = await _storage.read('enrollment_token');
      final userId = await _storage.read('user_id');

      if (nodeUrl == null || username == null || token == null || userId == null) {
        log.warning('Missing registration details');
        throw Exception('Missing registration details');
      }
      final keyBundle = await _keyProvider.getKeyBundle();
      final payload = {
        'enrollment_token': token,
        'user_id': userId,
        'device_label': 'Flutter-${DateTime.now().millisecondsSinceEpoch}',
        'push_token': 'dummy_push_token',
        ...keyBundle,
      };
      final response = await dio.post(
        '$nodeUrl/users/$userId/devices',
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: jsonEncode(payload),
      );

        stepNotifier?.value = 7;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.data);
        final deviceId = data['device_id'];
        final deviceKey = data['device_key'];
        await _storage.write('device_id', deviceId);
        await _storage.write('device_key', deviceKey);
                stepNotifier?.value = 8;

        return true;
      } else {
        log.severe('Enroll failed: ${response.statusCode} ${response.data}');
        return false;
      }
    } catch (e) {
      log.severe('Error enrolling device: $e');
      return false;
    }
  }
}