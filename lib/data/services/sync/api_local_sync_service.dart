import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/config/connection_config_service.dart';
import '../../models/core/api_response.dart';

/// Resultado de sincronização da API local
class ApiLocalSyncResult {
  final bool sucesso;
  final String? erro;
  final int tabelasProcessadas;
  final int registrosProcessados;
  final int registrosInseridos;
  final int registrosAtualizados;

  ApiLocalSyncResult({
    required this.sucesso,
    this.erro,
    this.tabelasProcessadas = 0,
    this.registrosProcessados = 0,
    this.registrosInseridos = 0,
    this.registrosAtualizados = 0,
  });

  factory ApiLocalSyncResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    
    if (data == null) {
      return ApiLocalSyncResult(
        sucesso: json['success'] == true,
        erro: json['message'] as String?,
      );
    }

    final tables = data['tables'] as List<dynamic>? ?? [];
    int totalProcessados = 0;
    int totalInseridos = 0;
    int totalAtualizados = 0;

    for (var table in tables) {
      if (table is Map<String, dynamic>) {
        totalProcessados += table['recordsProcessed'] as int? ?? 0;
        totalInseridos += table['recordsInserted'] as int? ?? 0;
        totalAtualizados += table['recordsUpdated'] as int? ?? 0;
      }
    }

    return ApiLocalSyncResult(
      sucesso: json['success'] == true,
      erro: json['message'] as String?,
      tabelasProcessadas: tables.length,
      registrosProcessados: totalProcessados,
      registrosInseridos: totalInseridos,
      registrosAtualizados: totalAtualizados,
    );
  }
}

/// Progresso de sincronização da API local
class ApiLocalSyncProgress {
  final String etapa;
  final int progresso; // 0-100
  final String mensagem;

  ApiLocalSyncProgress({
    required this.etapa,
    required this.progresso,
    required this.mensagem,
  });
}

/// Serviço para sincronização da API local (busca dados do servidor cloud)
class ApiLocalSyncService {
  final ApiClient _apiClient;

  ApiLocalSyncService({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  /// Verifica se está conectado ao servidor local
  bool get isLocalServer {
    final config = ConnectionConfigService.getCurrentConfig();
    return config?.isLocal ?? false;
  }

  /// Executa sincronização completa da API local
  /// O token JWT será adicionado automaticamente pelo AuthInterceptor
  Future<ApiLocalSyncResult> sincronizarCompleto({
    Function(ApiLocalSyncProgress)? onProgress,
  }) async {
    if (!isLocalServer) {
      throw Exception('Sincronização da API local só está disponível quando conectado ao servidor local');
    }

    try {
      onProgress?.call(ApiLocalSyncProgress(
        etapa: 'Iniciando',
        progresso: 0,
        mensagem: 'Iniciando sincronização do servidor cloud...',
      ));

      // Verificar qual URL está sendo usada
      final config = ConnectionConfigService.getCurrentConfig();
      final serverUrl = ConnectionConfigService.getServerUrl();
      final apiUrl = ConnectionConfigService.getApiUrl();
      
      debugPrint('🔄 [ApiLocalSyncService] Iniciando sincronização completa da API local...');
      debugPrint('📍 [ApiLocalSyncService] Config: ${config?.tipoConexao} - ${config?.serverName}');
      debugPrint('📍 [ApiLocalSyncService] Server URL: $serverUrl');
      debugPrint('📍 [ApiLocalSyncService] API URL: $apiUrl');
      debugPrint('📍 [ApiLocalSyncService] Endpoint: ${ApiEndpoints.syncApiLocalFull}');
      
      // Chama o endpoint /api/sync/full
      // O token JWT será adicionado automaticamente pelo AuthInterceptor no header Authorization
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.syncApiLocalFull,
        data: {}, // Body vazio - o token vem do header
      );

      if (response.data == null) {
        throw Exception('Resposta vazia da API local');
      }

      onProgress?.call(ApiLocalSyncProgress(
        etapa: 'Finalizando',
        progresso: 100,
        mensagem: 'Sincronização concluída',
      ));

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data!,
        (data) => data as Map<String, dynamic>? ?? {},
      );

      if (!apiResponse.success) {
        return ApiLocalSyncResult(
          sucesso: false,
          erro: apiResponse.message.isNotEmpty ? apiResponse.message : 'Erro desconhecido',
        );
      }

      debugPrint('✅ [ApiLocalSyncService] Sincronização completa concluída com sucesso');
      
      return ApiLocalSyncResult.fromJson(response.data!);
    } catch (e) {
      debugPrint('❌ [ApiLocalSyncService] Erro na sincronização: $e');
      return ApiLocalSyncResult(
        sucesso: false,
        erro: e.toString(),
      );
    }
  }

  /// Executa sincronização incremental da API local
  Future<ApiLocalSyncResult> sincronizarIncremental({
    DateTime? lastSync,
    Function(ApiLocalSyncProgress)? onProgress,
  }) async {
    if (!isLocalServer) {
      throw Exception('Sincronização da API local só está disponível quando conectado ao servidor local');
    }

    try {
      onProgress?.call(ApiLocalSyncProgress(
        etapa: 'Iniciando',
        progresso: 0,
        mensagem: 'Iniciando sincronização incremental...',
      ));

      debugPrint('🔄 [ApiLocalSyncService] Iniciando sincronização incremental da API local...');
      
      final body = <String, dynamic>{};
      if (lastSync != null) {
        body['lastSync'] = lastSync.toIso8601String();
      }

      // Chama o endpoint /api/sync/incremental
      // O token JWT será adicionado automaticamente pelo AuthInterceptor no header Authorization
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.syncApiLocalIncremental,
        data: body.isEmpty ? {} : body,
      );

      if (response.data == null) {
        throw Exception('Resposta vazia da API local');
      }

      onProgress?.call(ApiLocalSyncProgress(
        etapa: 'Finalizando',
        progresso: 100,
        mensagem: 'Sincronização incremental concluída',
      ));

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data!,
        (data) => data as Map<String, dynamic>? ?? {},
      );

      if (!apiResponse.success) {
        return ApiLocalSyncResult(
          sucesso: false,
          erro: apiResponse.message.isNotEmpty ? apiResponse.message : 'Erro desconhecido',
        );
      }

      debugPrint('✅ [ApiLocalSyncService] Sincronização incremental concluída com sucesso');
      
      return ApiLocalSyncResult.fromJson(response.data!);
    } catch (e) {
      debugPrint('❌ [ApiLocalSyncService] Erro na sincronização incremental: $e');
      return ApiLocalSyncResult(
        sucesso: false,
        erro: e.toString(),
      );
    }
  }
}

