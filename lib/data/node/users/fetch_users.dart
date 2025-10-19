import 'package:dio/dio.dart';
import 'package:hushnet_frontend/models/users.dart';

Future<List<User>> fetchUsers(String nodeUrl) async {
  final dio = Dio();
  final res = await dio.get('$nodeUrl/users');
  final List<dynamic> data = res.data;
  return data.map((userJson) => User.fromJson(userJson)).toList();
}