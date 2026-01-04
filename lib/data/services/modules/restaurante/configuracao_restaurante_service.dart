import '../../../../core/network/api_client.dart';
import '../../../models/core/api_response.dart';
import '../../../models/modules/restaurante/configuracao_restaurante_dto.dart';
import 'package:flutter/foundation.dart';

/// Serviço para gerenciamento de configuração do restaurante
class ConfiguracaoRestauranteService {
  final ApiClient _apiClient;
  
  ConfiguracaoRestauranteService({required ApiClient apiClient}) 
      : _apiClient = apiClient;

  /// Busca a configuração do restaurante da empresa atual
  /// GET /api/configuracao-restaurante
  Future<ApiResponse<ConfiguracaoRestauranteDto?>> getConfiguracao() async {
    try {
      debugPrint('📋 Buscando configuração do restaurante...');
      
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/configuracao-restaurante',
      );
      
      if (response.data == null) {
        return ApiResponse<ConfiguracaoRestauranteDto?>.error(
          message: 'Erro ao buscar configuração',
        );
      }
      
      final data = response.data!;
      final configData = data['data'] as Map<String, dynamic>?;
      
      if (configData == null) {
        // Configuração não encontrada (pode ser null se não foi criada ainda)
        debugPrint('⚠️ Configuração do restaurante não encontrada');
        return ApiResponse<ConfiguracaoRestauranteDto?>.success(
          data: null,
          message: data['message'] as String? ?? 'Configuração não encontrada',
        );
      }
      
      final config = ConfiguracaoRestauranteDto.fromJson(configData);
      final tipoControle = config.isControlePorMesa 
          ? "PorMesa" 
          : (config.isControlePorComanda 
              ? "PorComanda" 
              : "PorMesaOuComanda");
      debugPrint('✅ Configuração encontrada: TipoControleVenda=${config.tipoControleVenda} ($tipoControle)');
      
      return ApiResponse<ConfiguracaoRestauranteDto?>.success(
        data: config,
        message: data['message'] as String? ?? 'Configuração encontrada com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao buscar configuração do restaurante: $e');
      return ApiResponse<ConfiguracaoRestauranteDto?>.error(
        message: 'Erro ao buscar configuração: ${e.toString()}',
      );
    }
  }
}

