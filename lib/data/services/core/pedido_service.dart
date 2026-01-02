import 'package:flutter/foundation.dart';
import '../../models/core/pedido_list_item.dart';
import '../../models/core/pedido_com_itens_pdv_dto.dart';
import '../../models/core/pedidos_com_venda_comandas_dto.dart';
import '../../models/core/pedido_operacoes_dto.dart';
import '../../../core/network/api_client.dart';
import '../../models/core/api_response.dart';
import '../../../core/network/endpoints.dart';

/// Serviço para gerenciamento de pedidos
class PedidoService {
  final ApiClient apiClient;

  PedidoService({required this.apiClient});

  /// Busca pedidos por mesa
  Future<ApiResponse<List<PedidoListItemDto>>> getPedidosPorMesa(String mesaId) async {
    try {
      debugPrint('🔍 Buscando pedidos da mesa: $mesaId');
      final response = await apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.pedidosPorMesa(mesaId),
      );

      if (response.data == null) {
        debugPrint('⚠️ Resposta vazia ao buscar pedidos da mesa');
        return ApiResponse<List<PedidoListItemDto>>.success(
          data: [],
          message: 'Nenhum pedido encontrado',
        );
      }

      final data = response.data!;
      debugPrint('📥 Resposta recebida: success=${data['success']}, data type=${data['data']?.runtimeType}');
      final listData = data['data'];
      
      // Se listData for null ou não for uma lista, retorna lista vazia
      if (listData == null) {
        return ApiResponse<List<PedidoListItemDto>>.success(
          data: [],
          message: data['message'] as String? ?? 'Nenhum pedido encontrado',
        );
      }

      // Se for uma lista vazia, retorna lista vazia
      if (listData is! List) {
        return ApiResponse<List<PedidoListItemDto>>.success(
          data: [],
          message: data['message'] as String? ?? 'Nenhum pedido encontrado',
        );
      }

      // Se a lista estiver vazia, retorna lista vazia (não null)
      if ((listData as List).isEmpty) {
        return ApiResponse<List<PedidoListItemDto>>.success(
          data: [],
          message: data['message'] as String? ?? 'Nenhum pedido encontrado',
        );
      }

      // Converte os itens da lista para PedidoListItemDto
      final pedidos = (listData as List)
          .map((item) {
            try {
              final pedido = PedidoListItemDto.fromJson(item as Map<String, dynamic>);
              debugPrint('✅ Pedido parseado: ${pedido.numero} - MesaId: ${pedido.mesaId}, ComandaId: ${pedido.comandaId}');
              return pedido;
            } catch (e, stackTrace) {
              // Log do erro mas continua processando outros itens
              debugPrint('❌ Erro ao deserializar pedido: $e');
              debugPrint('Stack trace: $stackTrace');
              debugPrint('Item JSON: $item');
              return null;
            }
          })
          .where((pedido) => pedido != null)
          .cast<PedidoListItemDto>()
          .toList();
      
      debugPrint('📦 Total de pedidos parseados: ${pedidos.length}');

      return ApiResponse<List<PedidoListItemDto>>.success(
        data: pedidos,
        message: data['message'] as String? ?? 'Pedidos encontrados',
      );
    } catch (e) {
      return ApiResponse<List<PedidoListItemDto>>.error(
        message: 'Erro ao buscar pedidos: ${e.toString()}',
      );
    }
  }

  /// Busca pedidos por mesa com itens simplificados para PDV (retorna também venda e comandas)
  Future<ApiResponse<PedidosComVendaComandasDto>> getPedidosPorMesaCompleto(String mesaId) async {
    try {
      debugPrint('🔍 Buscando pedidos da mesa: $mesaId');
      final response = await apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.pedidosPorMesa(mesaId),
      );

      if (response.data == null) {
        debugPrint('⚠️ Resposta vazia ao buscar pedidos da mesa');
        return ApiResponse<PedidosComVendaComandasDto>.success(
          data: PedidosComVendaComandasDto(pedidos: []),
          message: 'Nenhum pedido encontrado',
        );
      }

      final data = response.data!;
      debugPrint('📥 Resposta recebida: success=${data['success']}, data type=${data['data']?.runtimeType}');
      
      // Nova estrutura: data['data'] é um objeto com 'pedidos', 'venda' e 'comandas'
      final responseData = data['data'];
      
      // Se responseData for null, retorna objeto vazio
      if (responseData == null) {
        return ApiResponse<PedidosComVendaComandasDto>.success(
          data: PedidosComVendaComandasDto(pedidos: []),
          message: data['message'] as String? ?? 'Nenhum pedido encontrado',
        );
      }

      // Processa o objeto completo
      PedidosComVendaComandasDto resultado;
      if (responseData is Map<String, dynamic>) {
        // Nova estrutura: { pedidos: [...], venda: {...}, comandas: [...] }
        resultado = PedidosComVendaComandasDto.fromJson(responseData);
      } else if (responseData is List) {
        // Estrutura antiga (compatibilidade): apenas lista de pedidos
        final pedidos = (responseData as List)
            .map((item) {
              try {
                return PedidoComItensPdvDto.fromJson(item as Map<String, dynamic>);
              } catch (e, stackTrace) {
                debugPrint('❌ Erro ao deserializar pedido: $e');
                debugPrint('Stack trace: $stackTrace');
                debugPrint('Item JSON: $item');
                return null;
              }
            })
            .where((pedido) => pedido != null)
            .cast<PedidoComItensPdvDto>()
            .toList();
        resultado = PedidosComVendaComandasDto(pedidos: pedidos);
      } else {
        return ApiResponse<PedidosComVendaComandasDto>.success(
          data: PedidosComVendaComandasDto(pedidos: []),
          message: data['message'] as String? ?? 'Nenhum pedido encontrado',
        );
      }

      debugPrint('📦 Total de pedidos encontrados: ${resultado.pedidos.length}');
      debugPrint('📋 Total de comandas encontradas: ${resultado.comandas?.length ?? 0}');
      for (var pedido in resultado.pedidos) {
        debugPrint('  - Pedido ${pedido.numero}: ${pedido.itens.length} itens');
      }

      return ApiResponse<PedidosComVendaComandasDto>.success(
        data: resultado,
        message: data['message'] as String? ?? 'Pedidos encontrados',
      );
    } catch (e) {
      debugPrint('❌ Erro ao buscar pedidos da mesa: $e');
      return ApiResponse<PedidosComVendaComandasDto>.error(
        message: 'Erro ao buscar pedidos: ${e.toString()}',
      );
    }
  }

  /// Busca um pedido completo por ID (inclui itens)
  Future<ApiResponse<Map<String, dynamic>>> getPedidoById(String pedidoId) async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.pedidoById(pedidoId),
      );

      if (response.data == null) {
        return ApiResponse<Map<String, dynamic>>.error(
          message: 'Pedido não encontrado',
        );
      }

      final data = response.data!;
      
      // Verifica se houve erro na resposta
      if (data['success'] == false) {
        final mensagem = data['message'] as String? ?? 'Erro ao buscar pedido';
        return ApiResponse<Map<String, dynamic>>.error(
          message: mensagem,
        );
      }

      final pedidoData = data['data'] as Map<String, dynamic>?;
      
      if (pedidoData == null) {
        return ApiResponse<Map<String, dynamic>>.error(
          message: data['message'] as String? ?? 'Erro ao buscar pedido',
        );
      }

      return ApiResponse<Map<String, dynamic>>.success(
        data: pedidoData,
        message: data['message'] as String? ?? 'Pedido encontrado',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.error(
        message: 'Erro ao buscar pedido: ${e.toString()}',
      );
    }
  }

  /// Busca pedidos por comanda com itens simplificados para PDV (retorna também venda)
  Future<ApiResponse<PedidosComVendaComandasDto>> getPedidosPorComandaCompleto(String comandaId) async {
    try {
      debugPrint('🔍 Buscando pedidos da comanda: $comandaId');
      // Usa o endpoint específico para comanda (igual ao de mesa)
      final response = await apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.pedidosPorComanda(comandaId),
      );

      if (response.data == null) {
        debugPrint('⚠️ Resposta vazia ao buscar pedidos da comanda');
        return ApiResponse<PedidosComVendaComandasDto>.success(
          data: PedidosComVendaComandasDto(pedidos: []),
          message: 'Nenhum pedido encontrado',
        );
      }

      final data = response.data!;
      debugPrint('📥 Resposta recebida: success=${data['success']}, data type=${data['data']?.runtimeType}');
      
      // Nova estrutura: data['data'] é um objeto com 'pedidos' e 'venda'
      final responseData = data['data'];
      
      // Se responseData for null, retorna objeto vazio
      if (responseData == null) {
        return ApiResponse<PedidosComVendaComandasDto>.success(
          data: PedidosComVendaComandasDto(pedidos: []),
          message: data['message'] as String? ?? 'Nenhum pedido encontrado',
        );
      }

      // Processa o objeto completo (igual ao método de mesa)
      PedidosComVendaComandasDto resultado;
      if (responseData is Map<String, dynamic>) {
        // Nova estrutura: { pedidos: [...], venda: {...} }
        resultado = PedidosComVendaComandasDto.fromJson(responseData);
      } else if (responseData is List) {
        // Estrutura antiga (compatibilidade): apenas lista de pedidos
        final pedidos = (responseData as List)
            .map((item) {
              try {
                return PedidoComItensPdvDto.fromJson(item as Map<String, dynamic>);
              } catch (e, stackTrace) {
                debugPrint('❌ Erro ao deserializar pedido: $e');
                debugPrint('Stack trace: $stackTrace');
                debugPrint('Item JSON: $item');
                return null;
              }
            })
            .where((pedido) => pedido != null)
            .cast<PedidoComItensPdvDto>()
            .toList();
        resultado = PedidosComVendaComandasDto(pedidos: pedidos);
      } else {
        return ApiResponse<PedidosComVendaComandasDto>.success(
          data: PedidosComVendaComandasDto(pedidos: []),
          message: data['message'] as String? ?? 'Nenhum pedido encontrado',
        );
      }

      debugPrint('📦 Total de pedidos encontrados: ${resultado.pedidos.length}');
      if (resultado.venda != null) {
        debugPrint('✅ Venda encontrada: ${resultado.venda!.id}');
      } else {
        debugPrint('ℹ️ Nenhuma venda encontrada na resposta');
      }
      for (var pedido in resultado.pedidos) {
        debugPrint('  - Pedido ${pedido.numero}: ${pedido.itens.length} itens');
      }

      return ApiResponse<PedidosComVendaComandasDto>.success(
        data: resultado,
        message: data['message'] as String? ?? 'Pedidos encontrados',
      );
    } catch (e) {
      debugPrint('❌ Erro ao buscar pedidos da comanda: $e');
      return ApiResponse<PedidosComVendaComandasDto>.error(
        message: 'Erro ao buscar pedidos: ${e.toString()}',
      );
    }
  }

  /// Busca pedidos por comanda
  Future<ApiResponse<List<PedidoListItemDto>>> getPedidosPorComanda(String comandaId) async {
    try {
      debugPrint('🔍 Buscando pedidos da comanda: $comandaId');
      // Usa o endpoint de busca com filtro por comanda
      final response = await apiClient.post<Map<String, dynamic>>(
        '${ApiEndpoints.pedidos}/search',
        data: {
          'pagination': {
            'page': 1,
            'pageSize': 1000,
          },
          'filter': {
            'comandaId': comandaId,
          },
        },
      );

      if (response.data == null) {
        debugPrint('⚠️ Resposta vazia ao buscar pedidos da comanda');
        return ApiResponse<List<PedidoListItemDto>>.success(
          data: [],
          message: 'Nenhum pedido encontrado',
        );
      }

      final data = response.data!;
      debugPrint('📥 Resposta recebida: success=${data['success']}, data type=${data['data']?.runtimeType}');
      
      // O endpoint /search retorna estrutura paginada: { data: { list: [...], pagination: {...} } }
      final paginatedData = data['data'] as Map<String, dynamic>?;
      final list = paginatedData?['list'] as List<dynamic>? ?? [];
      
      debugPrint('📦 Total de pedidos na resposta: ${list.length}');
      
      final pedidos = list
          .map((item) {
            try {
              final pedido = PedidoListItemDto.fromJson(item as Map<String, dynamic>);
              debugPrint('✅ Pedido parseado: ${pedido.numero} - MesaId: ${pedido.mesaId}, ComandaId: ${pedido.comandaId}');
              return pedido;
            } catch (e, stackTrace) {
              debugPrint('❌ Erro ao deserializar pedido: $e');
              debugPrint('Stack trace: $stackTrace');
              debugPrint('Item JSON: $item');
              return null;
            }
          })
          .where((pedido) => pedido != null)
          .cast<PedidoListItemDto>()
          .toList();
      
      debugPrint('📦 Total de pedidos parseados com sucesso: ${pedidos.length}');

      return ApiResponse<List<PedidoListItemDto>>.success(
        data: pedidos,
        message: data['message'] as String? ?? 'Pedidos encontrados',
      );
    } catch (e) {
      debugPrint('❌ Erro ao buscar pedidos da comanda: $e');
      return ApiResponse<List<PedidoListItemDto>>.error(
        message: 'Erro ao buscar pedidos: ${e.toString()}',
      );
    }
  }

  /// Cria um novo pedido no servidor
  Future<ApiResponse<Map<String, dynamic>>> createPedido(Map<String, dynamic> pedidoDto) async {
    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.pedidos,
        data: pedidoDto,
      );

      if (response.data == null) {
        return ApiResponse<Map<String, dynamic>>.error(
          message: 'Resposta vazia do servidor',
        );
      }

      final data = response.data!;
      
      // Verifica se houve erro na resposta
      if (data['success'] == false) {
        final mensagem = data['message'] as String? ?? 'Erro ao criar pedido';
        return ApiResponse<Map<String, dynamic>>.error(
          message: mensagem,
        );
      }

      final pedidoData = data['data'] as Map<String, dynamic>?;
      
      if (pedidoData == null) {
        return ApiResponse<Map<String, dynamic>>.error(
          message: data['message'] as String? ?? 'Erro ao criar pedido',
        );
      }

      return ApiResponse<Map<String, dynamic>>.success(
        data: pedidoData,
        message: data['message'] as String? ?? 'Pedido criado com sucesso',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.error(
        message: 'Erro ao criar pedido: ${e.toString()}',
      );
    }
  }

  /// Atualiza um item de pedido
  Future<ApiResponse<Map<String, dynamic>>> atualizarItem(
    String pedidoId,
    String itemId,
    UpdateItemPedidoDto dto,
  ) async {
    try {
      debugPrint('✏️ Atualizando item $itemId do pedido $pedidoId');
      final response = await apiClient.put<Map<String, dynamic>>(
        ApiEndpoints.pedidoItem(pedidoId, itemId),
        data: dto.toJson(),
      );

      if (response.data == null) {
        return ApiResponse<Map<String, dynamic>>.error(
          message: 'Resposta vazia do servidor',
        );
      }

      final data = response.data!;

      // Verifica se houve erro na resposta
      if (data['success'] == false) {
        final mensagem = data['message'] as String? ?? 'Erro ao atualizar item';
        return ApiResponse<Map<String, dynamic>>.error(
          message: mensagem,
        );
      }

      final pedidoData = data['data'] as Map<String, dynamic>?;

      if (pedidoData == null) {
        return ApiResponse<Map<String, dynamic>>.error(
          message: data['message'] as String? ?? 'Erro ao atualizar item',
        );
      }

      debugPrint('✅ Item atualizado com sucesso');
      return ApiResponse<Map<String, dynamic>>.success(
        data: pedidoData,
        message: data['message'] as String? ?? 'Item atualizado com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao atualizar item: $e');
      return ApiResponse<Map<String, dynamic>>.error(
        message: 'Erro ao atualizar item: ${e.toString()}',
      );
    }
  }

  /// Cancela um item de pedido
  Future<ApiResponse<Map<String, dynamic>>> cancelarItem(
    String pedidoId,
    String itemId,
    CancelarItemPedidoDto dto,
  ) async {
    try {
      debugPrint('🚫 Cancelando item $itemId do pedido $pedidoId');
      final response = await apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.cancelarItem(pedidoId, itemId),
        data: dto.toJson(),
      );

      if (response.data == null) {
        return ApiResponse<Map<String, dynamic>>.error(
          message: 'Resposta vazia do servidor',
        );
      }

      final data = response.data!;

      // Verifica se houve erro na resposta
      if (data['success'] == false) {
        final mensagem = data['message'] as String? ?? 'Erro ao cancelar item';
        return ApiResponse<Map<String, dynamic>>.error(
          message: mensagem,
        );
      }

      final pedidoData = data['data'] as Map<String, dynamic>?;

      if (pedidoData == null) {
        return ApiResponse<Map<String, dynamic>>.error(
          message: data['message'] as String? ?? 'Erro ao cancelar item',
        );
      }

      debugPrint('✅ Item cancelado com sucesso');
      return ApiResponse<Map<String, dynamic>>.success(
        data: pedidoData,
        message: data['message'] as String? ?? 'Item cancelado com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao cancelar item: $e');
      return ApiResponse<Map<String, dynamic>>.error(
        message: 'Erro ao cancelar item: ${e.toString()}',
      );
    }
  }

  /// Deleta um pedido (soft delete)
  Future<ApiResponse<void>> deletarPedido(String pedidoId) async {
    try {
      debugPrint('🗑️ Deletando pedido $pedidoId');
      final response = await apiClient.delete<Map<String, dynamic>>(
        ApiEndpoints.pedidoById(pedidoId),
      );

      if (response.data == null) {
        return ApiResponse<void>.error(
          message: 'Resposta vazia do servidor',
        );
      }

      final data = response.data!;

      // Verifica se houve erro na resposta
      if (data['success'] == false) {
        final mensagem = data['message'] as String? ?? 'Erro ao deletar pedido';
        return ApiResponse<void>.error(
          message: mensagem,
        );
      }

      debugPrint('✅ Pedido deletado com sucesso');
      return ApiResponse<void>.success(
        data: null,
        message: data['message'] as String? ?? 'Pedido removido com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao deletar pedido: $e');
      return ApiResponse<void>.error(
        message: 'Erro ao deletar pedido: ${e.toString()}',
      );
    }
  }

  /// Cancela um pedido
  Future<ApiResponse<Map<String, dynamic>>> cancelarPedido(
    String pedidoId,
    CancelarPedidoDto dto,
  ) async {
    try {
      debugPrint('🚫 Cancelando pedido $pedidoId');
      final response = await apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.cancelarPedido(pedidoId),
        data: dto.toJson(),
      );

      if (response.data == null) {
        return ApiResponse<Map<String, dynamic>>.error(
          message: 'Resposta vazia do servidor',
        );
      }

      final data = response.data!;

      // Verifica se houve erro na resposta
      if (data['success'] == false) {
        final mensagem = data['message'] as String? ?? 'Erro ao cancelar pedido';
        return ApiResponse<Map<String, dynamic>>.error(
          message: mensagem,
        );
      }

      final pedidoData = data['data'] as Map<String, dynamic>?;

      if (pedidoData == null) {
        return ApiResponse<Map<String, dynamic>>.error(
          message: data['message'] as String? ?? 'Erro ao cancelar pedido',
        );
      }

      debugPrint('✅ Pedido cancelado com sucesso');
      return ApiResponse<Map<String, dynamic>>.success(
        data: pedidoData,
        message: data['message'] as String? ?? 'Pedido cancelado com sucesso',
      );
    } catch (e) {
      debugPrint('❌ Erro ao cancelar pedido: $e');
      return ApiResponse<Map<String, dynamic>>.error(
        message: 'Erro ao cancelar pedido: ${e.toString()}',
      );
    }
  }
}
