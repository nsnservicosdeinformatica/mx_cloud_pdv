import 'package:flutter/material.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import 'package:provider/provider.dart';
import '../../presentation/providers/venda_balcao_provider.dart';
import '../../presentation/providers/payment_flow_provider.dart'; // 🆕 Import do PaymentFlowProvider
import '../../data/models/core/vendas/venda_dto.dart';
import '../../data/models/core/produto_agrupado.dart';
import '../../data/models/core/tipo_venda.dart';
import '../pedidos/restaurante/novo_pedido_restaurante_screen.dart';
import '../pagamento/pagamento_restaurante_screen.dart';
import '../../core/widgets/loading_helper.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/events/app_event_bus.dart';
import '../../widgets/h4nd_loading.dart';
import 'dart:async';

/// Helper para gerenciar pagamento de venda balcão com confirmação
class BalcaoPaymentHelper {
  /// Abre a tela de pagamento e intercepta o fechamento sem finalizar
  /// Mostra modal de confirmação perguntando se quer cancelar ou continuar
  /// Para pagamentos parciais, reabre automaticamente até saldo zerar
  /// Pode ser usado de qualquer lugar do código
  static Future<void> abrirPagamentoComConfirmacao({
    required BuildContext context,
    required VendaDto venda,
    required List<ProdutoAgrupado> produtosAgrupados,
    VoidCallback? onPagamentoProcessado,
    VoidCallback? onVendaConcluida,
  }) async {
    bool vendaFinalizada = false;
    VendaDto vendaAtual = venda;
    
    while (!vendaFinalizada) {
      if (!context.mounted) break;
      
      final result = await PagamentoRestauranteScreen.show(
        context,
        venda: vendaAtual,
        produtosAgrupados: produtosAgrupados,
        onPagamentoProcessado: () {
          // onPagamentoProcessado é chamado quando um pagamento é processado (mesmo parcial)
          // Permite que o chamador saiba que houve um pagamento e pode reagir
          onPagamentoProcessado?.call();
        },
        onVendaConcluida: () async {
          // onVendaConcluida é chamado quando a venda é realmente concluída/finalizada
          // Limpa venda pendente ao finalizar venda
          if (context.mounted) {
            final vendaBalcaoProvider = Provider.of<VendaBalcaoProvider>(context, listen: false);
            await vendaBalcaoProvider.limparVendaPendente();
          }
          onVendaConcluida?.call();
          vendaFinalizada = true;
        },
      );

      // Se fechou sem finalizar (result != true), mostra modal de confirmação
      if (context.mounted && result != true) {
        final confirmacao = await AppDialog.showConfirm(
          context: context,
          title: 'Venda Pendente',
          message: 'Existe uma venda balcão pendente de pagamento. '
              'Deseja cancelar esta venda ou continuar com o pagamento?',
          confirmText: 'Cancelar Venda',
          cancelText: 'Continuar Pagamento',
          confirmColor: Colors.red,
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.orange,
        );

        if (confirmacao == true) {
          // Usuário escolheu cancelar a venda
          if (context.mounted) {
            final vendaBalcaoProvider = Provider.of<VendaBalcaoProvider>(context, listen: false);
            final paymentFlowProvider = Provider.of<PaymentFlowProvider>(context, listen: false);
            
            // 🆕 Cancela venda pendente no PaymentFlowProvider
            paymentFlowProvider.cancelPendingSale();
            
            await vendaBalcaoProvider.limparVendaPendente();
          }
          vendaFinalizada = true; // Sai do loop
        } else {
          // Usuário escolheu continuar com o pagamento
          // 🆕 Prepara PaymentFlowProvider para venda pendente
          if (context.mounted) {
            final paymentFlowProvider = Provider.of<PaymentFlowProvider>(context, listen: false);
            paymentFlowProvider.prepareForPendingSale();
          }
          
          // Mostra loading durante a busca da venda atualizada
          LoadingHelper.show(context);
          
          try {
            // Atualiza a venda para garantir dados mais recentes e reabre o pagamento
            final vendaBalcaoProvider = Provider.of<VendaBalcaoProvider>(context, listen: false);
            final vendaId = vendaBalcaoProvider.vendaIdPendente;
            if (vendaId != null && context.mounted) {
              final vendaAtualizada = await vendaBalcaoProvider.buscarVendaAtualizada(context, vendaId);
              if (vendaAtualizada != null) {
                vendaAtual = vendaAtualizada; // Atualiza venda com dados mais recentes
                // O loop continuará e reabrirá o pagamento
              }
            }
          } finally {
            // Esconde loading após buscar venda
            LoadingHelper.hide(context);
          }
        }
      } else if (context.mounted && result == true) {
        // Tela fechou com result == true (pagamento foi processado)
        // Mas pode ser pagamento parcial - precisa verificar se ainda há saldo
        // Mostra loading durante a busca da venda atualizada
        LoadingHelper.show(context);
        
        try {
          final vendaBalcaoProvider = Provider.of<VendaBalcaoProvider>(context, listen: false);
          final vendaId = vendaBalcaoProvider.vendaIdPendente;
          if (vendaId != null) {
            // Busca venda atualizada para verificar saldo
            final vendaAtualizada = await vendaBalcaoProvider.buscarVendaAtualizada(context, vendaId);
            
            if (vendaAtualizada != null) {
              // Se ainda há saldo pendente, reabre automaticamente (pagamento parcial)
              if (vendaAtualizada.saldoRestante > 0.01) {
                vendaAtual = vendaAtualizada; // Atualiza venda com dados mais recentes
                // O loop continuará e reabrirá o pagamento automaticamente
                // Não mostra modal de confirmação - reabre direto
              } else {
                // Saldo zerou mas venda não foi concluída ainda
                // Aguarda o usuário concluir a venda (onVendaConcluida será chamado)
                // Por enquanto, reabre para que o usuário possa concluir
                vendaAtual = vendaAtualizada;
                // O loop continuará e reabrirá o pagamento para concluir
              }
            } else {
              // Erro ao buscar venda - considera finalizado para evitar loop infinito
              vendaFinalizada = true;
            }
          } else {
            // Não há venda pendente - considera finalizado
            vendaFinalizada = true;
          }
        } finally {
          // Esconde loading após buscar venda
          LoadingHelper.hide(context);
        }
      } else {
        // Result é null ou outro valor - considera finalizado
        vendaFinalizada = true;
      }
    }
  }
}

/// Estados de loading da tela balcão
enum _BalcaoLoadingState {
  idle,           // Sem loading - pode mostrar tela de pedido
  verificando,    // Verificando se há venda pendente
  buscandoVenda,  // Buscando dados da venda pendente
  abrindoPagamento, // Abrindo tela de pagamento
}

/// Tela de venda balcão (Restaurante)
/// Verifica se há venda pendente e abre pagamento ou tela de pedido
/// Mantém o bottom navigation visível
class BalcaoScreen extends StatefulWidget {
  final bool hideAppBar;
  final ValueNotifier<int>? navigationIndexNotifier;
  final int? screenIndex;

  const BalcaoScreen({
    super.key,
    this.hideAppBar = false,
    this.navigationIndexNotifier,
    this.screenIndex,
  });

  @override
  State<BalcaoScreen> createState() => _BalcaoScreenState();
}

class _BalcaoScreenState extends State<BalcaoScreen> {
  _BalcaoLoadingState _loadingState = _BalcaoLoadingState.idle;
  int _pedidoScreenKey = 0; // Contador para forçar reconstrução da tela de pedido
  int? _ultimoIndiceVerificado; // Último índice de navegação verificado
  StreamSubscription<AppEvent>? _eventSubscription; // Subscription para eventos

  /// Atualiza o estado de loading de forma segura
  void _atualizarLoadingState(_BalcaoLoadingState novoEstado) {
    if (mounted) {
      setState(() {
        _loadingState = novoEstado;
      });
    }
  }

  /// Reseta o estado para idle
  void _resetarParaIdle() {
    _atualizarLoadingState(_BalcaoLoadingState.idle);
  }

  /// Verifica se deve verificar venda pendente baseado na navegação
  bool _deveVerificarVendaPendente() {
    final currentIndex = widget.navigationIndexNotifier?.value;
    
    // Se navegou para outra tela, reseta e não verifica
    if (currentIndex != widget.screenIndex) {
      _ultimoIndiceVerificado = null;
      return false;
    }
    
    // Verifica se está na tela balcão e ainda não foi verificado nesta exibição
    return currentIndex == widget.screenIndex && 
           currentIndex != _ultimoIndiceVerificado &&
           _loadingState == _BalcaoLoadingState.idle;
  }

  /// Verifica venda pendente se necessário (baseado na navegação)
  void _verificarSeNecessario() {
    if (!_deveVerificarVendaPendente()) return;
    
    _ultimoIndiceVerificado = widget.navigationIndexNotifier?.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.navigationIndexNotifier?.value == widget.screenIndex) {
        _verificarVendaPendente();
      }
    });
  }

  /// Trata erro ao buscar venda (limpa pendente e reseta estado)
  Future<void> _tratarErroBuscaVenda() async {
    if (!mounted) return;
    final vendaBalcaoProvider = Provider.of<VendaBalcaoProvider>(context, listen: false);
    final paymentFlowProvider = Provider.of<PaymentFlowProvider>(context, listen: false);
    
    // 🆕 Cancela venda pendente no PaymentFlowProvider
    paymentFlowProvider.cancelPendingSale();
    
    await vendaBalcaoProvider.limparVendaPendente();
    _resetarParaIdle();
  }

  @override
  void initState() {
    super.initState();
    // Escuta mudanças no índice de navegação
    widget.navigationIndexNotifier?.addListener(_onNavigationIndexChanged);
    
    // Escuta eventos de venda balcão pendente criada
    _eventSubscription = AppEventBus.instance
        .on(TipoEvento.vendaBalcaoPendenteCriada)
        .listen(_onVendaBalcaoPendenteCriada);
    
    // Verifica se a tela já está sendo exibida inicialmente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _verificarSeNecessario();
      }
    });
  }

  @override
  void dispose() {
    widget.navigationIndexNotifier?.removeListener(_onNavigationIndexChanged);
    _eventSubscription?.cancel();
    super.dispose();
  }

  /// Callback chamado quando uma venda balcão pendente é criada
  /// Abre automaticamente a tela de pagamento
  void _onVendaBalcaoPendenteCriada(AppEvent evento) {
    final vendaId = evento.vendaId;
    if (vendaId == null) return;

    debugPrint('📢 [BalcaoScreen] Evento vendaBalcaoPendenteCriada recebido: $vendaId');
    
    // Se não estiver na tela balcão, navega para ela primeiro
    final currentIndex = widget.navigationIndexNotifier?.value;
    if (currentIndex != widget.screenIndex && widget.screenIndex != null) {
      widget.navigationIndexNotifier?.value = widget.screenIndex!;
    }

    // Abre pagamento diretamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _abrirPagamentoPendente(vendaId);
      }
    });
  }

  void _onNavigationIndexChanged() {
    // Usa método centralizado para verificar se deve verificar venda pendente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _verificarSeNecessario();
      }
    });
  }

  Future<void> _verificarVendaPendente() async {
    // Evita múltiplas verificações simultâneas
    if (_loadingState != _BalcaoLoadingState.idle) return;
    
    _atualizarLoadingState(_BalcaoLoadingState.verificando);

    final vendaBalcaoProvider = Provider.of<VendaBalcaoProvider>(context, listen: false);
    final vendaId = await vendaBalcaoProvider.verificarVendaPendente();

    if (vendaId == null) {
      // Não tem venda pendente → mostra tela de pedido
      // Incrementa key para forçar reconstrução e garantir que produtos sejam carregados
      if (mounted) {
        setState(() {
          _pedidoScreenKey++; // Força reconstrução da tela de pedido
        });
      }
      _resetarParaIdle();
      return;
    }

    // Tem venda pendente → busca venda e abre pagamento
    await _abrirPagamentoPendente(vendaId);
  }


  Future<void> _abrirPagamentoPendente(String vendaId) async {
    if (!mounted) {
      debugPrint('❌ [BalcaoScreen] Widget não está montado, não pode abrir pagamento');
      return;
    }

    try {
      // Atualiza estado para indicar que está buscando venda
      _atualizarLoadingState(_BalcaoLoadingState.buscandoVenda);

      // Busca venda usando VendaBalcaoProvider
      final vendaBalcaoProvider = Provider.of<VendaBalcaoProvider>(context, listen: false);
      final venda = await vendaBalcaoProvider.buscarVendaAtualizada(context, vendaId);

      if (venda == null) {
        // Erro ao buscar venda → limpa pendente e mostra tela de pedido
        await _tratarErroBuscaVenda();
        return;
      }

      // Para venda balcão, não temos os produtos agrupados salvos
      // Vamos usar lista vazia - a tela de pagamento vai calcular baseado na venda
      // TODO: Melhorar construção de produtosAgrupados buscando pedido da venda
      List<ProdutoAgrupado> produtosAgrupados = [];

      // 🆕 Prepara PaymentFlowProvider para venda pendente
      if (mounted) {
        final paymentFlowProvider = Provider.of<PaymentFlowProvider>(context, listen: false);
        paymentFlowProvider.prepareForPendingSale();
      }

      // Atualiza estado para indicar que está abrindo pagamento
      _atualizarLoadingState(_BalcaoLoadingState.abrindoPagamento);

      // Abre tela de pagamento em loop até finalizar ou cancelar
      if (mounted) {
        await BalcaoPaymentHelper.abrirPagamentoComConfirmacao(
          context: context,
          venda: venda,
          produtosAgrupados: produtosAgrupados,
          onPagamentoProcessado: () {
            // Pagamento processado (pode ser parcial) - não faz nada especial aqui
            // O helper já trata reabertura automática para pagamentos parciais
          },
          onVendaConcluida: () {
            // Venda concluída - atualiza estado
            _resetarParaIdle();
          },
        );
        
        // Após fechar o pagamento (seja finalizado ou cancelado), reseta estados
        if (mounted) {
          _resetarParaIdle();
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao abrir pagamento pendente: $e');
      // Em caso de erro, limpa pendente e mostra tela de pedido
      await _tratarErroBuscaVenda();
    }
  }


  @override
  Widget build(BuildContext context) {
    // Verifica se deve verificar venda pendente (usando método centralizado)
    _verificarSeNecessario();

    // Se está em qualquer estado de loading, mostra loading
    // Isso garante que a tela de pedido não apareça enquanto está verificando/buscando/abrindo
    if (_loadingState != _BalcaoLoadingState.idle) {
      return const Scaffold(
        body: Center(
          child: H4ndLoading(size: 60.0),
        ),
      );
    }

    // Não tem venda pendente e verificação terminou → mostra tela de pedido
    // A tela de pedido carrega produtos automaticamente via CategoriaNavigationTree
    // Usa key baseada em contador para forçar reconstrução quando necessário
          return AdaptiveLayout(
            child: NovoPedidoRestauranteScreen(
              key: ValueKey('balcao_pedido_$_pedidoScreenKey'),
              tipoVenda: TipoVenda.balcao,
              isModal: false,
            ),
          );
  }
}

