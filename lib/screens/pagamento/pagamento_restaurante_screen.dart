import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/payment/payment_service.dart';
import '../../core/payment/payment_method_option.dart';
import '../../core/payment/payment_provider.dart';
import '../../presentation/providers/payment_flow_provider.dart'; // 🆕 Import do PaymentFlowProvider
import '../../presentation/providers/venda_balcao_provider.dart'; // 🆕 Import do VendaBalcaoProvider
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../presentation/providers/services_provider.dart';
import '../../data/models/core/vendas/venda_dto.dart';
import '../../data/models/core/vendas/venda_resumo_dto.dart';
import '../../data/models/core/produto_agrupado.dart';
import '../../data/models/core/vendas/produto_nota_fiscal_dto.dart';
import '../../data/services/core/venda_service.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/events/app_event_bus.dart';
import '../../core/printing/print_service.dart';
import '../../core/payment/payment_flow_state.dart'; // 🆕 Import dos estados
import '../../core/widgets/payment_flow_status_modal.dart'; // 🆕 Import do modal padrão
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Tela de pagamento específica para restaurante (mesas/comandas)
/// Permite selecionar produtos para pagar com nota fiscal ou fazer pagamento de reserva
class PagamentoRestauranteScreen extends StatefulWidget {
  final VendaDto venda;
  final List<ProdutoAgrupado> produtosAgrupados;
  /// Callback chamado quando um pagamento é processado com sucesso (mesmo que parcial)
  final VoidCallback? onPagamentoProcessado;
  /// Callback chamado quando a venda é concluída/finalizada
  final VoidCallback? onVendaConcluida;
  final bool isModal; // Indica se deve ser exibido como modal
  /// Lista de IDs de vendas para pagamento múltiplo (quando fornecido, agrupa automaticamente)
  final List<String>? vendaIds;
  /// Resumo das vendas para exibir informações (usado quando vendaIds != null)
  final List<VendaResumoDto>? vendasResumo;

  const PagamentoRestauranteScreen({
    super.key,
    required this.venda,
    required this.produtosAgrupados,
    this.onPagamentoProcessado,
    this.onVendaConcluida,
    this.isModal = false,
    this.vendaIds,
    this.vendasResumo,
  });

  /// Mostra o pagamento de forma adaptativa:
  /// - Mobile: Tela cheia (Navigator.push)
  /// - Desktop/Tablet: Modal (showDialog)
  static Future<bool?> show(
    BuildContext context, {
    required VendaDto venda,
    required List<ProdutoAgrupado> produtosAgrupados,
    VoidCallback? onPagamentoProcessado,
    VoidCallback? onVendaConcluida,
    List<String>? vendaIds,
    List<VendaResumoDto>? vendasResumo,
  }) async {
    final adaptive = AdaptiveLayoutProvider.of(context);
    
    // Mobile: usa tela cheia
    if (adaptive?.isMobile ?? true) {
      return await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => AdaptiveLayout(
            child: PagamentoRestauranteScreen(
              venda: venda,
              produtosAgrupados: produtosAgrupados,
              onPagamentoProcessado: onPagamentoProcessado,
              onVendaConcluida: onVendaConcluida,
              isModal: false,
              vendaIds: vendaIds,
              vendasResumo: vendasResumo,
            ),
          ),
        ),
      );
    }
    
    // Desktop/Tablet: usa modal
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdaptiveLayout(
        child: PagamentoRestauranteScreen(
          venda: venda,
          produtosAgrupados: produtosAgrupados,
          onPagamentoProcessado: onPagamentoProcessado,
          onVendaConcluida: onVendaConcluida,
          isModal: true,
          vendaIds: vendaIds,
          vendasResumo: vendasResumo,
        ),
      ),
    );
  }

  @override
  State<PagamentoRestauranteScreen> createState() => _PagamentoRestauranteScreenState();
}

class _PagamentoRestauranteScreenState extends State<PagamentoRestauranteScreen> {
  // 🆕 Flag para garantir que onVendaConcluida seja chamado apenas uma vez
  bool _vendaConcluidaCallbackChamado = false;
  PaymentService? _paymentService; // Ainda usado para obter métodos de pagamento
  List<PaymentMethodOption> _paymentMethods = [];
  bool _isLoading = false;
  // 🆕 Removido: _isProcessing agora é gerenciado pelo PaymentFlowProvider
  PaymentMethodOption? _selectedMethod;
  final TextEditingController _valorController = TextEditingController();
  
  // Emitir nota parcial: se true, permite selecionar produtos para pagamento parcial com nota fiscal
  bool _emitirNotaParcial = false;
  
  // Produtos selecionados para pagamento (quando emitirNotaParcial = true)
  final Map<String, double> _produtosSelecionados = {}; // produtoId -> quantidade selecionada
  
  // Venda atualizada (para refletir mudanças após pagamentos)
  VendaDto? _vendaAtualizada;

  VendaService get _vendaService {
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    return servicesProvider.vendaService;
  }

  @override
  void initState() {
    super.initState();
    
    // 🆕 RESETA o PaymentFlowProvider para garantir estado inicial correto
    // Isso é importante porque o provider é compartilhado e pode estar em estado inválido
    // após cancelar uma venda ou concluir outra
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final paymentFlowProvider = Provider.of<PaymentFlowProvider>(context, listen: false);
      debugPrint('🔄 [PagamentoRestauranteScreen] Resetando PaymentFlowProvider');
      debugPrint('🔄 Estado antes do reset: ${paymentFlowProvider.currentState.description}');
      paymentFlowProvider.reset();
      debugPrint('🔄 Estado após reset: ${paymentFlowProvider.currentState.description}');
    });
    
    _initializePayment();
    _valorController.text = widget.venda.saldoRestante.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _initializePayment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _paymentService = await PaymentService.getInstance();
      _paymentMethods = _paymentService!.getAvailablePaymentMethods();
      
      if (_paymentMethods.isNotEmpty) {
        _selectedMethod = _paymentMethods.first;
      }
    } catch (e) {
      AppToast.showError(context, 'Erro ao inicializar pagamento: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Usa venda atualizada se disponível, senão usa a venda original
  VendaDto get _vendaAtual => _vendaAtualizada ?? widget.venda;
  
  double get _valorTotal => _vendaAtual.valorTotal;
  double get _totalPago => _vendaAtual.totalPago;
  double get _saldoRestante => _vendaAtual.saldoRestante;
  
  /// ✅ Getter reutilizável para verificar se saldo zerou
  bool get _saldoZerou => _saldoRestante <= 0.01;
  
  /// Verifica se é pagamento de múltiplas vendas
  bool get _isPagamentoMultiplasVendas => widget.vendaIds != null && widget.vendaIds!.length > 1;

  double? get _valorDigitado {
    final valor = double.tryParse(_valorController.text.replaceAll(',', '.'));
    return valor;
  }

  /// Calcula o valor total dos produtos selecionados
  double _calcularValorProdutosSelecionados() {
    double total = 0.0;
    for (final produto in widget.produtosAgrupados) {
      final quantidadeSelecionada = _produtosSelecionados[produto.produtoId] ?? 0.0;
      if (quantidadeSelecionada > 0) {
        total += produto.precoUnitario * quantidadeSelecionada;
      }
    }
    return total;
  }

  /// Verifica se há produtos selecionados
  bool get _temProdutosSelecionados {
    return _produtosSelecionados.values.any((qtd) => qtd > 0);
  }

  /// Quantidade disponível de um produto (quantidade total - já selecionada)
  double _quantidadeDisponivel(ProdutoAgrupado produto) {
    final selecionada = _produtosSelecionados[produto.produtoId] ?? 0.0;
    return produto.quantidadeTotal - selecionada;
  }

  /// Seleciona/deseleciona quantidade de um produto
  void _selecionarProduto(ProdutoAgrupado produto, double quantidade) {
    setState(() {
      if (quantidade <= 0) {
        _produtosSelecionados.remove(produto.produtoId);
      } else {
        final maxQuantidade = produto.quantidadeTotal.toDouble();
        _produtosSelecionados[produto.produtoId] = quantidade > maxQuantidade ? maxQuantidade : quantidade;
      }
      
      // Atualiza valor do campo se emitir nota parcial estiver marcado
      if (_emitirNotaParcial) {
        final valorProdutos = _calcularValorProdutosSelecionados();
        if (valorProdutos > 0) {
          _valorController.text = valorProdutos.toStringAsFixed(2);
        } else {
          _valorController.text = _saldoRestante.toStringAsFixed(2);
        }
      }
    });
  }

  Future<void> _processarPagamento() async {
    if (_selectedMethod == null) {
      AppToast.showError(context, 'Selecione uma forma de pagamento');
      return;
    }

    // Validação baseada na opção de emitir nota parcial
    if (_emitirNotaParcial) {
      // Modo nota parcial: deve ter produtos selecionados
      if (!_temProdutosSelecionados) {
        AppToast.showError(context, 'Selecione pelo menos um produto para pagar');
        return;
      }
      
      final valorProdutos = _calcularValorProdutosSelecionados();
      final valor = _valorDigitado ?? valorProdutos;
      
      if (valor <= 0) {
        AppToast.showError(context, 'Digite um valor válido');
        return;
      }
      
      // Valida se o valor digitado corresponde ao valor dos produtos selecionados
      if ((valor - valorProdutos).abs() > 0.01) {
        final confirm = await AppDialog.showConfirm(
          context: context,
          title: 'Valor diferente dos produtos',
          message: 'O valor digitado (R\$ ${valor.toStringAsFixed(2)}) é diferente do valor dos produtos selecionados (R\$ ${valorProdutos.toStringAsFixed(2)}). Deseja continuar?',
        );
        if (confirm != true) return;
      }
    } else {
      // Modo normal: apenas valida valor
      final valor = _valorDigitado;
      if (valor == null || valor <= 0) {
        AppToast.showError(context, 'Digite um valor válido');
        return;
      }
      
      if (valor > _saldoRestante) {
        final confirm = await AppDialog.showConfirm(
          context: context,
          title: 'Valor maior que o saldo',
          message: 'O valor digitado (R\$ ${valor.toStringAsFixed(2)}) é maior que o saldo restante (R\$ ${_saldoRestante.toStringAsFixed(2)}). Deseja continuar?',
        );
        if (confirm != true) return;
      }
    }

    // 🆕 Obtém PaymentFlowProvider do contexto
    final paymentFlowProvider = Provider.of<PaymentFlowProvider>(context, listen: false);
    
    try {
      final valor = _valorDigitado ?? _calcularValorProdutosSelecionados();
      
      // Determina provider key e dados adicionais baseado no método selecionado
      String providerKey = _selectedMethod!.providerKey;
      Map<String, dynamic>? additionalData;

      if (_selectedMethod!.type == PaymentType.cash) {
        providerKey = 'cash';
        additionalData = {
          'valorRecebido': valor,
        };
      } else if (_selectedMethod!.type == PaymentType.pos) {
        providerKey = _selectedMethod!.providerKey;
        // Determina tipo de transação baseado no label do método selecionado
        final tipoTransacao = _selectedMethod!.label.toLowerCase().contains('débito') || 
                             _selectedMethod!.label.toLowerCase().contains('debito')
            ? 'debit'
            : 'credit';
        additionalData = {
          'tipoTransacao': tipoTransacao,
          'parcelas': 1,
          'imprimirRecibo': false,
        };
      } else {
        providerKey = 'cash';
      }

      // 🆕 Usa PaymentFlowProvider para processar pagamento
      // O provider gerencia estado e notificações de UI automaticamente
      // Não precisa mais mostrar/esconder dialog manualmente
      await paymentFlowProvider.processPayment(
        providerKey: providerKey,
        amount: valor,
        vendaId: widget.venda.id,
        additionalData: additionalData,
      );

      // 🆕 Obtém resultado do provider
      final result = paymentFlowProvider.lastResult;
      
      if (result == null) {
        AppToast.showError(context, 'Erro ao processar pagamento: resultado não disponível');
        return;
      }

      // 🆕 Verifica se houve erro no provider
      if (paymentFlowProvider.errorMessage != null) {
        AppToast.showError(context, paymentFlowProvider.errorMessage!);
        paymentFlowProvider.clearError(); // Limpa erro após mostrar
        return;
      }

      if (result.success) {
        // Prepara lista de produtos para nota fiscal (se emitir nota parcial)
        List<Map<String, dynamic>>? produtosParaNota;
        if (_emitirNotaParcial && _temProdutosSelecionados) {
          produtosParaNota = _produtosSelecionados.entries
              .where((e) => e.value > 0)
              .map((e) => ProdutoNotaFiscalDto(
                    produtoId: e.key,
                    quantidade: e.value,
                  ).toJson())
              .toList();
        }

        // 🆕 Registra pagamento usando o provider (gerencia estado automaticamente)
        if (_selectedMethod!.type == PaymentType.cash || 
            _selectedMethod!.type == PaymentType.pos ||
            !(result.metadata?['pending'] == true)) {
          // Determina tipo de forma de pagamento baseado apenas no PaymentType e label
          final tipoFormaPagamento = _determinarTipoFormaPagamento(_selectedMethod!);
          
          // Extrai dados de transação do resultado padronizado
          String? bandeiraCartao;
          String? identificadorTransacao;
          
          if (result.transactionData != null) {
            final txData = result.transactionData!;
            bandeiraCartao = txData.cardBrandName ?? txData.cardBrand;
            identificadorTransacao = txData.initiatorTransactionKey ?? 
                                    txData.transactionReference ?? 
                                    result.transactionId;
          } else if (result.transactionId != null) {
            // Fallback: usa transactionId se não houver transactionData
            identificadorTransacao = result.transactionId;
          }
          
          // 🆕 Usa provider para registrar pagamento (mostra estado registeringPayment)
          final registroSuccess = await paymentFlowProvider.registerPayment(
            vendaService: _vendaService,
            vendaId: _isPagamentoMultiplasVendas ? null : widget.venda.id,
            vendaIds: _isPagamentoMultiplasVendas ? widget.vendaIds : null,
            valor: valor,
            formaPagamento: _selectedMethod!.label,
            tipoFormaPagamento: tipoFormaPagamento,
            bandeiraCartao: bandeiraCartao,
            identificadorTransacao: identificadorTransacao,
            produtos: produtosParaNota,
            transactionData: result.transactionData,
          );
          
          if (registroSuccess) {
            // 🆕 Usa a venda atualizada que o PaymentFlowProvider já buscou
            // Se múltiplas vendas, essa venda já é a venda agrupada retornada pelo backend
            final vendaAtualizadaDoProvider = paymentFlowProvider.vendaAtualizadaAposPagamento;
            
            if (vendaAtualizadaDoProvider != null) {
              setState(() {
                _vendaAtualizada = vendaAtualizadaDoProvider;
                _valorController.text = _saldoRestante > 0.01 
                    ? _saldoRestante.toStringAsFixed(2) 
                    : '0.00';
              });
            } else {
              // Fallback: busca pela primeira venda ou venda base (não deveria acontecer)
              final vendaIdParaBuscar = _isPagamentoMultiplasVendas 
                  ? (widget.vendaIds?.first ?? widget.venda.id)
                  : widget.venda.id;
              
              final vendaResponse = await _vendaService.getVendaById(vendaIdParaBuscar);
              if (vendaResponse.success && vendaResponse.data != null) {
                setState(() {
                  _vendaAtualizada = vendaResponse.data!;
                  _valorController.text = _saldoRestante > 0.01 
                      ? _saldoRestante.toStringAsFixed(2) 
                      : '0.00';
                });
              }
            }
            
            AppToast.showSuccess(context, 'Pagamento realizado com sucesso!');
            
            // Dispara evento de pagamento processado
            // Se múltiplas vendas, dispara para todas ou para a venda agrupada
            final vendaIdEvento = _isPagamentoMultiplasVendas 
                ? (_vendaAtualizada?.id ?? widget.vendaIds?.first ?? widget.venda.id)
                : (_vendaAtualizada?.id ?? widget.venda.id);
            
            AppEventBus.instance.dispararPagamentoProcessado(
              vendaId: vendaIdEvento,
              valor: valor,
              mesaId: widget.venda.mesaId,
              comandaId: widget.venda.comandaId,
            );
            
            // Limpa seleção de produtos
            _produtosSelecionados.clear();
            
            // Chama onPagamentoProcessado quando um pagamento é processado (mesmo que parcial)
            if (widget.onPagamentoProcessado != null) {
              widget.onPagamentoProcessado!();
            }
            
            // ✅ Usa getter reutilizável para verificar saldo
            if (!_saldoZerou) {
              // Ainda há saldo - fecha tela para permitir novo pagamento
              Navigator.of(context).pop(true);
            }
            // Se saldo zerou, mantém a tela aberta mostrando o botão "Concluir Venda"
          } else {
            // Erro já foi tratado pelo provider
            if (paymentFlowProvider.errorMessage != null) {
              AppToast.showError(context, paymentFlowProvider.errorMessage!);
              paymentFlowProvider.clearError();
            }
          }
        }
      } else {
        // Fecha diálogo se estiver aberto (para qualquer tipo POS)
        if (_selectedMethod!.type == PaymentType.pos && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        AppToast.showError(context, result.errorMessage ?? 'Erro ao processar pagamento');
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      AppToast.showError(context, 'Erro ao processar pagamento: $e');
    } finally {
      setState(() {
        // 🆕 Removido: _isProcessing agora é gerenciado pelo PaymentFlowProvider
      });
    }
  }

  /// Determina o tipo de forma de pagamento baseado apenas no PaymentType e label
  /// Não depende de provider específico
  int _determinarTipoFormaPagamento(PaymentMethodOption method) {
    switch (method.type) {
      case PaymentType.cash:
        return 1; // Dinheiro
      case PaymentType.pos:
        // Para POS, verifica se é débito ou crédito baseado no label
        final isDebito = method.label.toLowerCase().contains('débito') || 
                        method.label.toLowerCase().contains('debito');
        return isDebito ? 3 : 2; // 3 = Débito, 2 = Crédito
      case PaymentType.tef:
        return 2; // Cartão (padrão)
    }
  }

  /// ✅ Conclui a venda usando PaymentFlowProvider (com State Machine)
  /// 
  /// O modal de status será mostrado automaticamente pelo PaymentFlowStatusModal
  /// quando o estado mudar para processamento
  Future<void> _concluirVenda() async {
    // 🆕 Obtém PaymentFlowProvider do contexto
    final paymentFlowProvider = Provider.of<PaymentFlowProvider>(context, listen: false);
    
    // 🆕 Verifica se pode concluir antes de tentar
    debugPrint('🏁 [PagamentoRestauranteScreen] ========== TENTANDO CONCLUIR VENDA ==========');
    debugPrint('🏁 Estado atual: ${paymentFlowProvider.currentState.description}');
    debugPrint('🏁 canConcludeSale: ${paymentFlowProvider.canConcludeSale}');
    debugPrint('🏁 Saldo zerou? $_saldoZerou');
    debugPrint('🏁 Saldo restante: R\$ ${_saldoRestante.toStringAsFixed(2)}');
    
    // 🆕 Se não pode concluir mas o saldo zerou, tenta marcar como pronto primeiro
    if (!paymentFlowProvider.canConcludeSale && _saldoZerou) {
      debugPrint('⚠️ [PagamentoRestauranteScreen] Não pode concluir, mas saldo zerou. Tentando markReadyToComplete()...');
      paymentFlowProvider.markReadyToComplete();
      debugPrint('🏁 Estado após markReadyToComplete: ${paymentFlowProvider.currentState.description}');
      debugPrint('🏁 canConcludeSale após: ${paymentFlowProvider.canConcludeSale}');
    }
    
    // 🆕 Usa PaymentFlowProvider para concluir venda
    // O modal de status será mostrado automaticamente quando o estado mudar
      final success = await paymentFlowProvider.concludeSale(
        concluirVendaCallback: (vendaId) => _vendaService.concluirVenda(vendaId),
        getVendaCallback: (vendaId) => _vendaService.getVendaById(vendaId), // ✅ Adiciona callback para buscar venda
        vendaId: widget.venda.id,
      );
    
    if (!success) {
      // Se falhou, mostra erro
      if (paymentFlowProvider.errorMessage != null) {
        AppToast.showError(context, paymentFlowProvider.errorMessage!);
        paymentFlowProvider.clearError();
      }
      return;
    }
    
    // Se sucesso, continua com impressão e finalização
    if (success) {
      // Se sucesso, verifica se precisa imprimir nota fiscal
      // O provider já transicionou para invoiceAuthorized se tem nota fiscal
      if (paymentFlowProvider.currentState == PaymentFlowState.invoiceAuthorized) {
        // Busca dados e imprime
        final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
        final notaFiscalId = paymentFlowProvider.vendaFinalizadaData?['notaFiscalId'] as String?;
        
        if (notaFiscalId != null) {
          // Imprime usando o provider (gerencia estados automaticamente)
          await paymentFlowProvider.printInvoice(
            printNfceCallback: (data) async {
              final printService = await PrintService.getInstance();
              return await printService.printNfce(data: data);
            },
            getDadosCallback: (id) => servicesProvider.notaFiscalService.getDadosParaImpressao(id),
            notaFiscalId: notaFiscalId,
          );
        }
      }
      
      // Verifica se houve erro
      if (paymentFlowProvider.errorMessage != null) {
        AppToast.showError(context, paymentFlowProvider.errorMessage!);
        paymentFlowProvider.clearError();
      } else {
        AppToast.showSuccess(context, 'Venda concluída com sucesso!');
      }
      
      // Dispara evento de venda finalizada
      if (widget.venda.mesaId != null) {
        AppEventBus.instance.dispararVendaFinalizada(
          vendaId: widget.venda.id,
          mesaId: widget.venda.mesaId!,
          comandaId: widget.venda.comandaId,
        );
      }
      
      // 🆕 onVendaConcluida será chamado automaticamente no build() quando estado for completed
      // Isso garante que a venda pendente seja limpa antes do dialog fechar
    } else {
      // Se falhou, mostra erro
      if (paymentFlowProvider.errorMessage != null) {
        AppToast.showError(context, paymentFlowProvider.errorMessage!);
        paymentFlowProvider.clearError();
      }
    }
  }

  /// 🆕 Mostra diálogo informativo para pagamento via SDK
  /// Agora recebe mensagem do provider
  void _mostrarDialogAguardandoCartao(BuildContext context, String message) {
    if (_isDialogAberto) return; // Evita abrir múltiplos dialogs
    
    _isDialogAberto = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.credit_card,
                      size: 48,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Aguardando Cartão',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message, // 🆕 Usa mensagem do provider
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _isDialogAberto = false; // Marca como fechado quando dialog é fechado
    });
  }

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ✅ Único Consumer no build principal
    return Consumer<PaymentFlowProvider>(
      builder: (context, paymentFlowProvider, child) {
        // 🆕 Fecha dialog automaticamente quando venda é concluída
        if (paymentFlowProvider.currentState == PaymentFlowState.completed && !_vendaConcluidaCallbackChamado) {
          _vendaConcluidaCallbackChamado = true; // Marca como chamado para evitar múltiplas chamadas
          
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            
            try {
              // 🆕 Limpa venda pendente diretamente (se for venda balcão)
              // Isso garante que a limpeza aconteça mesmo se o callback não for chamado
              try {
                final vendaBalcaoProvider = Provider.of<VendaBalcaoProvider>(context, listen: false);
                if (vendaBalcaoProvider.temVendaPendente && vendaBalcaoProvider.vendaIdPendente == widget.venda.id) {
                  await vendaBalcaoProvider.limparVendaPendente();
                  debugPrint('✅ [PagamentoRestauranteScreen] Venda pendente limpa: ${widget.venda.id}');
                }
              } catch (e) {
                // Se não tiver VendaBalcaoProvider ou não for venda balcão, ignora
                debugPrint('ℹ️ [PagamentoRestauranteScreen] Não é venda balcão ou provider não disponível: $e');
              }
              
              // 🆕 Chama callback de venda concluída ANTES de fechar
              // Isso garante que a venda pendente seja limpa antes do dialog fechar
              if (widget.onVendaConcluida != null) {
                await Future.microtask(() => widget.onVendaConcluida!());
                debugPrint('✅ [PagamentoRestauranteScreen] onVendaConcluida chamado com sucesso');
              }
            } catch (e) {
              debugPrint('❌ [PagamentoRestauranteScreen] Erro ao processar conclusão: $e');
            }
            
            // Fecha dialog/tela após limpar venda pendente
            if (mounted && Navigator.canPop(context)) {
              Navigator.of(context).pop(true);
              debugPrint('✅ [PagamentoRestauranteScreen] Dialog fechado após venda concluída');
            }
          });
        }
        
        // Gerencia dialog "Aguardando cartão"
        _handleWaitingCardDialog(context, paymentFlowProvider);
        
        // 🆕 Mostra/esconde modal de status automaticamente baseado no estado
        PaymentFlowStatusModal.showIfNeeded(context, paymentFlowProvider);
        
        // Passa provider para métodos auxiliares
        return _buildScaffold(adaptive, paymentFlowProvider);
      },
    );
  }
  
  /// ✅ Método auxiliar para gerenciar dialog "Aguardando cartão"
  void _handleWaitingCardDialog(BuildContext context, PaymentFlowProvider provider) {
    if (provider.showWaitingCardDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDialogAberto) {
          _mostrarDialogAguardandoCartao(context, provider.waitingCardMessage);
        }
      });
    } else {
      if (_isDialogAberto) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
            _isDialogAberto = false;
          }
        });
      }
    }
  }

  // 🆕 Flag para controlar se dialog está aberto
  bool _isDialogAberto = false;

  // ✅ Método auxiliar para construir o scaffold (recebe provider)
  Widget _buildScaffold(AdaptiveLayoutProvider adaptive, PaymentFlowProvider paymentFlowProvider) {
    // Conteúdo comum (reutilizado em ambos os modos)
    Widget buildContent() {
      if (_isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      
      // ✅ Usa getter reutilizável
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Resumo da venda
          _buildResumoVenda(adaptive),
          
          // Informações das múltiplas vendas (se aplicável)
          if (_isPagamentoMultiplasVendas)
            _buildInfoMultiplasVendas(adaptive),
          
          // Opção de emitir nota parcial (apenas se houver saldo e não for múltiplas vendas)
          if (!_saldoZerou && !_isPagamentoMultiplasVendas)
            _buildOpcaoNotaParcial(adaptive),
          
          // Lista de produtos (se emitir nota parcial estiver marcado)
          if (!_saldoZerou && _emitirNotaParcial)
            widget.isModal
                ? ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: _buildListaProdutos(adaptive),
                  )
                : Expanded(
                    child: _buildListaProdutos(adaptive),
                  ),
          
          // Formulário de pagamento (passa provider)
          _buildFormularioPagamento(adaptive, paymentFlowProvider),
        ],
      );
    }

    // Modal: usa Dialog
    if (widget.isModal) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: adaptive.isDesktop ? 100 : 50,
          vertical: adaptive.isDesktop ? 40 : 20,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: adaptive.isDesktop ? 800 : 600,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // Header do modal
              Container(
                padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.payment,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    SizedBox(width: adaptive.isMobile ? 12 : 16),
                    Expanded(
                      child: Text(
                        'Pagamento',
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 18 : 20,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textPrimary),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),
              // Conteúdo com scroll
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
                  child: buildContent(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Tela cheia: usa Scaffold (mobile)
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Pagamento',
          style: GoogleFonts.inter(
            fontSize: adaptive.isMobile ? 18 : 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: buildContent(),
      ),
    );
  }

  Widget _buildResumoVenda(AdaptiveLayoutProvider adaptive) {
    final padding = adaptive.isMobile ? 16.0 : 20.0;
    
    return Container(
      margin: EdgeInsets.fromLTRB(padding, padding, padding, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: padding,
          vertical: adaptive.isMobile ? 18 : 22,
        ),
        child: Row(
          children: [
            // Total da Venda
            Expanded(
              child: _buildResumoItem(
                label: 'Total',
                valor: _valorTotal,
                color: AppTheme.textPrimary,
                icon: Icons.receipt_long,
                adaptive: adaptive,
              ),
            ),
            // Divisor vertical
            _buildDivider(),
            // Total Pago
            Expanded(
              child: _buildResumoItem(
                label: 'Pago',
                valor: _totalPago,
                color: AppTheme.successColor,
                icon: Icons.check_circle,
                adaptive: adaptive,
              ),
            ),
            // Divisor vertical
            _buildDivider(),
            // Saldo Restante
            Expanded(
              child: _buildResumoItem(
                label: 'Saldo',
                valor: _saldoRestante,
                color: _saldoRestante > 0 ? AppTheme.errorColor : AppTheme.successColor,
                icon: _saldoRestante > 0 ? Icons.pending : Icons.check_circle_outline,
                adaptive: adaptive,
                isHighlight: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.grey.shade200,
    );
  }

  /// Exibe informações sobre as múltiplas vendas sendo pagas
  Widget _buildInfoMultiplasVendas(AdaptiveLayoutProvider adaptive) {
    if (widget.vendasResumo == null || widget.vendasResumo!.isEmpty) {
      return const SizedBox.shrink();
    }

    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final vendas = widget.vendasResumo!;
    final saldoTotal = vendas.fold<double>(0, (sum, v) => sum + v.saldoRestante);

    final padding = adaptive.isMobile ? 16.0 : 20.0;

    return Container(
      margin: EdgeInsets.fromLTRB(padding, 12, padding, 0),
      padding: EdgeInsets.all(adaptive.isMobile ? 16 : 18),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pagando ${vendas.length} venda${vendas.length > 1 ? 's' : ''} juntas',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...vendas.take(3).map((venda) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      venda.isVendaSemComanda
                          ? Icons.table_restaurant
                          : Icons.receipt_long,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        venda.isVendaSemComanda
                            ? 'Sem Comanda'
                            : 'Comanda ${venda.comandaCodigo ?? ''}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      formatter.format(venda.saldoRestante),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              )),
          if (vendas.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '... e mais ${vendas.length - 3} venda${vendas.length - 3 > 1 ? 's' : ''}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total a pagar:',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  formatter.format(saldoTotal),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoItem({
    required String label,
    required double valor,
    required Color color,
    required IconData icon,
    required AdaptiveLayoutProvider adaptive,
    bool isHighlight = false,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: color.withOpacity(0.8),
            ),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'R\$ ${valor.toStringAsFixed(2)}',
          style: GoogleFonts.inter(
            fontSize: isHighlight ? 19 : 17,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: -0.3,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOpcaoNotaParcial(AdaptiveLayoutProvider adaptive) {
    final padding = adaptive.isMobile ? 16.0 : 20.0;
    
    return Container(
      margin: EdgeInsets.fromLTRB(padding, 12, padding, 0),
      padding: EdgeInsets.all(adaptive.isMobile ? 16 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _emitirNotaParcial ? AppTheme.primaryColor.withOpacity(0.3) : Colors.grey.shade200,
          width: _emitirNotaParcial ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _emitirNotaParcial = !_emitirNotaParcial;
            if (!_emitirNotaParcial) {
              // Limpa seleção de produtos ao desmarcar
              _produtosSelecionados.clear();
              _valorController.text = _saldoRestante.toStringAsFixed(2);
            } else {
              // Atualiza valor baseado nos produtos selecionados (se houver)
              final valorProdutos = _calcularValorProdutosSelecionados();
              if (valorProdutos > 0) {
                _valorController.text = valorProdutos.toStringAsFixed(2);
              }
            }
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            // Checkbox customizado
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _emitirNotaParcial ? AppTheme.primaryColor : Colors.transparent,
                border: Border.all(
                  color: _emitirNotaParcial ? AppTheme.primaryColor : Colors.grey.shade400,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: _emitirNotaParcial
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Texto e descrição
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emitir Nota Parcial',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pagamento parcial com emissão de notas fiscais. Será necessário marcar os produtos que serão pagos.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaProdutos(AdaptiveLayoutProvider adaptive) {
    if (widget.produtosAgrupados.isEmpty) {
      return Center(
        child: Text(
          'Nenhum produto disponível',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    final padding = adaptive.isMobile ? 16.0 : 20.0;
    
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(padding, 12, padding, padding),
      itemCount: widget.produtosAgrupados.length,
      itemBuilder: (context, index) {
        final produto = widget.produtosAgrupados[index];
        final quantidadeSelecionada = _produtosSelecionados[produto.produtoId] ?? 0.0;
        final quantidadeDisponivel = _quantidadeDisponivel(produto);
        
        return _buildProdutoCard(produto, quantidadeSelecionada, quantidadeDisponivel, adaptive);
      },
    );
  }

  Widget _buildProdutoCard(
    ProdutoAgrupado produto,
    double quantidadeSelecionada,
    double quantidadeDisponivel,
    AdaptiveLayoutProvider adaptive,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(adaptive.isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: quantidadeSelecionada > 0
            ? Border.all(color: AppTheme.primaryColor, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      produto.produtoNome,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (produto.produtoVariacaoNome != null && produto.produtoVariacaoNome!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        produto.produtoVariacaoNome!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'R\$ ${produto.precoUnitario.toStringAsFixed(2)} cada',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Disponível: ${produto.quantidadeTotal.toInt()}x',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (quantidadeSelecionada > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Selecionado: ${quantidadeSelecionada.toInt()}x',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: quantidadeSelecionada > 0
                      ? () => _selecionarProduto(produto, quantidadeSelecionada - 1)
                      : null,
                  icon: const Icon(Icons.remove, size: 18),
                  label: const Text('Menos'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  quantidadeSelecionada.toInt().toString(),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: quantidadeDisponivel > 0
                      ? () => _selecionarProduto(produto, quantidadeSelecionada + 1)
                      : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Mais'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormularioPagamento(AdaptiveLayoutProvider adaptive, PaymentFlowProvider paymentFlowProvider) {
    final valorProdutos = _emitirNotaParcial ? _calcularValorProdutosSelecionados() : 0.0;
    final padding = adaptive.isMobile ? 16.0 : 20.0;
    // ✅ Usa getter reutilizável
    
    return Container(
      margin: EdgeInsets.fromLTRB(padding, 12, padding, padding),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Se saldo é zero, mostra mensagem e botão de concluir
          if (_saldoZerou) ...[
            Container(
              padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.successColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: AppTheme.successColor,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Saldo Totalmente Pago',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.successColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Todos os pagamentos foram realizados. Conclua a venda para finalizar.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // ✅ Usa widget reutilizável (provider já passado como parâmetro)
                  // 🆕 Mostra mensagem diferente baseado no estado
                  _buildActionButton(
                    onPressed: _concluirVenda,
                    text: _getButtonTextForState(paymentFlowProvider.currentState),
                    backgroundColor: AppTheme.primaryColor,
                    icon: _getIconForState(paymentFlowProvider.currentState),
                    isProcessing: paymentFlowProvider.isProcessing,
                    adaptive: adaptive,
                  ),
                ],
              ),
            ),
          ] else ...[
            // Valor dos produtos selecionados (se emitir nota parcial)
            if (_emitirNotaParcial && _temProdutosSelecionados) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Valor Selecionado',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    'R\$ ${valorProdutos.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            
            // Campo de valor
            TextField(
              controller: _valorController,
              enabled: !_isPagamentoMultiplasVendas,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Valor do Pagamento',
                hintText: _isPagamentoMultiplasVendas 
                    ? 'Valor fixo (todas as vendas)' 
                    : '0.00',
                prefixIcon: const Icon(Icons.attach_money, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: _isPagamentoMultiplasVendas 
                    ? Colors.grey.shade200 
                    : Colors.grey.shade50,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: adaptive.isMobile ? 16 : 20,
                  vertical: adaptive.isMobile ? 16 : 18,
                ),
                helperText: _isPagamentoMultiplasVendas 
                    ? 'O valor é fixo quando há múltiplas vendas' 
                    : null,
                helperMaxLines: 2,
              ),
              style: GoogleFonts.inter(
                fontSize: adaptive.isMobile ? 15 : 16,
                color: _isPagamentoMultiplasVendas 
                    ? AppTheme.textSecondary 
                    : AppTheme.textPrimary,
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
            
            const SizedBox(height: 16),
            
            // Métodos de pagamento
            if (_paymentMethods.isNotEmpty) ...[
              Text(
                'Forma de Pagamento',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              // Métodos de pagamento com scroll horizontal para não ultrapassar a tela
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _paymentMethods.length,
                  itemBuilder: (context, index) {
                    final method = _paymentMethods[index];
                    final isSelected = _selectedMethod == method;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(method.icon, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              method.label,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedMethod = method;
                          });
                        },
                        selectedColor: AppTheme.primaryColor,
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: GoogleFonts.inter(
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            const SizedBox(height: 12),
            
            // ✅ Usa widget reutilizável (provider já passado como parâmetro)
            _buildActionButton(
              onPressed: _processarPagamento,
              text: 'Pagar',
              backgroundColor: AppTheme.successColor,
              isProcessing: paymentFlowProvider.isProcessing,
              adaptive: adaptive,
            ),
          ],
        ],
      ),
    );
  }
  
  /// ✅ Widget reutilizável para botões de ação com loading
  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String text,
    required Color backgroundColor,
    IconData? icon,
    required bool isProcessing,
    required AdaptiveLayoutProvider adaptive,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isProcessing ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            vertical: adaptive.isMobile ? 14 : 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isProcessing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : icon != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        text,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : Text(
                    text,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
      ),
    );
  }
  
  /// 🆕 Retorna texto do botão baseado no estado atual
  String _getButtonTextForState(PaymentFlowState state) {
    switch (state) {
      case PaymentFlowState.registeringPayment:
        return 'Registrando Pagamento...';
      case PaymentFlowState.concludingSale:
        return 'Concluindo Venda...';
      case PaymentFlowState.creatingInvoice:
        return 'Criando Nota Fiscal...';
      case PaymentFlowState.sendingToSefaz:
        return 'Enviando para SEFAZ...';
      case PaymentFlowState.printingInvoice:
        return 'Imprimindo Nota...';
      case PaymentFlowState.completed:
        return 'Concluído!';
      default:
        return 'Concluir Venda';
    }
  }
  
  /// 🆕 Retorna ícone baseado no estado atual
  IconData? _getIconForState(PaymentFlowState state) {
    switch (state) {
      case PaymentFlowState.registeringPayment:
        return Icons.cloud_upload;
      case PaymentFlowState.concludingSale:
        return Icons.hourglass_empty;
      case PaymentFlowState.creatingInvoice:
        return Icons.receipt_long;
      case PaymentFlowState.sendingToSefaz:
        return Icons.cloud_upload;
      case PaymentFlowState.printingInvoice:
        return Icons.print;
      case PaymentFlowState.completed:
        return Icons.check_circle;
      default:
        return Icons.check_circle;
    }
  }
  
}
