import 'package:flutter/foundation.dart';
import '../storage/preferences_service.dart';
import '../constants/storage_keys.dart';
import '../../data/models/core/app_config.dart';
import 'app_config_service.dart';
import 'connection_config_service.dart';

/// Configuração de ambiente da aplicação
abstract class EnvConfig {
  String get apiBaseUrl;
  String get apiUrl;
  String get s3BaseUrl;
  bool get isProduction;
  Duration get requestTimeout;
}

/// Configuração baseada nas configs salvas do backend
/// A URL da API vem do ConnectionConfigService (configurada pelo usuário)
/// IMPORTANTE: NÃO usa o apiUrl do AppConfig salvo, sempre usa ConnectionConfigService.getApiUrl()
class SavedAppConfig implements EnvConfig {
  final AppConfig _config;

  SavedAppConfig(this._config) {
    debugPrint('📦 [SavedAppConfig] Criado com AppConfig:');
    debugPrint('   - AppConfig.s3BaseUrl: ${_config.s3BaseUrl}');
    debugPrint('   - AppConfig.environment: ${_config.environment}');
    debugPrint('   - ConnectionConfigService.getApiUrl() (USADO): ${ConnectionConfigService.getApiUrl()}');
  }

  @override
  String get apiBaseUrl {
    // A URL da API vem do ConnectionConfigService
    final serverUrl = ConnectionConfigService.getServerUrl() ?? '';
    if (serverUrl.isEmpty) {
      // Fallback para padrão se não tiver configurado
      return 'https://api-hml.h4nd.com.br';
    }
    return serverUrl;
  }

  @override
  String get apiUrl {
    // Usa ConnectionConfigService.getApiUrl() que já adiciona /api se necessário
    // IMPORTANTE: Sempre chama dinamicamente para garantir que use a URL atual
    final config = ConnectionConfigService.getCurrentConfig();
    final serverUrl = ConnectionConfigService.getServerUrl();
    final apiUrl = ConnectionConfigService.getApiUrl();
    
    debugPrint('🔍 [SavedAppConfig] apiUrl getter chamado:');
    debugPrint('   - config: ${config?.tipoConexao} - ${config?.serverName}');
    debugPrint('   - serverUrl: $serverUrl');
    debugPrint('   - apiUrl retornado: $apiUrl');
    
    if (apiUrl.isEmpty) {
      // Se não tiver configurado, retorna fallback
      debugPrint('⚠️ [SavedAppConfig] apiUrl vazio, usando fallback');
      return 'https://api-hml.h4nd.com.br/api';
    }
    debugPrint('✅ [SavedAppConfig] apiUrl: $apiUrl');
    return apiUrl;
  }

  @override
  String get s3BaseUrl {
    // ✅ Sempre usa a configuração do frontend (debug = hml, release = prod)
    // Ignora o s3BaseUrl que vem do backend para garantir consistência
    const bool isProd = bool.fromEnvironment('dart.vm.product', defaultValue: false);
    const bool forceProd = bool.fromEnvironment('FORCE_PROD', defaultValue: false);
    
    if (isProd || forceProd) {
      return 'https://h4nd-client.s3.us-east-1.amazonaws.com';
    } else {
      return 'https://h4nd-client-hml.s3.us-east-1.amazonaws.com';
    }
  }

  @override
  bool get isProduction => _config.environment == 'Production';

  @override
  Duration get requestTimeout => const Duration(seconds: 30);
}

/// Configuração de desenvolvimento (fallback)
class DevConfig implements EnvConfig {
  @override
  String get apiBaseUrl => 'https://api-hml.h4nd.com.br';
  
  @override
  String get apiUrl => '$apiBaseUrl/api';
  
  @override
  String get s3BaseUrl => 'https://h4nd-client-hml.s3.us-east-1.amazonaws.com';
  
  @override
  bool get isProduction => false;
  
  @override
  Duration get requestTimeout => const Duration(seconds: 30);
}

/// Configuração de produção (fallback)
class ProdConfig implements EnvConfig {
  @override
  String get apiBaseUrl => 'https://api.h4nd.com.br';
  
  @override
  String get apiUrl => '$apiBaseUrl/api';
  
  @override
  String get s3BaseUrl => 'https://h4nd-client.s3.us-east-1.amazonaws.com';
  
  @override
  bool get isProduction => true;
  
  @override
  Duration get requestTimeout => const Duration(seconds: 30);
}

/// Configuração dinâmica que lê do storage (legado - mantido para compatibilidade)
class DynamicConfig implements EnvConfig {
  final String _baseUrl;

  DynamicConfig(this._baseUrl);

  @override
  String get apiBaseUrl => _baseUrl;

  @override
  String get apiUrl => '$apiBaseUrl/api';
  
  @override
  String get s3BaseUrl => 'https://h4nd-client-hml.s3.us-east-1.amazonaws.com';
  
  @override
  bool get isProduction => false;

  @override
  Duration get requestTimeout => const Duration(seconds: 30);
}

/// Factory para obter configuração baseada no ambiente
class Environment {
  /// Obtém configuração, verificando primeiro as configs salvas do backend
  /// Se não tiver config salva, retorna null (para forçar configuração)
  static EnvConfig? getConfigOrNull() {
    // CRÍTICO: Primeiro verifica se há configuração de servidor via ConnectionConfigService
    // Isso é a fonte de verdade para a URL da API
    if (ConnectionConfigService.isConfigured()) {
      debugPrint('✅ [Environment] Servidor configurado via ConnectionConfigService');
      
      // Tenta carregar AppConfig salvo (para s3BaseUrl e environment)
      final savedAppConfig = AppConfigService.loadFromStorage();
      
      if (savedAppConfig != null) {
        debugPrint('✅ [Environment] Usando AppConfig salvo do backend');
        return SavedAppConfig(savedAppConfig);
      } else {
        // Se não houver AppConfig salvo, cria um mínimo com valores padrão
        // O SavedAppConfig vai usar ConnectionConfigService.getApiUrl() para a URL da API
        debugPrint('⚠️ [Environment] AppConfig não encontrado, criando mínimo');
        const bool isProd = bool.fromEnvironment('dart.vm.product', defaultValue: false);
        const bool forceProd = bool.fromEnvironment('FORCE_PROD', defaultValue: false);
        
        final minimalAppConfig = AppConfig(
          s3BaseUrl: (isProd || forceProd)
              ? 'https://h4nd-client.s3.us-east-1.amazonaws.com'
              : 'https://h4nd-client-hml.s3.us-east-1.amazonaws.com',
          environment: (isProd || forceProd) ? 'Production' : 'Development',
        );
        
        return SavedAppConfig(minimalAppConfig);
      }
    }
    
    // Fallback: verifica se tem URL do servidor salva (compatibilidade legado)
    final savedUrl = PreferencesService.getString(StorageKeys.serverUrl);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      debugPrint('⚠️ [Environment] Usando URL do servidor (legado)');
      return DynamicConfig(savedUrl);
    }
    
    return null;
  }
  
  /// Obtém configuração com fallback para padrão
  static EnvConfig get config {
    debugPrint('🔍 [Environment.config] Verificando configuração...');
    final savedConfig = getConfigOrNull();
    if (savedConfig != null) {
      debugPrint('✅ [Environment.config] Retornando: ${savedConfig.runtimeType}');
      debugPrint('   - apiUrl: ${savedConfig.apiUrl}');
      return savedConfig;
    }
    
    // Se não tiver config salva, usa configuração padrão baseada no ambiente
    const bool isProd = bool.fromEnvironment('dart.vm.product', defaultValue: false);
    const bool forceProd = bool.fromEnvironment('FORCE_PROD', defaultValue: false);
    
    debugPrint('⚠️ [Environment.config] NÃO encontrou config salva!');
    debugPrint('   - ConnectionConfigService.isConfigured(): ${ConnectionConfigService.isConfigured()}');
    debugPrint('   - ConnectionConfigService.getApiUrl(): ${ConnectionConfigService.getApiUrl()}');
    debugPrint('   - AppConfigService.loadFromStorage(): ${AppConfigService.loadFromStorage()}');
    debugPrint('📋 [Environment.config] Usando config padrão (isProd: $isProd, forceProd: $forceProd)');
    final defaultConfig = (isProd || forceProd) ? ProdConfig() : DevConfig();
    debugPrint('   - apiUrl do config padrão: ${defaultConfig.apiUrl}');
    return defaultConfig;
  }
}



