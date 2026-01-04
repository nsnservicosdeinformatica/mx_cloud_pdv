import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/config/env_config.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/network/interceptors/auth_interceptor.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/storage/preferences_service.dart';
import '../../../core/utils/jwt_utils.dart';
import '../../models/auth/login_request.dart';
import '../../models/auth/login_response.dart';
import '../../models/auth/refresh_token_request.dart';
import '../../models/auth/refresh_token_response.dart';
import '../../models/auth/user.dart';
import '../../models/auth/empresa.dart';
import 'dart:convert';

/// Serviço de autenticação
/// Movido para data/services/core seguindo o padrão do Angular
class AuthService {
  final EnvConfig _config;
  final SecureStorageService _secureStorage;
  late final ApiClient _apiClient;
  final Dio _dio;
  User? _currentUser;
  bool _isRefreshing = false;

  AuthService({
    required EnvConfig config,
    required SecureStorageService secureStorage,
  })  : _config = config,
        _secureStorage = secureStorage,
        _dio = Dio(
          BaseOptions(
            baseUrl: config.apiUrl,
            connectTimeout: config.requestTimeout,
            receiveTimeout: config.requestTimeout,
          ),
        ) {
    // Cria o ApiClient com o AuthInterceptor
    final authInterceptor = AuthInterceptor(this);
    _apiClient = ApiClient(
      config: config,
      authInterceptor: authInterceptor,
    );
    
    // Carrega dados armazenados
    _loadStoredAuth();
  }

  /// Instância do Dio para uso no interceptor
  Dio get dio => _dio;

  /// Instância do ApiClient para uso em outros serviços
  ApiClient get apiClient => _apiClient;

  /// Realiza o login
  Future<LoginResponse> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final request = LoginRequest(
      email: email,
      senha: password,
      lembrame: rememberMe,
      ipAddress: await _getClientIP(),
    );

    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.login,
        data: request.toJson(),
      );

      final loginResponse = LoginResponse.fromJson(response.data!);

      if (loginResponse.success) {
        await _setAuthData(loginResponse);
        await PreferencesService.setBool(StorageKeys.rememberMe, rememberMe);
      }

      return loginResponse;
    } catch (e) {
      // Se for um erro de resposta da API, tenta extrair a mensagem
      if (e is DioException && e.response != null) {
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          if (data['message'] != null) {
            throw Exception(data['message'] as String);
          }
          if (data['errors'] != null && data['errors'] is List) {
            final errors = data['errors'] as List;
            if (errors.isNotEmpty) {
              throw Exception(errors.first.toString());
            }
          }
        }
      }
      final errorMessage = _handleError(e);
      throw Exception(errorMessage);
    }
  }

  /// Realiza o logout
  Future<void> logout() async {
    try {
      final refreshToken = await _secureStorage.read(StorageKeys.refreshToken);
      if (refreshToken != null) {
        final request = RefreshTokenRequest(refreshToken: refreshToken);
        await _apiClient.post(
          ApiEndpoints.revoke,
          data: request.toJson(),
        );
      }
    } catch (e) {
      // Continua com logout mesmo se falhar ao revogar
      print('Erro ao revogar token: $e');
    } finally {
      await _clearAuthData();
    }
  }

  /// Renova o token usando refresh token (SEMPRE tenta, mesmo que token pareça válido)
  /// Usado quando recebe 401 do servidor
  Future<bool> refreshToken() async {
    if (_isRefreshing) {
      // Aguarda a renovação em andamento
      debugPrint('AuthService: Refresh já em andamento, aguardando...');
      while (_isRefreshing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      // Verifica se o refresh foi bem-sucedido
      final token = await getToken();
      return token != null && !JwtUtils.isExpired(token);
    }

    final refreshTokenValue = await _secureStorage.read(StorageKeys.refreshToken);
    if (refreshTokenValue == null || refreshTokenValue.isEmpty) {
      debugPrint('AuthService: Refresh token não encontrado');
      return false;
    }

    _isRefreshing = true;
    debugPrint('AuthService: Iniciando refresh token...');

    try {
      final request = RefreshTokenRequest(refreshToken: refreshTokenValue);
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.refresh,
        data: request.toJson(),
      );

      final refreshResponse = RefreshTokenResponse.fromJson(response.data!);

      if (refreshResponse.success) {
        await _setTokens(
          refreshResponse.data.token,
          refreshResponse.data.refreshToken,
        );

        // Atualiza dados do usuário do novo token
        await _updateUserFromToken(refreshResponse.data.token);
        _isRefreshing = false;
        debugPrint('AuthService: Token renovado com sucesso');
        return true;
      }

      _isRefreshing = false;
      debugPrint('AuthService: Falha ao renovar token - resposta não sucedida');
      return false;
    } catch (e) {
      _isRefreshing = false;
      debugPrint('AuthService: Erro ao renovar token: $e');
      // Não faz logout aqui, deixa o interceptor decidir
      return false;
    }
  }

  /// Renova o token usando refresh token (só se necessário)
  /// Verifica se o token está expirado antes de tentar refresh
  Future<bool> refreshTokenIfNeeded() async {
    final token = await getToken();
    if (token != null && !JwtUtils.isExpired(token)) {
      return true; // Token ainda válido
    }

    // Token expirado ou não existe, tenta refresh
    return await refreshToken();
  }

  /// Obtém o token atual
  Future<String?> getToken() async {
    return await _secureStorage.read(StorageKeys.token);
  }

  /// Obtém o refresh token
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(StorageKeys.refreshToken);
  }

  /// Verifica se o usuário está autenticado
  /// Se o token estiver expirado, tenta fazer refresh automaticamente
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    if (token != null && !JwtUtils.isExpired(token)) {
      return true;
    }

    // Se o token expirou, tenta fazer refresh automaticamente
    final refreshTokenValue = await getRefreshToken();
    if (refreshTokenValue == null || refreshTokenValue.isEmpty) {
      return false;
    }

    // Tenta fazer refresh do token
    debugPrint('AuthService: Token expirado, tentando refresh automático...');
    final refreshed = await refreshToken();
    if (refreshed) {
      debugPrint('AuthService: Token renovado com sucesso na verificação de autenticação');
      return true;
    }

    debugPrint('AuthService: Falha ao renovar token na verificação de autenticação');
    return false;
  }

  /// Obtém o usuário atual
  User? getCurrentUser() {
    return _currentUser;
  }

  /// Verifica se o usuário é SuperAdmin
  bool isSuperAdmin() {
    return _currentUser?.isSuperAdmin ?? false;
  }

  /// Obtém o setor da organização do JWT
  Future<int?> getSetorOrganizacao() async {
    try {
      final token = await getToken();
      if (token == null) return null;
      
      // Tenta obter o claim como int primeiro
      final setor = JwtUtils.getClaim<int>(token, 'setor');
      if (setor != null) return setor;
      
      // Se não funcionar, tenta como dynamic e converte
      final dynamicSetor = JwtUtils.getClaim<dynamic>(token, 'setor');
      if (dynamicSetor == null) return null;
      
      // Converte para int se possível
      if (dynamicSetor is int) return dynamicSetor;
      if (dynamicSetor is String) return int.tryParse(dynamicSetor);
      
      return null;
    } catch (e) {
      print('Erro ao obter setor do JWT: $e');
      return null;
    }
  }

  /// Verifica se é setor Restaurante
  Future<bool> isSetorRestaurante() async {
    final setor = await getSetorOrganizacao();
    return setor == 2;
  }

  /// Verifica se é setor Oficina
  Future<bool> isSetorOficina() async {
    final setor = await getSetorOrganizacao();
    return setor == 3;
  }

  /// Verifica se é setor Varejo
  Future<bool> isSetorVarejo() async {
    final setor = await getSetorOrganizacao();
    return setor == null || setor == 1;
  }

  /// Define os tokens
  Future<void> _setTokens(String token, String refreshToken) async {
    await _secureStorage.write(StorageKeys.token, token);
    await _secureStorage.write(StorageKeys.refreshToken, refreshToken);
  }

  /// Salva os dados de autenticação
  Future<void> _setAuthData(LoginResponse response) async {
    final data = response.data;
    
    // Extrai dados do token
    final tokenData = JwtUtils.decode(data.token);
    final nomeDoJwt = tokenData?['nome'] ?? 
                      tokenData?['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'] ?? 
                      data.nome;

    // Cria objeto User
    _currentUser = User(
      id: data.tenantId,
      name: nomeDoJwt ?? data.email.split('@')[0],
      email: data.email,
      role: data.isSuperAdmin ? 'SuperAdmin' : 'Usuário',
      isSuperAdmin: data.isSuperAdmin,
    );

    await _setTokens(data.token, data.refreshToken);
    await _secureStorage.write(
      StorageKeys.user,
      jsonEncode(_currentUser!.toJson()),
    );
    
    // Extrai e salva empresas do JWT
    final empresas = _getEmpresasFromToken(data.token);
    if (empresas != null && empresas.isNotEmpty) {
      await _saveEmpresas(empresas);
      // Seleciona a primeira empresa automaticamente
      await setSelectedEmpresa(empresas[0].id);
    }
  }

  /// Atualiza dados do usuário a partir do token
  Future<void> _updateUserFromToken(String token) async {
    final tokenData = JwtUtils.decode(token);
    if (tokenData == null) return;

    final nomeDoJwt = tokenData['nome'] ?? 
                      tokenData['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'];
    final emailDoJwt = tokenData['email'] ?? 
                       tokenData['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'];
    final isSuperAdminDoJwt = tokenData['isSuperAdmin'] == 'True' || 
                               tokenData['isSuperAdmin'] == true;

    if (_currentUser != null && nomeDoJwt != null) {
      _currentUser = User(
        id: _currentUser!.id,
        name: nomeDoJwt,
        email: emailDoJwt ?? _currentUser!.email,
        role: isSuperAdminDoJwt ? 'SuperAdmin' : 'Usuário',
        isSuperAdmin: isSuperAdminDoJwt || _currentUser!.isSuperAdmin,
      );

      await _secureStorage.write(
        StorageKeys.user,
        jsonEncode(_currentUser!.toJson()),
      );
    }
  }

  /// Carrega dados de autenticação armazenados
  Future<void> _loadStoredAuth() async {
    final token = await _secureStorage.read(StorageKeys.token);
    final userStr = await _secureStorage.read(StorageKeys.user);

    if (token != null && userStr != null) {
      try {
        _currentUser = User.fromJson(jsonDecode(userStr));
        
        // Garante que empresas estejam em cache
        await ensureEmpresasFromTokenCache();
      } catch (e) {
        await _clearAuthData();
      }
    }
  }

  /// Limpa todos os dados de autenticação
  Future<void> _clearAuthData() async {
    await _secureStorage.deleteAll();
    await PreferencesService.remove(StorageKeys.empresas);
    await PreferencesService.remove(StorageKeys.selectedEmpresa);
    _currentUser = null;
  }

  /// Extrai empresas do JWT
  List<Empresa>? _getEmpresasFromToken(String token) {
    try {
      final tokenData = JwtUtils.decode(token);
      if (tokenData != null && tokenData['empresas'] != null) {
        final empresasJson = jsonDecode(tokenData['empresas'] as String);
        if (empresasJson is List) {
          return empresasJson
              .map((e) => Empresa.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      print('Erro ao extrair empresas do JWT: $e');
    }
    return null;
  }

  /// Salva empresas no storage
  Future<void> _saveEmpresas(List<Empresa> empresas) async {
    final empresasJson = jsonEncode(
      empresas.map((e) => e.toJson()).toList(),
    );
    await PreferencesService.setString(StorageKeys.empresas, empresasJson);
  }

  /// Obtém a lista de empresas disponíveis
  Future<List<Empresa>> getEmpresas() async {
    try {
      final empresasStr = PreferencesService.getString(StorageKeys.empresas);
      if (empresasStr != null) {
        final empresasJson = jsonDecode(empresasStr) as List;
        return empresasJson
            .map((e) => Empresa.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Erro ao obter empresas: $e');
    }
    return [];
  }

  /// Garante que a lista de empresas esteja em cache a partir do JWT atual
  Future<void> ensureEmpresasFromTokenCache() async {
    final token = await getToken();
    if (token == null) return;
    
    final empresas = _getEmpresasFromToken(token);
    if (empresas != null && empresas.isNotEmpty) {
      await _saveEmpresas(empresas);
      final selectedEmpresa = await getSelectedEmpresa();
      if (selectedEmpresa == null) {
        await setSelectedEmpresa(empresas[0].id);
      }
    }
  }

  /// Obtém a empresa selecionada
  Future<String?> getSelectedEmpresa() async {
    return PreferencesService.getString(StorageKeys.selectedEmpresa);
  }

  /// Define a empresa selecionada
  Future<void> setSelectedEmpresa(String empresaId) async {
    await PreferencesService.setString(StorageKeys.selectedEmpresa, empresaId);
  }

  /// Verifica se o usuário tem múltiplas empresas
  Future<bool> hasMultipleEmpresas() async {
    final empresas = await getEmpresas();
    return empresas.length > 1;
  }

  /// Obtém o IP do cliente (simulado)
  Future<String> _getClientIP() async {
    // Em produção, pode usar um serviço para obter o IP real
    // Por enquanto retorna um IP padrão ou vazio se não disponível
    try {
      // Pode implementar lógica para obter IP real aqui
      return '127.0.0.1';
    } catch (e) {
      return '127.0.0.1';
    }
  }

  /// Trata erros
  String _handleError(dynamic error) {
    if (error is DioException) {
      if (error.response != null) {
        final data = error.response?.data;
        if (data is Map && data['message'] != null) {
          return data['message'];
        }
        return 'Erro ao realizar login';
      }
      return 'Erro de conexão. Verifique sua internet.';
    }
    return 'Erro desconhecido';
  }
}


