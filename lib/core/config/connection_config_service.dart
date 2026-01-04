import 'package:flutter/foundation.dart';
import '../storage/preferences_service.dart';
import 'app_connection_config.dart';
import 'environment_detector.dart';
import 'app_config_service.dart';

/// Serviço para gerenciar configuração de conexão do app
class ConnectionConfigService {
  static const String _configKey = 'app_connection_config';
  
  /// Carrega configuração salva
  static AppConnectionConfig? loadConfig() {
    final saved = PreferencesService.getString(_configKey);
    if (saved == null || saved.isEmpty) {
      return null;
    }
    
    try {
      return AppConnectionConfig.fromJsonString(saved);
    } catch (e) {
      debugPrint('❌ [ConnectionConfigService] Erro ao carregar config: $e');
      return null;
    }
  }
  
  /// Salva configuração
  static Future<bool> saveConfig(AppConnectionConfig config) async {
    try {
      final jsonString = config.toJsonString();
      final saved = await PreferencesService.setString(_configKey, jsonString);
      
      if (saved) {
        debugPrint('✅ [ConnectionConfigService] Config salva: ${config.toString()}');
      }
      
      return saved;
    } catch (e) {
      debugPrint('❌ [ConnectionConfigService] Erro ao salvar config: $e');
      return false;
    }
  }
  
  /// Configura servidor online (H4ND)
  /// Detecta automaticamente se é produção ou homologação
  static Future<bool> configurarServidorOnline() async {
    final isProd = EnvironmentDetector.isProduction;
    final serverUrl = EnvironmentDetector.getServerUrl();
    
    final config = AppConnectionConfig(
      tipoConexao: TipoConexao.remoto,
      ambiente: isProd ? Ambiente.producao : Ambiente.homologacao,
      serverUrl: serverUrl,
      serverName: isProd ? 'Produção (H4ND)' : 'Homologação (H4ND)',
    );
    
    final saved = await saveConfig(config);
    
    if (saved) {
      // Buscar configurações do backend
      debugPrint('🔧 [ConnectionConfigService] Buscando configurações do backend...');
      await AppConfigService.fetchFromBackend(serverUrl);
    }
    
    return saved;
  }
  
  /// Configura servidor local
  static Future<bool> configurarServidorLocal(String serverUrl) async {
    // Normalizar URL
    String normalizedUrl = serverUrl.trim();
    if (!normalizedUrl.startsWith('http://') && 
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'http://$normalizedUrl';
    }
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }
    
    final config = AppConnectionConfig(
      tipoConexao: TipoConexao.local,
      ambiente: null, // Local não tem ambiente
      serverUrl: normalizedUrl,
      serverName: 'Servidor Local',
    );
    
    final saved = await saveConfig(config);
    
    if (saved) {
      // Buscar configurações do backend
      debugPrint('🔧 [ConnectionConfigService] Buscando configurações do backend...');
      await AppConfigService.fetchFromBackend(normalizedUrl);
    }
    
    return saved;
  }
  
  /// Verifica se está configurado
  static bool isConfigured() {
    return loadConfig() != null;
  }
  
  /// Obtém configuração atual
  static AppConnectionConfig? getCurrentConfig() {
    return loadConfig();
  }
  
  /// Obtém a URL do servidor atual
  static String? getServerUrl() {
    final config = loadConfig();
    return config?.serverUrl;
  }
  
  /// Obtém a URL da API (com /api)
  static String getApiUrl() {
    final serverUrl = getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      return '';
    }
    
    // Se já termina com /api, retorna como está
    if (serverUrl.endsWith('/api')) {
      return serverUrl;
    }
    
    // Adiciona /api
    return '$serverUrl/api';
  }
  
  /// Limpa configuração
  static Future<bool> clearConfig() async {
    return await PreferencesService.remove(_configKey);
  }
}

