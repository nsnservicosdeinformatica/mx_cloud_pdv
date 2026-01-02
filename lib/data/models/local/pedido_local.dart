import 'package:hive/hive.dart';
import 'sync_status_pedido.dart';
import 'item_pedido_local.dart';

part 'pedido_local.g.dart';

/// Modelo local para pedido em construção
@HiveType(typeId: 7)
class PedidoLocal {
  @HiveField(0)
  String id; // ID único do pedido local

  @HiveField(1)
  String? mesaId;

  @HiveField(2)
  String? comandaId;

  @HiveField(3)
  List<ItemPedidoLocal> itens;

  @HiveField(4)
  String? observacoesGeral; // Observações gerais do pedido

  @HiveField(5)
  DateTime dataCriacao;

  @HiveField(6)
  DateTime? dataAtualizacao;

  /// Status de sincronização local
  @HiveField(7)
  SyncStatusPedido syncStatus;

  /// Número de tentativas de sync
  @HiveField(8)
  int syncAttempts;

  /// Último erro de sync (se houver)
  @HiveField(9)
  String? lastSyncError;

  /// Data/hora da última sincronização bem-sucedida
  @HiveField(10)
  DateTime? syncedAt;

  /// Id remota (após sincronizar)
  @HiveField(11)
  String? remoteId;

  PedidoLocal({
    required this.id,
    this.mesaId,
    this.comandaId,
    List<ItemPedidoLocal>? itens,
    this.observacoesGeral,
    DateTime? dataCriacao,
    this.dataAtualizacao,
    this.syncStatus = SyncStatusPedido.pendente,
    this.syncAttempts = 0,
    this.lastSyncError,
    this.syncedAt,
    this.remoteId,
  }) : itens = itens ?? [],
       dataCriacao = dataCriacao ?? DateTime.now();

  /// Calcula o total do pedido
  double get total {
    return itens.fold(0.0, (sum, item) => sum + item.precoTotal);
  }

  /// Retorna a quantidade total de itens
  int get quantidadeTotal {
    return itens.fold(0, (sum, item) => sum + item.quantidade);
  }

  /// Adiciona um item ao pedido
  void adicionarItem(ItemPedidoLocal item) {
    itens.add(item);
    dataAtualizacao = DateTime.now();
  }

  /// Remove um item do pedido
  void removerItem(String itemId) {
    itens.removeWhere((item) => item.id == itemId);
    dataAtualizacao = DateTime.now();
  }

  /// Atualiza a quantidade de um item
  void atualizarQuantidadeItem(String itemId, int novaQuantidade) {
    final item = itens.firstWhere(
      (item) => item.id == itemId,
      orElse: () => throw Exception('Item não encontrado'),
    );
    item.quantidade = novaQuantidade;
    dataAtualizacao = DateTime.now();
  }

  /// Limpa todos os itens do pedido
  void limparItens() {
    itens.clear();
    dataAtualizacao = DateTime.now();
  }

  /// Converte PedidoLocal para CreatePedidoDto (Map) para envio à API
  /// Usado para vendas balcão que são enviadas diretamente para API
  Map<String, dynamic> toCreateDto() {
    // ✅ Determina tipoContexto baseado em mesaId/comandaId
    int tipoContexto;
    if (mesaId != null) {
      tipoContexto = 2; // TipoContextoPedido.Mesa
    } else if (comandaId != null) {
      tipoContexto = 3; // TipoContextoPedido.Comanda
    } else {
      tipoContexto = 1; // TipoContextoPedido.Direto (venda balcão)
    }
    
    final dto = {
      'tipo': 2, // TipoPedido.Venda
      'tipoContexto': tipoContexto,
      'mesaId': mesaId,
      'comandaId': comandaId,
      'clienteNome': 'Consumidor Final',
      'observacoes': observacoesGeral,
      'itens': itens.map((item) {
        final itemMap = <String, dynamic>{
          'produtoId': item.produtoId,
          'produtoVariacaoId': item.produtoVariacaoId,
          'quantidade': item.quantidade,
          'precoUnitario': item.precoUnitario,
          'observacoes': item.observacoes,
        };

        // Adicionar componentes removidos se houver
        if (item.componentesRemovidos.isNotEmpty) {
          itemMap['componentesRemovidos'] = item.componentesRemovidos.map((componenteId) {
            return {
              'componenteId': componenteId,
              'componenteNome': '', // Backend buscará se necessário
            };
          }).toList();
        }

        return itemMap;
      }).toList(),
    };

    return dto;
  }
}

