import 'dart:async';
import 'package:dio/dio.dart';
import 'token_storage.dart';

typedef RefreshTokenFn = Future<String?> Function(String? refreshToken);

class AuthInterceptor extends Interceptor {
  final TokenStorage storage;
  final RefreshTokenFn onRefreshToken;

  AuthInterceptor({required this.storage, required this.onRefreshToken});

  bool _refreshing = false;
  final List<Completer<void>> _queue = [];

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await storage.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // ถ้าไม่ได้ 401 หรือเคยลอง refresh แล้ว ให้ทิ้งไป
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // กันยิงซ้ำ: ถ้ากำลัง refresh อยู่ ให้รอ
    if (_refreshing) {
      final completer = Completer<void>();
      _queue.add(completer);
      await completer.future;
      // หลัง refresh เสร็จ ลองยิงซ้ำ
      final req = await _retry(err.requestOptions);
      return handler.resolve(req);
    }

    _refreshing = true;
    try {
      final newAccess = await onRefreshToken(await storage.refreshToken);
      if (newAccess == null) {
        return handler.next(err); // refresh ไม่สำเร็จ
      }
      // แจ้งคิวที่รอให้ไปต่อ
      for (final c in _queue) {
        if (!c.isCompleted) c.complete();
      }
      _queue.clear();

      // ยิงซ้ำตัวที่พัง 401
      final response = await _retry(err.requestOptions);
      return handler.resolve(response);
    } catch (e) {
      for (final c in _queue) {
        if (!c.isCompleted) c.completeError(e);
      }
      _queue.clear();
      return handler.next(err);
    } finally {
      _refreshing = false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions req) async {
    // Prefer the original Dio instance if passed via request options
    final retryDio = (req.extra['dio'] as Dio?) ?? Dio();
    final token = await storage.accessToken;
    final options = Options(
      method: req.method,
      headers: {
        ...req.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      },
      responseType: req.responseType,
      contentType: req.contentType,
      followRedirects: req.followRedirects,
      receiveDataWhenStatusError: req.receiveDataWhenStatusError,
      validateStatus: req.validateStatus,
    );

    return retryDio.request<dynamic>(
      req.path,
      data: req.data,
      queryParameters: req.queryParameters,
      options: options,
      cancelToken: req.cancelToken,
      onReceiveProgress: req.onReceiveProgress,
    );
  }
}
