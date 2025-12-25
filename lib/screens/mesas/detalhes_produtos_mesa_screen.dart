import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../presentation/providers/services_provider.dart';
import '../../data/models/core/pedido_com_itens_pdv_dto.dart';
import '../../data/models/core/pedidos_com_venda_comandas_dto.dart';
import '../../data/models/local/pedido_local.dart';
import '../../data/models/local/sync_status_pedido.dart';
import '../../data/models/core/produto_agrupado.dart';
import '../../data/models/modules/restaurante/configuracao_restaurante_dto.dart';
import '../../data/repositories/pedido_local_repository.dart';
import '../../data/services/core/pedido_service.dart';
import '../pedidos/restaurante/novo_pedido_restaurante_screen.dart';
import '../pedidos/restaurante/dialogs/selecionar_mesa_comanda_dialog.dart';
import '../../data/models/core/vendas/venda_dto.dart';
import '../../data/models/core/vendas/pagamento_venda_dto.dart';
import '../../data/services/modules/restaurante/mesa_service.dart';
import '../../data/services/modules/restaurante/comanda_service.dart';
import '../../data/services/core/venda_service.dart';
import '../../core/printing/print_service.dart';
import '../../core/printing/print_data.dart';
import '../../core/printing/print_config.dart';
import '../pagamento/pagamento_restaurante_screen.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/app_dialog.dart';
import '../../data/models/modules/restaurante/comanda_list_item.dart';
import 'package:intl/intl.dart';
// Novos imports para modelos e widgets extraídos
import '../../models/mesas/entidade_produtos.dart' show TipoEntidade, MesaComandaInfo;
import '../../models/mesas/comanda_com_produtos.dart';
import '../../models/mesas/tab_data.dart';
import '../../widgets/mesas/tabs_scrollable_widget.dart';
import '../../widgets/mesas/produto_card_widget.dart';
import '../../widgets/mesas/total_item_widget.dart';
import '../../widgets/mesas/historico_pagamentos_widget.dart';
import '../../widgets/mesas/enhanced_app_bar_widget.dart';
import '../../widgets/mesas/compact_header_widget.dart';
import '../../widgets/elevated_toolbar_container.dart';
import '../../widgets/mesas/comanda_card_widget.dart';
import '../../widgets/mesas/botoes_acao_widget.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/status_utils.dart';
import '../../core/events/app_event_bus.dart';
import '../../presentation/providers/mesa_detalhes_provider.dart';
import '../../widgets/h4nd_loading.dart';

/// Resultado do cálculo de pagamentos
class _PagamentosCalculados {
  final List<PagamentoVendaDto> pagamentos;
  final double valorPago;

  _PagamentosCalculados({
    required this.pagamentos,
    required this.valorPago,
  });
}

/// Tela de detalhes de produtos agrupados (mesa ou comanda)
class DetalhesProdutosMesaScreen extends StatefulWidget {
  final MesaComandaInfo entidade;

  const DetalhesProdutosMesaScreen({
    super.key,
    required this.entidade,
  });

  @override
  State<DetalhesProdutosMesaScreen> createState() => _DetalhesProdutosMesaScreenState();
}

class _DetalhesProdutosMesaScreenState extends State<DetalhesProdutosMesaScreen> {
  late MesaDetalhesProvider _provider;
  final _pedidoRepo = PedidoLocalRepository();
  bool _isAbrindoNovoPedido = false; // Proteção contra múltiplos cliques

  ServicesProvider get _servicesProvider {
    return Provider.of<ServicesProvider>(context, listen: false);
  }

  ConfiguracaoRestauranteDto? get _configuracaoRestaurante {
    return _servicesProvider.configuracaoRestaurante;
  }

  @override
  void initState() {
    super.initState();
    _pedidoRepo.getAll(); // Garante que a box está aberta
    
    // Cria o provider imediatamente
    // A configuração já foi carregada na inicialização do sistema (persistida localmente)
    _provider = MesaDetalhesProvider(
      entidade: widget.entidade,
      pedidoService: _servicesProvider.pedidoService,
      mesaService: _servicesProvider.mesaService,
      comandaService: _servicesProvider.comandaService,
      vendaService: _servicesProvider.vendaService,
      configuracaoRestaurante: _configuracaoRestaurante,
      pedidoRepo: _pedidoRepo,
    );
    
    // Carrega produtos quando o widget é criado
    // SEMPRE recarrega tudo do servidor (refresh=true garante recarga completa)
    _provider.loadProdutos(refresh: true);
    _provider.loadVendaAtual();
    // Comandas serão carregadas automaticamente dentro de loadProdutos() quando controle é por comanda
    
    // O provider já escuta eventos do AppEventBus, não precisa de listener adicional
  }
  
  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  // Métodos _processarComandasDoRetorno, _loadComandasDaMesa, _loadVendaAtual, 
  // _loadProdutos, _processarItensPedidoServidorCompleto, _processarItensPedidoLocal
  // e _getPedidosLocais foram migrados para o provider.
  // Use os métodos do provider em vez disso.

  Color _getStatusColor(String status) {
    return StatusUtils.getStatusColor(status, widget.entidade.tipo);
  }

  bool _podeCriarPedido() {
    // Validação apenas de status (não bloqueia por configuração de controle)
    // A configuração de controle apenas define o fluxo de seleção, não bloqueia criação de pedido
    // O bloqueio é apenas no pagamento (quando controle é por comanda, não pode pagar pela mesa)
    
    // Usa status visual (considera pedidos locais sincronizando)
    final statusVisual = _provider.statusVisual.toLowerCase();
    
    if (widget.entidade.tipo == TipoEntidade.mesa) {
      // Mesa: pode criar pedido se estiver Livre (primeiro pedido) ou Ocupada (adicionar mais pedidos)
      // Não pode criar se estiver em Manutenção, Suspensa ou AguardandoPagamento sem venda
      if (statusVisual == 'manutencao' || statusVisual == 'suspensa') {
        return false;
      }
      // Se está Livre ou Ocupada, pode criar pedido
      // Se está AguardandoPagamento, só pode criar se não tiver venda (caso raro, mas permite)
      return statusVisual == 'livre' || 
             statusVisual == 'ocupada' || 
             statusVisual == 'reservada' ||
             (statusVisual == 'aguardando pagamento' && _provider.vendaAtual == null);
    } else {
      // Comanda: pode criar pedido se estiver "Em Uso" (tem sessão ativa)
      // OU se estiver Livre (primeiro pedido cria a sessão)
      // Se está sincronizando, considera como "em uso"
      if (_provider.estaSincronizando || _provider.pedidosPendentes > 0) {
        return true; // Se tem pedidos locais, pode criar mais pedidos
      }
      return statusVisual == 'em uso' || statusVisual == 'livre';
    }
  }

  double _calcularTotal() {
    return _provider.produtosAgrupados.fold(0.0, (sum, produto) => sum + produto.precoTotal);
  }

  // Método _buildEnhancedAppBar foi extraído para widget separado
  // Use EnhancedAppBarWidget em vez disso

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) {
      return const Scaffold(
        body: Center(child: H4ndLoading(size: 60)),
      );
    }

    // Usa Consumer para escutar mudanças do provider
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // Barra de ferramentas com informações da mesa/comanda
          _buildBarraFerramentas(adaptive),
          // Conteúdo das abas ou lista de produtos (scrollável)
          Expanded(
            child: _buildConteudoAbas(adaptive),
          ),

          // Totais e botões de ação (fixos na parte inferior)
              Builder(
                builder: (context) {
    final produtos = _getProdutosParaAcao();
    final total = produtos.fold(0.0, (sum, produto) => sum + produto.precoTotal);
                  final pagamentosCalculados = _calcularPagamentos();
                  final saldoRestante = total - pagamentosCalculados.valorPago;
                  final saldoZero = saldoRestante <= 0.01;

                  return BotoesAcaoWidget(
                    adaptive: adaptive,
                    podeCriarPedido: _podeCriarPedido(),
                    deveMostrarBotoesAcao: _deveMostrarBotoesAcao(),
                    produtos: produtos,
                    total: total,
                    valorPago: pagamentosCalculados.valorPago,
                    pagamentos: pagamentosCalculados.pagamentos,
                    historicoExpandido: _provider.historicoPagamentosExpandido,
                    onToggleHistorico: () => _provider.toggleHistoricoPagamentos(),
                    onNovoPedido: () async {
                        // Proteção contra múltiplos cliques
                        if (_isAbrindoNovoPedido) {
                          debugPrint('⚠️ [DetalhesProdutosMesaScreen] Já está abrindo novo pedido, ignorando clique');
                          return;
                        }
                        
                        setState(() {
                          _isAbrindoNovoPedido = true;
                        });
                        
                        try {
                          // Lógica baseada no tipo de entidade
                          if (widget.entidade.tipo == TipoEntidade.mesa) {
                            // Tela de Mesa: sempre abre diálogo com mesa pré-selecionada
                            // Se estiver em uma aba de comanda específica, pré-seleciona também a comanda
                            String? comandaIdPreSelecionada;
                            
                            // Se a aba selecionada é uma comanda (não é "Mesa"), pré-seleciona ela
                            if (_provider.abaSelecionada != null && 
                                _provider.abaSelecionada != MesaDetalhesProvider.semComandaId) {
                              comandaIdPreSelecionada = _provider.abaSelecionada;
                            }
                            
                            final resultado = await SelecionarMesaComandaDialog.show(
                              context,
                              mesaIdPreSelecionada: widget.entidade.id,
                              comandaIdPreSelecionada: comandaIdPreSelecionada,
                              permiteVendaAvulsa: true, // Permite continuar sem comanda
                            );
                            
                            // Se cancelou, não faz nada. Se confirmou (com ou sem comanda), continua
                            if (resultado != null && mounted) {
                              final mesaIdFinal = resultado.mesa?.id ?? widget.entidade.id;
                              final comandaIdFinal = resultado.comanda?.id;
                              
                              debugPrint('📋 [DetalhesProdutosMesaScreen] Abrindo NovoPedidoRestauranteScreen:');
                              debugPrint('  - MesaId: $mesaIdFinal (resultado.mesa?.id: ${resultado.mesa?.id}, widget.entidade.id: ${widget.entidade.id})');
                              debugPrint('  - ComandaId: $comandaIdFinal');
                              
                              await NovoPedidoRestauranteScreen.show(
                                context,
                                mesaId: mesaIdFinal,
                                comandaId: comandaIdFinal, // Opcional
                              );
                              
                              if (mounted) {
                                _provider.loadProdutos(refresh: true);
                                _provider.loadVendaAtual();
                              }
                            }
                          } else {
                            // Tela de Comanda: sempre mostra modal (tudo opcional)
                            final resultado = await SelecionarMesaComandaDialog.show(
                              context,
                              comandaIdPreSelecionada: widget.entidade.id,
                              permiteVendaAvulsa: true, // Permite continuar sem seleção
                            );
                            
                            // Se cancelou, não faz nada. Se confirmou (com ou sem seleção), continua
                            if (resultado != null && mounted) {
                              final comandaIdFinal = resultado.comanda?.id ?? widget.entidade.id;
                              await NovoPedidoRestauranteScreen.show(
                                context,
                                mesaId: resultado.mesa?.id,
                                comandaId: comandaIdFinal.isNotEmpty ? comandaIdFinal : null,
                              );
                              
                              if (mounted) {
                                _provider.loadProdutos(refresh: true);
                                _provider.loadVendaAtual();
                              }
                            }
                          }
                        } finally {
                          // Sempre libera o flag, mesmo se houver erro
                          if (mounted) {
                            setState(() {
                              _isAbrindoNovoPedido = false;
                            });
                          }
                        }
                      },
                    onImprimirParcial: _imprimirParcial,
                    onPagar: _abrirTelaPagamento,
                    onFinalizar: _finalizarVenda,
                    saldoZero: saldoZero,
                  );
                },
                      ),
            ],
          ),
        );
      },
    );
  }

  /// Barra de ferramentas com informações da mesa/comanda
  Widget _buildBarraFerramentas(AdaptiveLayoutProvider adaptive) {
    final statusExibido = _provider.statusVisual;
    final statusColor = StatusUtils.getStatusColor(statusExibido, widget.entidade.tipo);
    
    return ElevatedToolbarContainer(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.isMobile ? 12 : 16,
        vertical: adaptive.isMobile ? 8 : 10,
      ),
      child: Row(
        children: [
          // Botão voltar (apenas mobile) - design único e padrão
          if (adaptive.isMobile) ...[
            _buildBackButton(adaptive),
            const SizedBox(width: 8),
          ],
          
          // Badge compacto com identificação da mesa/comanda
          _buildMesaBadge(adaptive, statusExibido, statusColor),
          
          const Spacer(),
          
          // Botão de atualizar (padrão igual área de mesas)
          _buildRefreshButton(adaptive),
        ],
      ),
    );
  }
  
  /// Botão voltar padrão único do sistema (apenas mobile)
  Widget _buildBackButton(AdaptiveLayoutProvider adaptive) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withOpacity(0.15),
                AppTheme.primaryColor.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
  
  /// Badge compacto com identificação da mesa/comanda
  Widget _buildMesaBadge(
    AdaptiveLayoutProvider adaptive,
    String statusExibido,
    Color statusColor,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.isMobile ? 10 : 12,
        vertical: adaptive.isMobile ? 10 : 12, // Mesmo padding dos botões
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 10 : 12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ícone da mesa/comanda
          Icon(
            widget.entidade.tipo == TipoEntidade.mesa 
                ? Icons.table_restaurant_rounded
                : Icons.receipt_long_rounded,
            size: 16,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          // Nome (sem "Mesa" ou "Comanda")
          Text(
            widget.entidade.numero,
            style: GoogleFonts.inter(
              fontSize: adaptive.isMobile ? 13 : 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          // Badge de status compacto
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: statusColor.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Text(
              statusExibido,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
          // Indicadores de status compactos
          if (_provider.estaSincronizando) ...[
            const SizedBox(width: 6),
            const H4ndLoadingCompact(size: 10),
          ],
          if (_provider.temErros) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.error_outline,
              size: 12,
              color: AppTheme.errorColor,
            ),
          ],
          if (_provider.pedidosPendentes > 0 && !_provider.estaSincronizando && !_provider.temErros) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_provider.pedidosPendentes}',
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warningColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  /// Botão de atualizar (padrão igual área de mesas)
  Widget _buildRefreshButton(AdaptiveLayoutProvider adaptive) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _provider.loadProdutos(refresh: true),
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 10 : 12),
        child: Tooltip(
          message: 'Atualizar',
          child: Container(
            padding: EdgeInsets.all(adaptive.isMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(adaptive.isMobile ? 10 : 12),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              Icons.refresh_rounded,
              color: AppTheme.textPrimary,
              size: adaptive.isMobile ? 20 : 22,
            ),
          ),
        ),
      ),
    );
  }

  // Método _buildCompactHeader foi extraído para widget separado
  // Use CompactHeaderWidget em vez disso
  
  // Método _buildHistoricoPagamentos foi extraído para widget separado
  // Use HistoricoPagamentosWidget em vez disso

  // Métodos _buildTotalItem e _buildProdutoCard foram extraídos para widgets separados
  // Use TotalItemWidget e ProdutoCardWidget em vez disso

  // Método _buildBotoesAcao foi extraído para widget separado
  // Use BotoesAcaoWidget em vez disso

  /// Verifica se deve mostrar os botões de ação (imprimir e pagar)
  bool _deveMostrarBotoesAcao() {
    // Se não é mesa com controle por comanda, usa lógica normal
    if (widget.entidade.tipo != TipoEntidade.mesa ||
        _configuracaoRestaurante == null ||
        !_configuracaoRestaurante!.controlePorComanda) {
      return _provider.vendaAtual != null && _provider.produtosAgrupados.isNotEmpty;
    }

    // Se controle é por comanda:
    // - Sempre mostra botões se houver aba selecionada e produtos
    if (_provider.abaSelecionada == null) {
      return false; // Sem aba selecionada, não mostra botões
    }

    final produtos = _provider.getProdutosParaAcao();
    // Permite mostrar botões se tiver produtos, mesmo sem venda (pode criar venda no pagamento)
    return produtos.isNotEmpty;
  }

  /// Retorna os produtos para ação (geral ou da comanda selecionada)
  List<ProdutoAgrupado> _getProdutosParaAcao() {
    return _provider.getProdutosParaAcao();
  }

  /// Retorna a venda para ação (geral ou da comanda selecionada)
  VendaDto? _getVendaParaAcao() {
    return _provider.getVendaParaAcao();
  }

  /// Calcula pagamentos e valor pago baseado no contexto atual (comanda selecionada ou visão geral)
  _PagamentosCalculados _calcularPagamentos() {
    List<PagamentoVendaDto> pagamentos = [];
    double valorPago = 0.0;
    
    // Verifica se a aba selecionada é "Sem Comanda"
    final isAbaSemComanda = _provider.abaSelecionada == MesaDetalhesProvider.semComandaId;
                            
    if (_provider.abaSelecionada != null && !isAbaSemComanda) {
      // Se há aba selecionada (comanda específica), busca pagamentos da comanda
      final comanda = _provider.comandasDaMesa.firstWhere(
        (c) => c.comanda.id == _provider.abaSelecionada,
        orElse: () => _provider.comandasDaMesa.isNotEmpty 
            ? _provider.comandasDaMesa.first 
            : throw StateError('Nenhuma comanda encontrada'),
      );
      if (comanda.comanda.pagamentos.isNotEmpty) {
        pagamentos = comanda.comanda.pagamentos;
      } else if (comanda.venda?.pagamentos.isNotEmpty == true) {
        pagamentos = comanda.venda!.pagamentos;
      }
      // Calcula valor pago da comanda específica
      valorPago = pagamentos
          .where((p) => p.status == 2 && !p.isCancelado) // StatusPagamento.Confirmado = 2
          .fold(0.0, (sum, p) => sum + p.valor);
    } else if (isAbaSemComanda) {
      // Se está na aba "Sem Comanda", busca pagamentos da venda sem comanda
      final venda = _provider.getVendaParaAcao();
      if (venda?.pagamentos.isNotEmpty == true) {
        pagamentos = venda!.pagamentos;
        valorPago = venda.totalPago;
      }
    } else if (widget.entidade.tipo == TipoEntidade.comanda) {
      // Se entidade é comanda diretamente, busca da venda
      final venda = _provider.getVendaParaAcao();
      if (venda?.pagamentos.isNotEmpty == true) {
        pagamentos = venda!.pagamentos;
        valorPago = venda.totalPago;
      }
    }
    // Não há mais "visão geral" - sempre trabalha com aba selecionada
    
    return _PagamentosCalculados(
      pagamentos: pagamentos,
      valorPago: valorPago,
    );
  }

  /// Busca venda aberta quando necessário e atualiza o estado apropriado
  /// Retorna a venda encontrada ou null se não encontrada
  Future<VendaDto?> _buscarVendaAberta() async {
    return await _provider.buscarVendaAberta();
  }

  Future<void> _imprimirParcial() async {
    if (_provider.vendaAtual == null) {
      AppToast.showError(context, 'Nenhuma venda encontrada');
      return;
    }

    try {
      final printService = await PrintService.getInstance();
      
      // Cria PrintData para parcial de venda
      final printData = PrintData(
        header: PrintHeader(
          title: 'PARCIAL DE VENDA',
          subtitle: widget.entidade.tipo == TipoEntidade.mesa 
              ? 'Mesa ${widget.entidade.numero}'
              : 'Comanda ${widget.entidade.numero}',
          dateTime: DateTime.now(),
        ),
        entityInfo: PrintEntityInfo(
          mesaNome: widget.entidade.tipo == TipoEntidade.mesa ? widget.entidade.numero : null,
          comandaCodigo: widget.entidade.tipo == TipoEntidade.comanda ? widget.entidade.numero : null,
          clienteNome: _provider.vendaAtual!.clienteNome,
        ),
        items: _provider.produtosAgrupados.map((produto) => PrintItem(
          produtoNome: produto.produtoNome,
          produtoVariacaoNome: produto.produtoVariacaoNome,
          quantidade: produto.quantidadeTotal.toDouble(),
          precoUnitario: produto.precoUnitario,
          valorTotal: produto.precoTotal,
          componentesRemovidos: [],
        )).toList(),
        totals: PrintTotals(
          subtotal: _provider.vendaAtual!.subtotal,
          descontoTotal: _provider.vendaAtual!.descontoTotal,
          acrescimoTotal: _provider.vendaAtual!.acrescimoTotal,
          impostosTotal: _provider.vendaAtual!.impostosTotal,
          valorTotal: _provider.vendaAtual!.valorTotal,
        ),
        footer: PrintFooter(
          message: 'Total pago: R\$ ${_provider.vendaAtual!.totalPago.toStringAsFixed(2)}\n'
                    'Saldo restante: R\$ ${_provider.vendaAtual!.saldoRestante.toStringAsFixed(2)}',
        ),
      );

      final result = await printService.printDocument(
        documentType: DocumentType.parcialVenda,
        data: printData,
      );

      if (result.success) {
        AppToast.showSuccess(context, 'Parcial impresso com sucesso!');
      } else {
        AppToast.showError(context, result.errorMessage ?? 'Erro ao imprimir parcial');
      }
    } catch (e) {
      AppToast.showError(context, 'Erro ao imprimir parcial: $e');
    }
  }

  Future<void> _abrirTelaPagamento() async {
    var venda = _getVendaParaAcao();
    final produtos = _getProdutosParaAcao();

    // Se venda é null, tenta buscar venda aberta diretamente usando método auxiliar
    if (venda == null) {
      debugPrint('⚠️ Venda não encontrada localmente, buscando venda aberta diretamente...');
      venda = await _buscarVendaAberta();
    }

    if (venda == null) {
      AppToast.showError(context, 'Nenhuma venda encontrada');
      return;
    }

    if (produtos.isEmpty) {
      AppToast.showError(context, 'Nenhum produto disponível para pagamento');
      return;
    }

    // Validação: sempre precisa ter uma aba selecionada
    if (_provider.abaSelecionada == null) {
      AppToast.showError(
        context, 
        'Selecione uma aba para realizar o pagamento.'
      );
      return;
    }

    final result = await PagamentoRestauranteScreen.show(
      context,
      venda: venda,
      produtosAgrupados: produtos,
      // Callback removido - o provider já reage ao evento pagamentoProcessado
      // e atualiza localmente sem ir no servidor
      onPaymentSuccess: () {
        // Não precisa fazer nada - provider já reage ao evento
      },
    );

    // Callback após pagamento removido - o provider já reage aos eventos
    // (pagamentoProcessado e vendaFinalizada) e atualiza localmente
    // Se a venda foi finalizada, marcarVendaFinalizada() já foi chamado
    // e loadProdutos() não vai no servidor mesmo se for chamado
    if (result == true) {
      // Não precisa recarregar - provider já reage aos eventos
      // Se venda foi finalizada, já foi marcado como finalizada acima
    }
  }

  /// Finaliza a venda (conclui e emite nota fiscal se necessário)
  Future<void> _finalizarVenda() async {
    var venda = _getVendaParaAcao();
    final produtos = _getProdutosParaAcao();

    // Se venda é null, tenta buscar venda aberta diretamente usando método auxiliar
    if (venda == null) {
      debugPrint('⚠️ Venda não encontrada localmente, buscando venda aberta diretamente...');
      venda = await _buscarVendaAberta();
    }

    if (venda == null) {
      AppToast.showError(context, 'Nenhuma venda encontrada');
      return;
    }

    // Validação: se controle é por comanda e está na visão geral, bloqueia
    if (widget.entidade.tipo == TipoEntidade.mesa && 
        _configuracaoRestaurante != null && 
        _configuracaoRestaurante!.controlePorComanda &&
        _provider.abaSelecionada == null) {
      AppToast.showError(
        context, 
        'Selecione uma comanda específica para finalizar a venda.'
      );
      return;
    }

    // Confirmação antes de finalizar usando AppDialog padrão
    final confirmar = await AppDialog.showConfirm(
      context: context,
      title: 'Finalizar Venda',
      message: 'Deseja finalizar esta venda? A nota fiscal será emitida automaticamente se necessário.',
      confirmText: 'Finalizar',
      cancelText: 'Cancelar',
      icon: Icons.check_circle_outline,
      iconColor: AppTheme.primaryColor,
      confirmColor: AppTheme.primaryColor,
    );

    if (confirmar != true) return;

    // Mostra loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: H4ndLoading(size: 60)),
    );

    try {
      final response = await _servicesProvider.vendaService.concluirVenda(venda!.id);
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Fecha loading

      if (response.success && response.data != null) {
        AppToast.showSuccess(context, response.message ?? 'Venda finalizada com sucesso!');
        
        // Determina comandaId da venda sendo finalizada (para finalização parcial)
        // Sempre usa o comandaId da venda, se houver
        final comandaIdParaFinalizacao = venda!.comandaId;
        
        // Determina mesaId para os eventos
        final mesaIdParaEvento = widget.entidade.tipo == TipoEntidade.mesa 
            ? widget.entidade.id 
            : venda.mesaId;
        
        debugPrint('📋 [DetalhesProdutosMesaScreen] Finalizando venda:');
        debugPrint('   vendaId: ${venda.id}');
        debugPrint('   comandaId: $comandaIdParaFinalizacao');
        debugPrint('   mesaId: $mesaIdParaEvento');
        debugPrint('   entidade.tipo: ${widget.entidade.tipo}');
        debugPrint('   entidade.id: ${widget.entidade.id}');
        
        // Dispara evento de venda finalizada primeiro (para outros providers/listeners)
        if (mesaIdParaEvento != null) {
          debugPrint('📢 [DetalhesProdutosMesaScreen] Disparando evento vendaFinalizada');
          AppEventBus.instance.dispararVendaFinalizada(
            vendaId: venda.id,
            mesaId: mesaIdParaEvento,
            comandaId: comandaIdParaFinalizacao,
          );
        }
        
        // Marca venda como finalizada e recarrega dados da mesa completamente
        // O método marcarVendaFinalizada() recarrega do servidor e verifica se ainda há vendas abertas
        // Só libera a mesa se não houver nenhuma venda aberta após recarregar
        await _provider.marcarVendaFinalizada(
          comandaId: comandaIdParaFinalizacao,
          mesaId: mesaIdParaEvento,
        );
      } else {
        AppToast.showError(context, response.message ?? 'Erro ao finalizar venda');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Fecha loading
      AppToast.showError(context, 'Erro ao finalizar venda: ${e.toString()}');
    }
  }

  /// Conteúdo das abas ou lista de produtos normal
  Widget _buildConteudoAbas(AdaptiveLayoutProvider adaptive) {
    // Se não é mesa, mostra lista normal
    if (widget.entidade.tipo != TipoEntidade.mesa) {
      return Container(
        color: Colors.white,
        child: _buildListaProdutos(adaptive),
      );
    }

    // IMPORTANTE: Verifica se está carregando ANTES de verificar se tem dados
    // Não deve mostrar "nenhum pedido" se ainda está carregando
    if (_provider.isLoading || _provider.carregandoProdutos) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: H4ndLoading(size: 60),
        ),
      );
    }

    // Para mesa: SEMPRE verifica se há comandas OU produtos sem comanda
    // Se houver comandas ou produtos sem comanda, mostra abas; se não houver, mostra lista vazia
    final temComandas = _provider.comandasDaMesa.isNotEmpty;
    final temProdutosSemComanda = _provider.temProdutosSemComanda;
    
    if (!temComandas && !temProdutosSemComanda) {
      // Sem comandas e sem produtos sem comanda: mostra lista vazia
      // Só mostra esta mensagem se JÁ terminou de carregar (verificado acima)
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhum pedido encontrado',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Com comandas ou produtos sem comanda: mostra seletor de visualização integrado (abas)
    return Container(
      color: Colors.white,
      child: Column(
      children: [
        // Seletor de visualização (tabs integradas)
        _buildSeletorVisualizacao(adaptive),
        // Conteúdo da visualização selecionada (sempre mostra produtos da aba selecionada)
        Expanded(
            child: _buildListaProdutosPorComanda(adaptive, _provider.abaSelecionada),
        ),
      ],
      ),
    );
  }

  /// Seletor de visualização integrado (substitui tabs do cabeçalho)
  Widget _buildSeletorVisualizacao(AdaptiveLayoutProvider adaptive) {
    final tabs = <TabData>[];
    
    // SEMPRE adiciona aba "Mesa" primeiro (venda integral - tudo)
    // Só mostra se houver produtos (com comanda ou sem comanda)
    final temProdutos = _provider.comandasDaMesa.isNotEmpty || _provider.temProdutosSemComanda;
    if (temProdutos) {
      tabs.add(
        TabData(
          comandaId: null, // null = "Mesa" (venda integral)
          label: 'Mesa',
          icon: Icons.table_restaurant,
        ),
      );
    }
    
    // Adiciona aba "Sem Comanda" apenas se houver produtos SEM comanda E COM comanda (ambos)
    if (_provider.deveMostrarAbaSemComanda) {
      tabs.add(
        TabData(
          comandaId: MesaDetalhesProvider.semComandaId,
          label: 'Sem Comanda',
          icon: Icons.table_restaurant_outlined,
        ),
      );
    }
    
    // Adiciona abas das comandas
    tabs.addAll(
      _provider.comandasDaMesa.map((comandaData) {
        final comanda = comandaData.comanda;
        return TabData(
          comandaId: comanda.id,
          label: 'Comanda ${comanda.numero}',
          icon: Icons.receipt_long,
        );
      }),
    );
    
    return TabsScrollableWidget(
      adaptive: adaptive,
      tabs: tabs,
      selectedTab: _provider.abaSelecionada,
      onTabSelected: (comandaId) {
        _provider.setAbaSelecionada(comandaId);
      },
      buildTab: (tab) => _buildOpcaoVisualizacao(
        adaptive,
        comandaId: tab.comandaId,
        label: tab.label,
        icon: tab.icon,
      ),
    );
  }

  Widget _buildOpcaoVisualizacao(
    AdaptiveLayoutProvider adaptive, {
    required String? comandaId,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _provider.abaSelecionada == comandaId;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.isMobile ? 12 : 16,
        vertical: adaptive.isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 10 : 12),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: adaptive.isMobile ? 16 : 18,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
          ),
          SizedBox(width: adaptive.isMobile ? 6 : 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: adaptive.isMobile ? 13 : 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Widget de erro bonito e amigável
  Widget _buildErrorWidget(AdaptiveLayoutProvider adaptive) {
    final isConnectionError = _isConnectionError(_provider.errorMessage ?? '');
    
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(adaptive.isMobile ? 24 : 32),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícone grande e bonito
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isConnectionError ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                  size: adaptive.isMobile ? 72 : 80,
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(height: 32),
              
              // Título
              Text(
                isConnectionError 
                    ? 'Erro de Comunicação'
                    : 'Ops! Algo deu errado',
                style: GoogleFonts.inter(
                  fontSize: adaptive.isMobile ? 24 : 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Mensagem amigável
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: adaptive.isMobile ? 16 : 32,
                ),
                child: Text(
                  isConnectionError
                      ? 'Não foi possível conectar ao servidor. Verifique sua conexão com a internet e tente novamente.'
                      : 'Não foi possível carregar os produtos. Por favor, tente novamente.',
                  style: GoogleFonts.inter(
                    fontSize: adaptive.isMobile ? 15 : 16,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              
              // Botão de tentar novamente estilizado
              ElevatedButton.icon(
                onPressed: _provider.isLoading 
                    ? null 
                    : () => _provider.loadProdutos(refresh: true),
                icon: _provider.isLoading
                    ? const H4ndLoadingCompact(
                        size: 20,
                        blueColor: Colors.white,
                        greenColor: Colors.white70,
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(
                  _provider.isLoading ? 'Carregando...' : 'Tentar novamente',
                  style: GoogleFonts.inter(
                    fontSize: adaptive.isMobile ? 15 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: adaptive.isMobile ? 32 : 40,
                    vertical: adaptive.isMobile ? 16 : 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Verifica se o erro é relacionado a conexão/rede
  bool _isConnectionError(String errorMessage) {
    final lowerMessage = errorMessage.toLowerCase();
    return lowerMessage.contains('connection') ||
        lowerMessage.contains('conexão') ||
        lowerMessage.contains('network') ||
        lowerMessage.contains('rede') ||
        lowerMessage.contains('timeout') ||
        lowerMessage.contains('socket') ||
        lowerMessage.contains('failed host lookup') ||
        lowerMessage.contains('no internet') ||
        lowerMessage.contains('sem internet');
  }

  /// Lista de produtos (visão geral)
  Widget _buildListaProdutos(AdaptiveLayoutProvider adaptive) {
    return _provider.errorMessage != null
        ? _buildErrorWidget(adaptive)
        : (_provider.isLoading || _provider.carregandoProdutos)
            ? Container(
                color: Colors.white,
                child: const Center(child: H4ndLoading(size: 60)),
              )
            : _provider.produtosAgrupados.isEmpty
                ? Container(
                    color: Colors.white,
                    child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum produto encontrado',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    ),
                  )
                : Container(
                    color: Colors.white,
                    child: RefreshIndicator(
                      onRefresh: () => _provider.loadProdutos(refresh: true),
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        adaptive.isMobile ? 16 : 20,
                        8,
                        adaptive.isMobile ? 16 : 20,
                        8,
                      ),
                        itemCount: _provider.produtosAgrupados.length,
                      itemBuilder: (context, index) {
                          return ProdutoCardWidget(
                            produto: _provider.produtosAgrupados[index],
                            adaptive: adaptive,
                          );
                      },
                      ),
                    ),
                  );
  }

  /// Lista de produtos filtrada por comanda específica
  Widget _buildListaProdutosPorComanda(AdaptiveLayoutProvider adaptive, String? comandaId) {
    // IMPORTANTE: Verifica se está carregando ANTES de verificar se tem produtos
    // Não deve mostrar "nenhum produto" se ainda está carregando
    if (_provider.isLoading || _provider.carregandoProdutos || _provider.carregandoComandas) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: H4ndLoading(size: 60),
        ),
      );
    }
    
    // Busca os produtos da aba selecionada
    // null = "Mesa" (venda integral - todos os produtos)
    // comandaId = produtos da comanda específica ou "_SEM_COMANDA"
    final produtos = _provider.getProdutosParaAcao();
    
    if (produtos.isEmpty) {
      // Só mostra esta mensagem se JÁ terminou de carregar (verificado acima)
      return Container(
        color: Colors.white,
        child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              comandaId == null 
                  ? 'Nenhum produto encontrado na mesa'
                  : comandaId == MesaDetalhesProvider.semComandaId
                      ? 'Nenhum produto encontrado sem comanda'
                      : 'Nenhum produto encontrado nesta comanda',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _provider.loadProdutos(refresh: true),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          adaptive.isMobile ? 16 : 20,
          8,
          adaptive.isMobile ? 16 : 20,
          8,
        ),
        itemCount: produtos.length,
        itemBuilder: (context, index) {
          return ProdutoCardWidget(
            produto: produtos[index],
            adaptive: adaptive,
          );
        },
      ),
    );
  }

  /// Lista de comandas da mesa
  Widget _buildListaComandas(AdaptiveLayoutProvider adaptive) {
    if (_provider.carregandoComandas) {
      return Container(
        color: Colors.white,
        child: const Center(child: H4ndLoading(size: 60)),
      );
    }

    if (_provider.comandasDaMesa.isEmpty) {
      return Container(
        color: Colors.white,
        child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma comanda encontrada nesta mesa',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
                onPressed: () => _provider.loadProdutos(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar'),
            ),
          ],
          ),
        ),
      );
    }

    // Lista de comandas
    return Container(
      color: Colors.white,
      child: RefreshIndicator(
        onRefresh: () => _provider.loadProdutos(refresh: true),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          adaptive.isMobile ? 16 : 20,
          0,
          adaptive.isMobile ? 16 : 20,
          8,
        ),
          itemCount: _provider.comandasDaMesa.length,
        itemBuilder: (context, index) {
            final comandaData = _provider.comandasDaMesa[index];
            return ComandaCardWidget(
              comandaData: comandaData,
              adaptive: adaptive,
              isExpanded: _provider.produtosPorComanda.containsKey(comandaData.comanda.id),
              onTap: () => _provider.setAbaSelecionada(comandaData.comanda.id),
              onPagarComanda: comandaData.venda != null && comandaData.produtos.isNotEmpty
                  ? () => _abrirPagamentoComanda(
                        comandaData.comanda,
                        comandaData.produtos,
                        comandaData.venda!,
                      )
                  : null,
                        );
                      },
                    ),
      ),
    );
  }

  // Método _buildComandaCard foi extraído para widget separado
  // Use ComandaCardWidget em vez disso

  /// Abre tela de pagamento para uma comanda específica
  Future<void> _abrirPagamentoComanda(
    ComandaListItemDto comanda,
    List<ProdutoAgrupado> produtos,
    VendaDto venda,
  ) async {
    final result = await PagamentoRestauranteScreen.show(
      context,
      venda: venda,
      produtosAgrupados: produtos,
      onPaymentSuccess: () {
        _provider.loadVendaAtual();
        _provider.loadProdutos(refresh: true);
        // Comandas são recarregadas automaticamente dentro de _loadProdutos() quando controle é por comanda
      },
    );

    if (result == true && mounted) {
      // Recarrega dados
      _provider.loadVendaAtual();
      _provider.loadProdutos(refresh: true);
      // Comandas são recarregadas automaticamente dentro de loadProdutos() quando controle é por comanda
    }
  }
}
