import 'package:dio/dio.dart';

Dio createBaseDio({
  required String baseUrl,
  Duration connectTimeout = const Duration(seconds: 10),
  Duration receiveTimeout = const Duration(seconds: 20),
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      contentType: 'application/json',
      headers: {'Accept': 'application/json'},
    ),
  );

  // Logging เบาๆ (เปิดตอน debug เท่านั้นถ้าต้องการ)
  // dio.interceptors.add(LogInterceptor(responseBody: false, requestBody: true));
  return dio;
}
