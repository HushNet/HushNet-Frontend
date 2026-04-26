import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hushnet_frontend/services/key_provider.dart';
import 'package:hushnet_frontend/services/secure_storage_service.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class NodeService {
  static final NodeService _instance = NodeService._internal();
  factory NodeService() => _instance;
  NodeService._internal();

  final dio = Dio();
  final SecureStorageService _storage = SecureStorageService();
  final log = Logger('NodeService');
  final KeyProvider _keyProvider = KeyProvider();
  
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _connectedUserId;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  bool _isConnected = false;
  bool _retrying = false;
  int _retryDelay = 3;
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<bool> get connectionState => _connectionStateController.stream;
  bool get isConnected => _isConnected;

  Stream<Map<String, dynamic>> get stream => _controller.stream;



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

  Future<String?> loginUser(String nodeUrl, ValueNotifier<int>? stepNotifier) async {
    Map<String, dynamic> signedMessage = await _keyProvider.generateSignedMessage('Login request');
      stepNotifier?.value += 1;
    try {
      log.info('Logging in user');
      print(signedMessage);
      final response = await dio.post(
        '$nodeUrl/users/login',
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: jsonEncode(signedMessage),
      );
      stepNotifier?.value += 2;

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final userId = data['id'] as String;
        final username = data['username'] as String;
        await _storage.write('username', username);
        await _storage.write('user_id', userId);
        await _storage.write('node_url', nodeUrl);
        await connectWebSocket();
        return username;
      } else {
        log.severe('Login failed: ${response.statusCode} ${response.data}');
          stepNotifier?.value = 4;
        return null;
      }
    } catch (e) {
      stepNotifier?.value = 4;
      log.severe('Error logging in user: $e');
      return null;
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
        await connectWebSocket();
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
  Future<String?> getCurrentNodeUrl() async {
    return await _storage.read('node_url');
  }

  Future<String?> getCurrentUserId() async {
    return await _storage.read('user_id');
  }
  
  Future<String?> getCurrentDeviceId() async {
    return await _storage.read('device_id');
  }
Future<void> connectWebSocket() async {
  final nodeUrl = await getCurrentNodeUrl();
  final userId = await getCurrentUserId();
  if (nodeUrl == null || userId == null) {
    debugPrint("Cannot connect WS: missing nodeUrl or userId");
    return;
  }
  if (_connectedUserId == userId && _channel != null) {
    debugPrint("WebSocket already connected for $userId");
    return;
  }

  var clean = nodeUrl.trim().replaceAll('#', '');
  final parsed = Uri.parse(clean);
  final scheme = (parsed.scheme == 'https' || parsed.scheme == 'wss') ? 'wss' : 'ws';
  final host = parsed.host;
  final port = parsed.hasPort ? ':${parsed.port}' : '';
  final wsUrl = Uri.parse("$scheme://$host$port/ws/$userId");
  debugPrint("Connecting WS to $wsUrl");

  void onDisconnect() {
    _channel = null;
    _connectedUserId = null;
    _isConnected = false;
    _connectionStateController.add(false);
    _scheduleRetry();
  }

  try {
    _channel = WebSocketChannel.connect(wsUrl);
    _connectedUserId = userId;
    _isConnected = true;
    _retryDelay = 3;
    _connectionStateController.add(true);
    debugPrint("WS connected for $userId");

    _subscription?.cancel();
    _subscription = _channel!.stream.listen(
      (event) {
        try {
          final decoded = jsonDecode(event);
          _controller.add(decoded);
        } catch (e) {
          debugPrint("Invalid WS payload: $e");
        }
      },
      onError: (err) {
        debugPrint("WS error: $err");
        onDisconnect();
      },
      onDone: () {
        debugPrint("WS closed for $userId");
        onDisconnect();
      },
    );
  } catch (e) {
    debugPrint("Failed to connect WebSocket: $e");
    onDisconnect();
  }
}

  void _scheduleRetry() {
    if (_retrying) return;
    _retrying = true;
    final delay = _retryDelay;
    _retryDelay = (_retryDelay * 2).clamp(3, 60);
    debugPrint("WS retry in ${delay}s");
    Future.delayed(Duration(seconds: delay), () {
      _retrying = false;
      connectWebSocket();
    });
  }

  void disconnectWebSocket() {
    //TODO : Implement disconnect logic
    debugPrint("Closing WS connection...");
    _subscription?.cancel();
    _channel?.sink.close(status.normalClosure);
    _connectedUserId = null;
  }

}