import 'package:flutter/foundation.dart';

/// Detecta o ambiente da aplicação (Produção ou Homologação)
class EnvironmentDetector {
  /// Detecta se é ambiente de produção
  /// 
  /// Usa kReleaseMode do Flutter:
  /// - true: Build de release (produção)
  /// - false: Build de debug (homologação/desenvolvimento)
  static bool get isProduction {
    return kReleaseMode;
  }
  
  /// Detecta se é ambiente de homologação
  static bool get isHomologacao {
    return !kReleaseMode;
  }
  
  /// Obtém o nome do ambiente
  static String get environmentName {
    return isProduction ? 'production' : 'homologation';
  }
  
  /// Obtém a URL do servidor baseado no ambiente
  static String getServerUrl() {
    if (isProduction) {
      return 'https://api.h4nd.com.br';
    } else {
      return 'https://api-hml.h4nd.com.br';
    }
  }
  
  /// Obtém a URL da API (com /api)
  static String getApiUrl() {
    final baseUrl = getServerUrl();
    return '$baseUrl/api';
  }
}

