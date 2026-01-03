import 'connection_config_service.dart';

/// Serviço para gerenciar configuração do servidor
/// @deprecated Use ConnectionConfigService diretamente
/// Mantido apenas para compatibilidade durante transição
class ServerConfigService {
  /// Verifica se o servidor está configurado
  /// @deprecated Use ConnectionConfigService.isConfigured()
  static bool isConfigured() {
    return ConnectionConfigService.isConfigured();
  }

  /// Obtém a URL do servidor salva
  /// @deprecated Use ConnectionConfigService.getServerUrl()
  static String? getServerUrl() {
    return ConnectionConfigService.getServerUrl();
  }

  /// Obtém a URL base da API (adiciona /api se necessário)
  /// @deprecated Use ConnectionConfigService.getApiUrl()
  static String getApiUrl() {
    return ConnectionConfigService.getApiUrl();
  }
}

