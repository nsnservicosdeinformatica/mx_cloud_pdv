import 'package:flutter/foundation.dart';
import '../storage/preferences_service.dart';
import '../constants/storage_keys.dart';
import '../../data/models/core/app_config.dart';
import 'app_config_service.dart';
import 'server_config_service.dart';

/// Configuração de ambiente da aplicação
abstract class EnvConfig {
  String get apiBaseUrl;
  String get apiUrl;
  String get s3BaseUrl;
  bool get isProduction;
  Duration get requestTimeout;
}

/// Configuração baseada nas configs salvas do backend
/// A URL da API vem do ServerConfigService (configurada pelo usuário)
class SavedAppConfig implements EnvConfig {
  final AppConfig _config;

  SavedAppConfig(this._config);

  @override
  String get apiBaseUrl {
    // A URL da API vem do ServerConfigService (o que o usuário digitou)
    final serverUrl = ServerConfigService.getServerUrl() ?? '';
    if (serverUrl.isEmpty) {
      // Fallback para padrão se não tiver configurado
      return 'https://api-hml.h4nd.com.br';
    }
    return serverUrl;
  }

  @override
  String get apiUrl {
    // Usa ServerConfigService.getApiUrl() que já adiciona /api se necessário
    return ServerConfigService.getApiUrl();
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
    // Primeiro, tenta usar as configs salvas do backend
    final savedConfig = AppConfigService.loadFromStorage();
    if (savedConfig != null) {
      debugPrint('✅ [Environment] Usando config salva do backend');
      return SavedAppConfig(savedConfig);
    }
    
    // Fallback: verifica se tem URL do servidor salva (compatibilidade)
    final savedUrl = PreferencesService.getString(StorageKeys.serverUrl);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      debugPrint('⚠️ [Environment] Usando URL do servidor (legado)');
      return DynamicConfig(savedUrl);
    }
    
    return null;
  }
  
  /// Obtém configuração com fallback para padrão
  static EnvConfig get config {
    final savedConfig = getConfigOrNull();
    if (savedConfig != null) {
      return savedConfig;
    }
    
    // Se não tiver config salva, usa configuração padrão baseada no ambiente
    const bool isProd = bool.fromEnvironment('dart.vm.product', defaultValue: false);
    const bool forceProd = bool.fromEnvironment('FORCE_PROD', defaultValue: false);
    
    debugPrint('📋 [Environment] Usando config padrão (isProd: $isProd, forceProd: $forceProd)');
    return (isProd || forceProd) ? ProdConfig() : DevConfig();
  }
}



