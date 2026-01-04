import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/env_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// Cliente HTTP base usando Dio
class ApiClient {
  late final Dio _dio;
  final EnvConfig _config;

  ApiClient({
    required EnvConfig config,
    required AuthInterceptor authInterceptor,
  }) : _config = config {
    final apiUrl = config.apiUrl;
    debugPrint('🌐 [ApiClient] Criando ApiClient com baseUrl: $apiUrl');
    
    _dio = Dio(
      BaseOptions(
        baseUrl: apiUrl,
        connectTimeout: config.requestTimeout,
        receiveTimeout: config.requestTimeout,
        sendTimeout: config.requestTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Adiciona interceptors
    // IMPORTANTE: O interceptor de atualização de URL deve ser o primeiro
    // para garantir que o baseUrl seja atualizado antes de qualquer outra operação
    _dio.interceptors.addAll([
      _DynamicBaseUrlInterceptor(_config, _dio),
      authInterceptor,
      ErrorInterceptor(),
      if (!config.isProduction) LoggingInterceptor(),
    ]);
  }

  /// GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    // FORÇA atualização do baseUrl antes de cada requisição
    final currentApiUrl = _config.apiUrl;
    if (currentApiUrl.isNotEmpty) {
      _dio.options.baseUrl = currentApiUrl;
      debugPrint('🔧 [ApiClient.get] baseUrl FORÇADO para: $currentApiUrl');
    }
    
    // Usa URL absoluta diretamente - isso garante que o Dio use a URL correta
    final url = path.startsWith('http') ? path : '$currentApiUrl$path';
    debugPrint('🌐 [ApiClient.get] Fazendo GET para: $url');
    
    // Cria um Dio temporário com baseUrl vazio para usar URL absoluta
    final dioForRequest = Dio(_dio.options.copyWith(baseUrl: ''));
    // Copia os interceptors do Dio original
    dioForRequest.interceptors.addAll(_dio.interceptors);
    
    return await dioForRequest.get<T>(
      url,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    // FORÇA atualização do baseUrl antes de cada requisição
    final currentApiUrl = _config.apiUrl;
    if (currentApiUrl.isNotEmpty) {
      _dio.options.baseUrl = currentApiUrl;
      debugPrint('🔧 [ApiClient.post] baseUrl FORÇADO para: $currentApiUrl');
    }
    
    // Usa URL absoluta diretamente - isso garante que o Dio use a URL correta
    final url = path.startsWith('http') ? path : '$currentApiUrl$path';
    debugPrint('🌐 [ApiClient.post] Fazendo POST para: $url');
    
    // Cria um Dio temporário com baseUrl vazio para usar URL absoluta
    final dioForRequest = Dio(_dio.options.copyWith(baseUrl: ''));
    // Copia os interceptors do Dio original
    dioForRequest.interceptors.addAll(_dio.interceptors);
    
    return await dioForRequest.post<T>(
      url,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    // Atualiza o baseUrl antes de cada requisição para garantir que use a URL atual
    _updateBaseUrlIfNeeded();
    return await _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    // Atualiza o baseUrl antes de cada requisição para garantir que use a URL atual
    _updateBaseUrlIfNeeded();
    return await _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    // Atualiza o baseUrl antes de cada requisição para garantir que use a URL atual
    _updateBaseUrlIfNeeded();
    return await _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Atualiza o baseUrl dinamicamente (útil quando a configuração muda)
  void updateBaseUrl(String newBaseUrl) {
    debugPrint('🔄 [ApiClient] Atualizando baseUrl: ${_dio.options.baseUrl} -> $newBaseUrl');
    _dio.options.baseUrl = newBaseUrl;
  }

  /// Obtém o baseUrl atual
  String get baseUrl => _dio.options.baseUrl;

  /// Atualiza o baseUrl se necessário (verifica a URL atual do EnvConfig)
  void _updateBaseUrlIfNeeded() {
    final currentApiUrl = _config.apiUrl;
    debugPrint('🔍 [ApiClient] _updateBaseUrlIfNeeded:');
    debugPrint('   - currentApiUrl (do EnvConfig): $currentApiUrl');
    debugPrint('   - _dio.options.baseUrl (atual): ${_dio.options.baseUrl}');
    debugPrint('   - _config tipo: ${_config.runtimeType}');
    
    if (currentApiUrl.isNotEmpty && currentApiUrl != _dio.options.baseUrl) {
      debugPrint('🔄 [ApiClient] Atualizando baseUrl antes da requisição: ${_dio.options.baseUrl} -> $currentApiUrl');
      _dio.options.baseUrl = currentApiUrl;
      debugPrint('✅ [ApiClient] baseUrl atualizado para: ${_dio.options.baseUrl}');
    } else {
      debugPrint('✅ [ApiClient] baseUrl já está correto: $currentApiUrl');
    }
  }
}

/// Interceptor que atualiza o baseUrl dinamicamente antes de cada requisição
/// Isso garante que sempre use a URL atual do EnvConfig, mesmo quando a configuração muda
class _DynamicBaseUrlInterceptor extends Interceptor {
  final EnvConfig _config;
  final Dio _dio;

  _DynamicBaseUrlInterceptor(this._config, this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Atualiza o baseUrl dinamicamente antes de cada requisição
    final currentApiUrl = _config.apiUrl;
    debugPrint('🔍 [_DynamicBaseUrlInterceptor] onRequest:');
    debugPrint('   - currentApiUrl (do EnvConfig): $currentApiUrl');
    debugPrint('   - _dio.options.baseUrl (atual): ${_dio.options.baseUrl}');
    debugPrint('   - options.baseUrl: ${options.baseUrl}');
    debugPrint('   - options.path: ${options.path}');
    
    // Verifica se o path já é uma URL absoluta (começa com http:// ou https://)
    final isAbsoluteUrl = options.path.startsWith('http://') || options.path.startsWith('https://');
    
    if (isAbsoluteUrl) {
      // Se o path já é uma URL absoluta, não precisa atualizar o baseUrl
      // O Dio vai usar o path diretamente
      debugPrint('✅ [_DynamicBaseUrlInterceptor] Path já é URL absoluta, usando diretamente: ${options.path}');
      handler.next(options);
      return;
    }
    
    // Se não for URL absoluta, atualiza o baseUrl e concatena normalmente
    if (currentApiUrl.isNotEmpty && currentApiUrl != _dio.options.baseUrl) {
      debugPrint('🔄 [_DynamicBaseUrlInterceptor] Atualizando baseUrl: ${_dio.options.baseUrl} -> $currentApiUrl');
      _dio.options.baseUrl = currentApiUrl;
      debugPrint('✅ [_DynamicBaseUrlInterceptor] baseUrl atualizado para: ${_dio.options.baseUrl}');
    }
    
    // Garante que a URL final está correta
    final finalUrl = '${_dio.options.baseUrl}${options.path}';
    debugPrint('🌐 [_DynamicBaseUrlInterceptor] URL final da requisição: $finalUrl');
    
    handler.next(options);
  }
}



