import 'dart:convert';

import 'package:dio/dio.dart';

class JsonResponseInterceptor extends Interceptor 
{
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {

    response.data = json.decode(response.data);

    super.onResponse(response, handler);

  }

}
