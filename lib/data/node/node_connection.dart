import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> connectToNode(
  ValueNotifier<int> stepNotifier,
  ValueNotifier<bool> errorNotifier,
  String nodeAddress,
) async {
  final dio = Dio();
  // Query DNS for the node address
  try {
    final response = await dio.get(nodeAddress);
    if (response.statusCode == 200) {
      // Successfully connected to the node
      stepNotifier.value = 1;
      await Future.delayed(const Duration(seconds: 1), () {
        stepNotifier.value = 2;
      });
      await Future.delayed(const Duration(seconds: 1), () {
        stepNotifier.value = 3;
      });
      await Future.delayed(const Duration(seconds: 1), () {
        stepNotifier.value = 4;
      });
    } else {
      // Failed to connect to the node
      errorNotifier.value = true;
    }
  } catch (e) {
    log('Error connecting to node: $e');
    errorNotifier.value = true;
    return;
  }
  if (errorNotifier.value == false) {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('node_address', nodeAddress);
  }
}
