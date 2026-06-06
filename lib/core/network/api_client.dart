/// 网络请求客户端配置。
///
/// 基于 dio 的单例 HTTP 客户端，提供统一的拦截器、超时和错误处理。
library;

import 'package:dio/dio.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;

  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      error: true,
      logPrint: (obj) => print('[API] $obj'),
    ));
  }

  /// 获取单例实例
  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  /// 获取底层 Dio 实例
  Dio get dio => _dio;

  /// 配置 AI API 的 Base URL 和 Token
  void configureAI({
    required String baseUrl,
    required String apiKey,
  }) {
    _dio.options.baseUrl = baseUrl;
    _dio.options.headers['Authorization'] = 'Bearer $apiKey';
  }

  /// 发起 GET 请求
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get(path, queryParameters: queryParameters, options: options);
  }

  /// 发起 POST 请求
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post(path,
        data: data, queryParameters: queryParameters, options: options);
  }

  /// 发起 PUT 请求
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.put(path,
        data: data, queryParameters: queryParameters, options: options);
  }

  /// 发起 DELETE 请求
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.delete(path,
        data: data, queryParameters: queryParameters, options: options);
  }
}
