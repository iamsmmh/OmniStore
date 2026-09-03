import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import '../constants/app_constants.dart';
import '../logger/app_logger.dart';

final _logger = AppLogger.getLogger('HttpClient');

class HttpClient {
  late final Dio _dio;

  HttpClient() {
    _dio = Dio(BaseOptions(
      connectTimeout: AppConstants.httpTimeout,
      receiveTimeout: AppConstants.httpTimeout,
      sendTimeout: AppConstants.httpTimeout,
      headers: {
        'Accept': 'application/json',
        'User-Agent': '${AppConstants.appName}/${AppConstants.appVersion}',
      },
    ));

    _dio.interceptors.addAll([
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => _logger.fine(obj.toString()),
      ),
      RetryInterceptor(
        dio: _dio,
        retries: AppConstants.maxRetries,
        retryDelay: AppConstants.retryDelay,
      ),
    ]);
  }

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      _logger.severe('GET request failed: $path', e);
      rethrow;
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      _logger.severe('POST request failed: $path', e);
      rethrow;
    }
  }

  Future<Response<dynamic>> download(
    String urlPath,
    String savePath, {
    void Function(int, int)? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.download(
        urlPath,
        savePath,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      );
    } catch (e) {
      _logger.severe('Download failed: $urlPath', e);
      rethrow;
    }
  }
}

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int retries;
  final Duration retryDelay;
  final _logger = AppLogger.getLogger('RetryInterceptor');

  RetryInterceptor({
    required this.dio,
    required this.retries,
    required this.retryDelay,
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != null &&
        err.response!.statusCode! < 500) {
      return handler.next(err);
    }

    for (int i = 0; i < retries; i++) {
      try {
        await Future.delayed(retryDelay * (i + 1));
        final response = await dio.request(
          err.requestOptions.path,
          options: Options(
            method: err.requestOptions.method,
            headers: err.requestOptions.headers,
          ),
          data: err.requestOptions.data,
          queryParameters: err.requestOptions.queryParameters,
        );
        return handler.resolve(response);
      } catch (e) {
        _logger.warning('Retry ${i + 1} failed', e);
      }
    }

    return handler.next(err);
  }
}
