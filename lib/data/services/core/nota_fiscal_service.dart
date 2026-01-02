import 'package:flutter/foundation.dart';
import '../../models/core/api_response.dart';
import '../../../core/printing/nfce_print_data.dart';
import '../../../core/network/api_client.dart';

/// Serviço para operações relacionadas a notas fiscais
class NotaFiscalService {
  final ApiClient _apiClient;

  NotaFiscalService(this._apiClient);

  /// Busca dados da NFC-e para impressão
  /// 
  /// GET /api/notas-fiscais/{notaFiscalId}/dados-impressao
  Future<ApiResponse<NfcePrintData?>> getDadosParaImpressao(String notaFiscalId) async {
    try {
      debugPrint('🔍 Buscando dados para impressão da NFC-e: $notaFiscalId');
      
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/notas-fiscais/$notaFiscalId/dados-impressao',
      );
      
      if (response.data == null) {
        return ApiResponse<NfcePrintData?>.error(
          message: 'Erro ao buscar dados para impressão',
        );
      }
      
      final data = response.data!;
      final nfceData = data['data'] as Map<String, dynamic>?;
      
      if (nfceData == null) {
        debugPrint('ℹ️ NFC-e não encontrada ou sem dados para impressão');
        return ApiResponse<NfcePrintData?>.success(
          data: null,
          message: data['message'] as String? ?? 'NFC-e não encontrada',
        );
      }
      
      final nfcePrintData = NfcePrintData.fromJson(nfceData);
      debugPrint('✅ Dados para impressão obtidos: ${nfcePrintData.numero}/${nfcePrintData.serie}');
      
      return ApiResponse<NfcePrintData?>.success(
        data: nfcePrintData,
        message: data['message'] as String? ?? 'Dados obtidos com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao buscar dados para impressão da NFC-e: $e');
      return ApiResponse<NfcePrintData?>.error(
        message: 'Erro ao buscar dados: ${e.toString()}',
      );
    }
  }
}

