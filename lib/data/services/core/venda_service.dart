import '../../../core/network/api_client.dart';
import '../../../core/payment/payment_transaction_data.dart';
import '../../models/core/api_response.dart';
import '../../models/core/vendas/venda_dto.dart';
import '../../models/core/vendas/venda_resumo_dto.dart';
import 'package:flutter/foundation.dart';

/// Serviço para gerenciamento de vendas
class VendaService {
  final ApiClient _apiClient;
  
  VendaService({required ApiClient apiClient}) : _apiClient = apiClient;
  
  /// Registra um pagamento em uma ou múltiplas vendas
  /// 
  /// Se vendaIds for fornecido (lista), usa POST /api/vendas/pagamentos (novo endpoint unificado)
  /// Se apenas vendaId for fornecido, usa POST /api/vendas/{vendaId}/pagamentos (compatibilidade)
  /// 
  /// Quando múltiplas vendas são fornecidas, o backend agrupa automaticamente e processa pagamento total.
  Future<ApiResponse<VendaDto>> registrarPagamento({
    String? vendaId, // Opcional: para compatibilidade com código antigo
    List<String>? vendaIds, // Lista de IDs (novo formato unificado)
    required double valor,
    required String formaPagamento,
    required int tipoFormaPagamento, // TipoFormaPagamento enum
    int numeroParcelas = 1,
    String? bandeiraCartao,
    String? identificadorTransacao,
    List<Map<String, dynamic>>? produtos, // Lista opcional de produtos para nota fiscal (restaurante)
    PaymentTransactionData? transactionData, // Dados padronizados da transação
    String? clienteCPF, // CPF do cliente para nota fiscal
  }) async {
    try {
      // Determinar lista de IDs a usar
      final idsParaUsar = vendaIds ?? (vendaId != null ? [vendaId] : null);
      
      if (idsParaUsar == null || idsParaUsar.isEmpty) {
        return ApiResponse<VendaDto>.error(
          message: 'Deve ser fornecido vendaId ou vendaIds',
        );
      }
      
      debugPrint('📤 Registrando pagamento: Vendas=${idsParaUsar.join(", ")}, Valor=$valor, Forma=$formaPagamento');
      
      final payload = {
        'vendaIds': idsParaUsar, // Sempre incluir lista de IDs
        'valor': valor,
        'formaPagamento': formaPagamento,
        'tipoFormaPagamento': tipoFormaPagamento,
        'numeroParcelas': numeroParcelas,
        if (bandeiraCartao != null) 'bandeiraCartao': bandeiraCartao,
        // identificadorTransacaoPIX só para PIX, não para cartão
        // Para cartão, usa os campos de transação padronizados
        if (identificadorTransacao != null && tipoFormaPagamento == 4) 
          'identificadorTransacaoPIX': identificadorTransacao,
        if (produtos != null && produtos.isNotEmpty) 'produtos': produtos,
        if (clienteCPF != null) 'clienteCPF': clienteCPF,
        
        // Campos de transação padronizados (se disponíveis)
        if (transactionData != null) ...transactionData.toMap(),
        
        // Campos legados para compatibilidade (usar cardBrandName se disponível)
        if (transactionData?.cardBrandName != null && bandeiraCartao == null) 
          'bandeiraCartao': transactionData!.cardBrandName,
      };
      
      debugPrint('📤 Payload do pagamento: $payload');
      
      // Sempre usar o novo endpoint unificado
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/vendas/pagamentos',
        data: payload,
      );
      
      if (response.data == null) {
        return ApiResponse<VendaDto>.error(
          message: 'Erro ao registrar pagamento',
        );
      }
      
      final data = response.data!;
      final vendaData = data['data'] as Map<String, dynamic>?;
      
      if (vendaData == null) {
        return ApiResponse<VendaDto>.error(
          message: data['message'] as String? ?? 'Erro ao registrar pagamento',
        );
      }
      
      final venda = VendaDto.fromJson(vendaData);
      debugPrint('✅ Pagamento registrado com sucesso. Venda: ${venda.id}');
      
      return ApiResponse<VendaDto>.success(
        data: venda,
        message: data['message'] as String? ?? 'Pagamento registrado com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao registrar pagamento: $e');
      return ApiResponse<VendaDto>.error(
        message: 'Erro ao registrar pagamento: ${e.toString()}',
      );
    }
  }
  
  /// Busca uma venda por ID
  Future<ApiResponse<VendaDto>> getVendaById(String vendaId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/vendas/$vendaId',
      );
      
      if (response.data == null) {
        return ApiResponse<VendaDto>.error(
          message: 'Venda não encontrada',
        );
      }
      
      final data = response.data!;
      final vendaData = data['data'] as Map<String, dynamic>?;
      
      if (vendaData == null) {
        return ApiResponse<VendaDto>.error(
          message: data['message'] as String? ?? 'Venda não encontrada',
        );
      }
      
      final venda = VendaDto.fromJson(vendaData);
      return ApiResponse<VendaDto>.success(
        data: venda,
        message: data['message'] as String? ?? 'Venda encontrada',
      );
    } catch (e) {
      return ApiResponse<VendaDto>.error(
        message: 'Erro ao buscar venda: ${e.toString()}',
      );
    }
  }

  /// Busca venda aberta por comanda (se existir)
  /// 
  /// GET /api/vendas/por-comanda/{comandaId}
  Future<ApiResponse<VendaDto?>> getVendaAbertaPorComanda(String comandaId) async {
    try {
      debugPrint('🔍 Buscando venda aberta da comanda: $comandaId');
      
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/vendas/por-comanda/$comandaId',
      );
      
      if (response.data == null) {
        return ApiResponse<VendaDto?>.error(
          message: 'Erro ao buscar venda',
        );
      }
      
      final data = response.data!;
      final vendaData = data['data'] as Map<String, dynamic>?;
      
      if (vendaData == null) {
        // Venda não encontrada (pode ser null se não houver venda aberta)
        debugPrint('ℹ️ Nenhuma venda aberta encontrada para a comanda');
        return ApiResponse<VendaDto?>.success(
          data: null,
          message: data['message'] as String? ?? 'Nenhuma venda aberta encontrada',
        );
      }
      
      final venda = VendaDto.fromJson(vendaData);
      debugPrint('✅ Venda aberta encontrada: ${venda.id}, MesaId: ${venda.mesaId}');
      
      return ApiResponse<VendaDto?>.success(
        data: venda,
        message: data['message'] as String? ?? 'Venda encontrada',
      );
    } catch (e) {
      debugPrint('❌ Erro ao buscar venda aberta da comanda: $e');
      return ApiResponse<VendaDto?>.error(
        message: 'Erro ao buscar venda: ${e.toString()}',
      );
    }
  }

  /// Conclui uma venda (emite nota fiscal final)
  /// 
  /// POST /api/vendas/{vendaId}/concluir
  Future<ApiResponse<VendaDto>> concluirVenda(String vendaId) async {
    try {
      debugPrint('📤 Concluindo venda: Venda=$vendaId');
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/vendas/$vendaId/concluir',
        data: {},
      );
      
      if (response.data == null) {
        return ApiResponse<VendaDto>.error(
          message: 'Erro ao concluir venda',
        );
      }
      
      final data = response.data!;
      final vendaData = data['data'] as Map<String, dynamic>?;
      
      if (vendaData == null) {
        return ApiResponse<VendaDto>.error(
          message: data['message'] as String? ?? 'Erro ao concluir venda',
        );
      }
      
      final venda = VendaDto.fromJson(vendaData);
      debugPrint('✅ Venda concluída com sucesso: ${venda.id}');
      
      return ApiResponse<VendaDto>.success(
        data: venda,
        message: data['message'] as String? ?? 'Venda concluída com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao concluir venda: $e');
      return ApiResponse<VendaDto>.error(
        message: 'Erro ao concluir venda: ${e.toString()}',
      );
    }
  }

  /// Obtém resumo das vendas abertas por mesa (apenas informações essenciais para seleção de agrupamento)
  /// 
  /// GET /api/vendas/mesa/{mesaId}/resumo
  Future<ApiResponse<List<VendaResumoDto>>> getVendasResumoPorMesa(String mesaId) async {
    try {
      debugPrint('🔍 Buscando resumo de vendas abertas da mesa: $mesaId');
      
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/vendas/mesa/$mesaId/resumo',
      );
      
      if (response.data == null) {
        return ApiResponse<List<VendaResumoDto>>.error(
          message: 'Erro ao buscar resumo de vendas',
        );
      }
      
      final data = response.data!;
      final vendasData = data['data'] as List<dynamic>?;
      
      if (vendasData == null) {
        return ApiResponse<List<VendaResumoDto>>.error(
          message: data['message'] as String? ?? 'Erro ao buscar resumo de vendas',
        );
      }
      
      final vendas = vendasData
          .map((v) => VendaResumoDto.fromJson(v as Map<String, dynamic>))
          .toList();
      
      debugPrint('✅ Resumo de vendas encontrado: ${vendas.length} vendas');
      
      return ApiResponse<List<VendaResumoDto>>.success(
        data: vendas,
        message: data['message'] as String? ?? 'Resumo de vendas encontrado',
      );
    } catch (e) {
      debugPrint('❌ Erro ao buscar resumo de vendas: $e');
      return ApiResponse<List<VendaResumoDto>>.error(
        message: 'Erro ao buscar resumo de vendas: ${e.toString()}',
      );
    }
  }

  /// Agrupa múltiplas vendas em uma única venda destino, transferindo pedidos e pagamentos
  /// 
  /// POST /api/vendas/agrupar
  Future<ApiResponse<VendaDto>> agruparVendas({
    required String vendaDestinoId,
    required List<String> vendaOrigemIds,
  }) async {
    try {
      debugPrint('📤 Agrupando vendas. Destino: $vendaDestinoId, Origens: ${vendaOrigemIds.join(", ")}');
      
      final payload = {
        'vendaDestinoId': vendaDestinoId,
        'vendaOrigemIds': vendaOrigemIds,
      };
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/vendas/agrupar',
        data: payload,
      );
      
      if (response.data == null) {
        return ApiResponse<VendaDto>.error(
          message: 'Erro ao agrupar vendas',
        );
      }
      
      final data = response.data!;
      final vendaData = data['data'] as Map<String, dynamic>?;
      
      if (vendaData == null) {
        return ApiResponse<VendaDto>.error(
          message: data['message'] as String? ?? 'Erro ao agrupar vendas',
        );
      }
      
      final venda = VendaDto.fromJson(vendaData);
      debugPrint('✅ Vendas agrupadas com sucesso. Venda destino: ${venda.id}');
      
      return ApiResponse<VendaDto>.success(
        data: venda,
        message: data['message'] as String? ?? 'Vendas agrupadas com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao agrupar vendas: $e');
      return ApiResponse<VendaDto>.error(
        message: 'Erro ao agrupar vendas: ${e.toString()}',
      );
    }
  }

  /// Transfere todas as vendas abertas de uma mesa para outra
  /// 
  /// Lógica de transferência:
  /// - Vendas COM comanda: apenas atualiza MesaId (cada comanda tem sua própria venda)
  /// - Venda SEM comanda:
  ///   * Se mesa destino está livre: apenas atualiza MesaId
  ///   * Se mesa destino já tem venda sem comanda: MESCLA pedidos e pagamentos (agrupa)
  /// 
  /// A mesa origem será liberada (VendaAtual removida) e a mesa destino receberá as vendas.
  /// 
  /// POST /api/vendas/transferir-mesa
  Future<ApiResponse<void>> transferirVendasDeMesa({
    required String mesaOrigemId,
    required String mesaDestinoId,
  }) async {
    try {
      debugPrint('📤 Transferindo vendas da mesa $mesaOrigemId para mesa $mesaDestinoId');
      
      final payload = {
        'mesaOrigemId': mesaOrigemId,
        'mesaDestinoId': mesaDestinoId,
      };
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/vendas/transferir-mesa',
        data: payload,
      );
      
      if (response.data == null) {
        return ApiResponse<void>.error(
          message: 'Erro ao transferir vendas de mesa',
        );
      }
      
      final data = response.data!;
      
      // Verificar se houve erro na resposta
      if (data['success'] == false) {
        return ApiResponse<void>.error(
          message: data['message'] as String? ?? 'Erro ao transferir vendas de mesa',
        );
      }
      
      debugPrint('✅ Vendas transferidas com sucesso da mesa $mesaOrigemId para mesa $mesaDestinoId');
      
      return ApiResponse<void>.success(
        data: null,
        message: data['message'] as String? ?? 'Vendas transferidas com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao transferir vendas de mesa: $e');
      return ApiResponse<void>.error(
        message: 'Erro ao transferir vendas de mesa: ${e.toString()}',
      );
    }
  }

  /// Transfere a venda de uma comanda para outra comanda
  /// 
  /// Lógica de transferência:
  /// - Se comanda destino está livre: apenas atualiza ComandaId da venda origem
  /// - Se comanda destino já tem venda aberta: MESCLA pedidos e pagamentos (agrupa)
  /// 
  /// A comanda origem será liberada (VendaAtual removida) e a comanda destino receberá a venda.
  /// 
  /// POST /api/vendas/transferir-comanda
  Future<ApiResponse<void>> transferirVendaDeComanda({
    required String comandaOrigemId,
    required String comandaDestinoId,
  }) async {
    try {
      debugPrint('📤 Transferindo venda da comanda $comandaOrigemId para comanda $comandaDestinoId');
      
      final payload = {
        'comandaOrigemId': comandaOrigemId,
        'comandaDestinoId': comandaDestinoId,
      };
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/vendas/transferir-comanda',
        data: payload,
      );
      
      if (response.data == null) {
        return ApiResponse<void>.error(
          message: 'Erro ao transferir venda de comanda',
        );
      }
      
      final data = response.data!;
      
      // Verificar se houve erro na resposta
      if (data['success'] == false) {
        return ApiResponse<void>.error(
          message: data['message'] as String? ?? 'Erro ao transferir venda de comanda',
        );
      }
      
      debugPrint('✅ Venda transferida com sucesso da comanda $comandaOrigemId para comanda $comandaDestinoId');
      
      return ApiResponse<void>.success(
        data: null,
        message: data['message'] as String? ?? 'Venda transferida com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao transferir venda de comanda: $e');
      return ApiResponse<void>.error(
        message: 'Erro ao transferir venda de comanda: ${e.toString()}',
      );
    }
  }
}

