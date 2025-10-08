import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart'; // เพิ่ม GetX
import 'package:smart_control/core/alert/app_snackbar.dart';
import 'package:smart_control/widgets/loading_overlay.dart';
import 'api_exceptions.dart';
import 'dio_client.dart';
import 'token_storage.dart';

typedef Json = Map<String, dynamic>;
typedef FromJson<T> = T Function(dynamic data);

class ApiService {
  static const String _baseUrl =
      'https://app.viinter.online'; // สำหรับอุปกรณ์จริง

  final Dio _dio;
  final TokenStorage _storage;
  final PersistCookieJar _cookieJar;

  ApiService._(this._dio, this._storage, this._cookieJar);

  static Future<ApiService> public() async {
    final dio = createBaseDio(baseUrl: _baseUrl);
    final storage = TokenStorage();
    final directory = await getApplicationDocumentsDirectory();
    final cookieJar = PersistCookieJar(
      storage: FileStorage(directory.path + '/cookies'),
    );

    dio.interceptors.add(CookieManager(cookieJar));
    dio.interceptors.add(
      LogInterceptor(
        responseBody: true,
        requestBody: true,
        requestHeader: true,
      ),
    );

    dio.options.extra['dio'] = dio;
    return ApiService._(dio, storage, cookieJar);
  }

  static Future<ApiService> private() async {
    final dio = createBaseDio(baseUrl: _baseUrl);
    final storage = TokenStorage();
    final directory = await getApplicationDocumentsDirectory();
    final cookieJar = PersistCookieJar(
      storage: FileStorage(directory.path + '/cookies'),
    );

    dio.interceptors.add(CookieManager(cookieJar));
    dio.interceptors.add(
      LogInterceptor(
        responseBody: true,
        requestBody: true,
        requestHeader: true,
      ),
    );

    dio.options.extra['dio'] = dio;

    return ApiService._(dio, storage, cookieJar);
  }

  Future<T> _request<T>(
    String path, {
    String method = 'GET',
    Json? query,
    dynamic data,
    FromJson<T>? decoder,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _dio.request(
        path,
        queryParameters: query,
        data: data,
        options: (options ?? Options()).copyWith(method: method),
        cancelToken: cancelToken,
      );
      final body = res.data;

      if (decoder != null) {
        return decoder(body);
      }
      return body as T;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final responseData = e.response?.data;

      // ตรวจสอบ 401 และ requireLogin
      if (code == 401 &&
          responseData is Map &&
          responseData['requireLogin'] == true) {
        AppSnackbar.info("แจ้งเตือน", "Session หมดอายุ");

        await _cookieJar.deleteAll();
        await _storage.clear();

        Get.offAllNamed('/login');

        throw ApiException(
          responseData['message']?.toString() ?? 'ต้องล็อกอินใหม่',
          statusCode: code,
        );
      }

      final msg = responseData is Map && responseData['message'] != null
          ? responseData['message'].toString()
          : e.message ?? 'Network error';
      throw ApiException(msg, statusCode: code);
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  Future<T> get<T>(
    String path, {
    Json? query,
    FromJson<T>? decoder,
    CancelToken? cancelToken,
  }) => _request<T>(
    path,
    method: 'GET',
    query: query,
    decoder: decoder,
    cancelToken: cancelToken,
  );

  Future<T> post<T>(
    String path, {
    dynamic data,
    Json? query,
    FromJson<T>? decoder,
    CancelToken? cancelToken,
    Options? options,
  }) => _request<T>(
    path,
    method: 'POST',
    data: data,
    query: query,
    decoder: decoder,
    cancelToken: cancelToken,
    options: options,
  );

  Future<T> put<T>(
    String path, {
    dynamic data,
    Json? query,
    FromJson<T>? decoder,
    CancelToken? cancelToken,
  }) => _request<T>(
    path,
    method: 'PUT',
    data: data,
    query: query,
    decoder: decoder,
    cancelToken: cancelToken,
  );

  Future<T> delete<T>(
    String path, {
    dynamic data,
    Json? query,
    FromJson<T>? decoder,
    CancelToken? cancelToken,
  }) => _request<T>(
    path,
    method: 'DELETE',
    data: data,
    query: query,
    decoder: decoder,
    cancelToken: cancelToken,
  );

  Future<void> setTokens({required String access, required String refresh}) =>
      _storage.saveTokens(accessToken: access, refreshToken: refresh);

  Future<void> clearTokens() => _storage.clear();

  Future<List<Cookie>> getCookies() async {
    return await _cookieJar.loadForRequest(Uri.parse(_baseUrl));
  }
}
