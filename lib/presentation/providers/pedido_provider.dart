import 'package:flutter/foundation.dart';
import '../../data/models/local/pedido_local.dart';
import '../../data/models/local/item_pedido_local.dart';
import '../../data/models/local/sync_status_pedido.dart';
import '../../data/repositories/pedido_local_repository.dart';
import '../../screens/pedidos/restaurante/modals/selecionar_produto_modal.dart';
import '../../data/services/core/pedido_service.dart';
import 'package:uuid/uuid.dart';

/// Resultado da finalização do pedido
class FinalizarPedidoResult {
  final bool sucesso;
  final String? pedidoId;
  final String? pedidoRemoteId;
  final String? vendaId;
  final String? erro;
  final bool foiEnviadoDireto;

  FinalizarPedidoResult({
    required this.sucesso,
    this.pedidoId,
    this.pedidoRemoteId,
    this.vendaId,
    this.erro,
    this.foiEnviadoDireto = false,
  });
}

/// Provider para gerenciar o pedido em construção
/// Responsável apenas pelo gerenciamento de estado do pedido local
class PedidoProvider extends ChangeNotifier {
  PedidoLocal? _pedidoAtual;
  final _pedidoRepo = PedidoLocalRepository();
  PedidoService? _pedidoService; // ✅ Para enviar direto ao servidor

  PedidoLocal? get pedidoAtual => _pedidoAtual;

  /// Total do pedido
  double get total => _pedidoAtual?.total ?? 0.0;

  /// Quantidade total de itens
  int get quantidadeTotal => _pedidoAtual?.quantidadeTotal ?? 0;

  /// Lista de itens do pedido
  List<ItemPedidoLocal> get itens => _pedidoAtual?.itens ?? [];

  /// Verifica se o pedido está vazio
  bool get isEmpty => _pedidoAtual == null || _pedidoAtual!.itens.isEmpty;

  PedidoProvider() {
    _inicializarPedido();
  }

  /// Define o PedidoService para permitir envio direto ao servidor
  void setPedidoService(PedidoService pedidoService) {
    _pedidoService = pedidoService;
  }

  /// Inicializa um novo pedido
  void _inicializarPedido({
    String? mesaId,
    String? comandaId,
  }) {
    _pedidoAtual = PedidoLocal(
      id: const Uuid().v4(), // Gera um novo ID para cada pedido
      mesaId: mesaId,
      comandaId: comandaId,
    );
    notifyListeners();
  }

  /// Inicia um novo pedido
  /// A venda será criada automaticamente no backend quando o primeiro pedido for enviado
  Future<bool> iniciarNovoPedido({
    String? mesaId,
    String? comandaId,
  }) async {
    debugPrint('📝 [PedidoProvider] iniciarNovoPedido chamado:');
    debugPrint('  - MesaId: $mesaId');
    debugPrint('  - ComandaId: $comandaId');
    
    _inicializarPedido(
      mesaId: mesaId,
      comandaId: comandaId,
    );
    
    debugPrint('📝 [PedidoProvider] Pedido inicializado:');
    debugPrint('  - MesaId no pedido: ${_pedidoAtual?.mesaId}');
    debugPrint('  - ComandaId no pedido: ${_pedidoAtual?.comandaId}');
    
    return true;
  }

  /// Adiciona itens ao pedido a partir do resultado da seleção de produto
  void adicionarItens(ProdutoSelecionadoResult resultado) {
    if (_pedidoAtual == null) {
      _inicializarPedido();
    }

    for (var itemSelecionado in resultado.itens) {
      final itemPedido = ItemPedidoLocal(
        id: const Uuid().v4(),
        produtoId: itemSelecionado.produtoId,
        produtoNome: itemSelecionado.produtoNome,
        produtoVariacaoId: itemSelecionado.produtoVariacaoId,
        produtoVariacaoNome: itemSelecionado.produtoVariacaoNome,
        precoUnitario: itemSelecionado.precoUnitario,
        quantidade: 1,
        observacoes: itemSelecionado.observacoes,
        proporcoesAtributos: itemSelecionado.proporcoesAtributos,
        valoresAtributosSelecionados: itemSelecionado.valoresAtributosSelecionados,
        componentesRemovidos: itemSelecionado.componentesRemovidos,
      );

      _pedidoAtual!.adicionarItem(itemPedido);
    }

    notifyListeners();
  }

  /// Remove um item do pedido
  void removerItem(String itemId) {
    if (_pedidoAtual == null) return;
    _pedidoAtual!.removerItem(itemId);
    notifyListeners();
  }

  /// Atualiza a quantidade de um item
  void atualizarQuantidadeItem(String itemId, int novaQuantidade) {
    if (_pedidoAtual == null) return;
    if (novaQuantidade <= 0) {
      removerItem(itemId);
      return;
    }
    _pedidoAtual!.atualizarQuantidadeItem(itemId, novaQuantidade);
    notifyListeners();
  }

  /// Atualiza um item existente (componentes removidos e observações)
  void atualizarItem(ItemPedidoLocal itemAtualizado) {
    if (_pedidoAtual == null) return;
    
    final index = _pedidoAtual!.itens.indexWhere((item) => item.id == itemAtualizado.id);
    if (index == -1) return;
    
    _pedidoAtual!.itens[index] = itemAtualizado;
    _pedidoAtual!.dataAtualizacao = DateTime.now();
    notifyListeners();
  }

  /// Limpa todos os itens do pedido
  void limparPedido() {
    if (_pedidoAtual == null) return;
    _pedidoAtual!.limparItens();
    notifyListeners();
  }

  /// Define observações gerais do pedido
  void setObservacoesGeral(String? observacoes) {
    if (_pedidoAtual == null) {
      _inicializarPedido();
    }
    _pedidoAtual!.observacoesGeral = observacoes;
    _pedidoAtual!.dataAtualizacao = DateTime.now();
    notifyListeners();
  }

  /// Finaliza o pedido atual
  /// Tenta enviar direto ao servidor primeiro
  /// Se falhar e permitirHive=true, salva no Hive para sincronização posterior
  /// Se falhar e permitirHive=false, retorna erro (usado para balcão)
  /// 
  /// [permitirHive] Se true, salva no Hive em caso de falha. Se false, retorna erro.
  Future<FinalizarPedidoResult> finalizarPedido({bool permitirHive = true}) async {
    if (_pedidoAtual == null || _pedidoAtual!.itens.isEmpty) {
      return FinalizarPedidoResult(
        sucesso: false,
        erro: 'Pedido vazio',
      );
    }

    try {
      // Preserva mesaId e comandaId antes de limpar
      final mesaId = _pedidoAtual!.mesaId;
      final comandaId = _pedidoAtual!.comandaId;

      debugPrint('💾 [PedidoProvider] Finalizando pedido:');
      debugPrint('  - PedidoId: ${_pedidoAtual!.id}');
      debugPrint('  - MesaId: $mesaId');
      debugPrint('  - ComandaId: $comandaId');
      debugPrint('  - PermitirHive: $permitirHive');

      // ✅ Tenta enviar direto ao servidor primeiro (comportamento comum)
      if (_pedidoService != null) {
        try {
          debugPrint('📤 [PedidoProvider] Tentando enviar pedido direto ao servidor...');
          
          // Converte para DTO
          final pedidoDto = _pedidoAtual!.toCreateDto();
          
          // Envia para servidor
          final response = await _pedidoService!.createPedido(pedidoDto);
          
          if (response.success && response.data != null) {
            debugPrint('✅ [PedidoProvider] Pedido enviado com sucesso ao servidor!');
            
            final pedidoData = response.data!;
            final pedidoRemoteId = pedidoData['id'] as String?;
            final vendaId = pedidoData['vendaId'] as String?;
            
            // Atualiza com ID remoto se retornado
            if (pedidoRemoteId != null) {
              _pedidoAtual!.remoteId = pedidoRemoteId;
              _pedidoAtual!.syncStatus = SyncStatusPedido.sincronizado;
              _pedidoAtual!.syncedAt = DateTime.now();
            }
            
            // Armazena ID do pedido antes de limpar
            final pedidoIdSalvo = _pedidoAtual!.id;
            
            // Limpa o pedido atual para permitir criar um novo, preservando mesa/comanda
            _inicializarPedido(
              mesaId: mesaId,
              comandaId: comandaId,
            );
            
            notifyListeners();
            
            debugPrint('📦 Pedido $pedidoIdSalvo enviado diretamente ao servidor');
            return FinalizarPedidoResult(
              sucesso: true,
              pedidoId: pedidoIdSalvo,
              pedidoRemoteId: pedidoRemoteId,
              vendaId: vendaId,
              foiEnviadoDireto: true,
            );
          } else {
            debugPrint('⚠️ [PedidoProvider] Falha ao enviar ao servidor: ${response.message}');
            
            // Se não permitir Hive, retorna erro
            if (!permitirHive) {
              return FinalizarPedidoResult(
                sucesso: false,
                erro: response.message.isNotEmpty 
                    ? response.message 
                    : 'Erro ao enviar pedido ao servidor',
              );
            }
            
            debugPrint('💾 [PedidoProvider] Salvando no Hive como fallback...');
            // Continua para salvar no Hive como fallback
          }
        } catch (e) {
          debugPrint('❌ [PedidoProvider] Erro ao enviar ao servidor: $e');
          
          // Se não permitir Hive, retorna erro
          if (!permitirHive) {
            return FinalizarPedidoResult(
              sucesso: false,
              erro: 'Erro ao enviar pedido: ${e.toString()}',
            );
          }
          
          debugPrint('💾 [PedidoProvider] Salvando no Hive como fallback...');
          // Continua para salvar no Hive como fallback
        }
      } else {
        debugPrint('⚠️ [PedidoProvider] PedidoService não configurado');
        
        // Se não permitir Hive e não tem serviço, retorna erro
        if (!permitirHive) {
          return FinalizarPedidoResult(
            sucesso: false,
            erro: 'Serviço de pedidos não configurado',
          );
        }
      }

      // Fallback: Salva no Hive (só se permitirHive=true)
      if (permitirHive) {
        debugPrint('💾 [PedidoProvider] Salvando pedido no Hive:');
        debugPrint('  - PedidoId: ${_pedidoAtual!.id}');
        
        // Marca o pedido como pendente de sincronização
        _pedidoAtual!.syncStatus = SyncStatusPedido.pendente;
        _pedidoAtual!.syncAttempts = 0;
        _pedidoAtual!.dataAtualizacao = DateTime.now();
        
        await _pedidoRepo.upsert(_pedidoAtual!);
        
        // Armazena ID do pedido antes de limpar
        final pedidoIdSalvo = _pedidoAtual!.id;
        
        // Limpa o pedido atual para permitir criar um novo, preservando mesa/comanda
        _inicializarPedido(
          mesaId: mesaId,
          comandaId: comandaId,
        );

        notifyListeners();
        
        debugPrint('📦 Pedido $pedidoIdSalvo salvo no Hive para sincronização');
        return FinalizarPedidoResult(
          sucesso: true,
          pedidoId: pedidoIdSalvo,
          foiEnviadoDireto: false,
        );
      }

      // Não deveria chegar aqui, mas por segurança
      return FinalizarPedidoResult(
        sucesso: false,
        erro: 'Erro desconhecido ao finalizar pedido',
      );
    } catch (e) {
      debugPrint('❌ Erro ao finalizar pedido: $e');
      return FinalizarPedidoResult(
        sucesso: false,
        erro: e.toString(),
      );
    }
  }

}

