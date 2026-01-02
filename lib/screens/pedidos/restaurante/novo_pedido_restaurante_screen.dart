import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/adaptive_layout/adaptive_layout.dart';
import '../../../widgets/elevated_toolbar_container.dart';
import '../../../presentation/providers/pedido_provider.dart';
import '../../../presentation/providers/services_provider.dart';
import '../../../presentation/providers/venda_balcao_provider.dart';
import '../../../data/models/modules/restaurante/mesa_list_item.dart';
import '../../../data/models/modules/restaurante/comanda_list_item.dart';
import '../../../core/widgets/loading_helper.dart';
import '../../../core/widgets/error_helper.dart';
import '../../../data/models/core/tipo_venda.dart';
import '../../../core/events/app_event_bus.dart';
import 'package:flutter/foundation.dart';
import 'components/categoria_navigation_tree.dart';
import 'components/pedido_resumo_panel.dart';

/// Tela de criação de novo pedido para restaurante
class NovoPedidoRestauranteScreen extends StatefulWidget {
  final String? mesaId; // ID da mesa (opcional)
  final String? comandaId; // ID da comanda (opcional)
  final bool isModal; // Indica se deve ser exibido como modal
  final TipoVenda tipoVenda; // Tipo de venda (mesa, balcão, delivery, etc.)

  const NovoPedidoRestauranteScreen({
    super.key,
    this.mesaId,
    this.comandaId,
    this.isModal = false,
    this.tipoVenda = TipoVenda.controlada, // Padrão: venda controlada (mesa/comanda)
  });

  /// SEMPRE mostra como TELA CHEIA (mobile e desktop)
  static Future<bool?> show(
    BuildContext context, {
    String? mesaId,
    String? comandaId,
    TipoVenda tipoVenda = TipoVenda.controlada,
  }) async {
    // SEMPRE usa Navigator.push para tela cheia em TODAS as plataformas
    return await Navigator.of(context, rootNavigator: true).push<bool>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => AdaptiveLayout(
          child: NovoPedidoRestauranteScreen(
            mesaId: mesaId,
            comandaId: comandaId,
            isModal: false,
            tipoVenda: tipoVenda,
          ),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        opaque: true,
        fullscreenDialog: false,
      ),
    );
  }

  @override
  State<NovoPedidoRestauranteScreen> createState() => _NovoPedidoRestauranteScreenState();
}

class _NovoPedidoRestauranteScreenState extends State<NovoPedidoRestauranteScreen> {
  MesaListItemDto? _mesa;
  ComandaListItemDto? _comanda;
  final ValueNotifier<bool> _mostrarBuscaNotifier = ValueNotifier<bool>(false);


  /// Verifica se há venda pendente (apenas para tipos que requerem conexão)
  /// Retorna true se pode continuar, false se deve fechar a tela
  bool _verificarVendaPendente() {
    // Apenas tipos que requerem conexão podem ter venda pendente
    if (!widget.tipoVenda.requerConexao) return true;
    
    final vendaBalcaoProvider = Provider.of<VendaBalcaoProvider>(context, listen: false);
    if (vendaBalcaoProvider.temVendaPendente) {
      // Tem venda pendente → não permite criar novo pedido
      // Fecha esta tela e volta (tela específica vai abrir pagamento)
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return false;
    }
    return true;
  }

  /// Busca dados de mesa e/ou comanda se houver IDs
  Future<void> _buscarMesaOuComanda() async {
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    
    // Busca mesa se houver ID
    if (widget.mesaId != null && mounted) {
      final mesaResponse = await servicesProvider.mesaService.getMesaById(widget.mesaId!);
      if (mesaResponse.success && mesaResponse.data != null && mounted) {
        setState(() {
          _mesa = mesaResponse.data;
        });
      }
    }

    // Busca comanda se houver ID
    if (widget.comandaId != null && mounted) {
      final comandaResponse = await servicesProvider.comandaService.getComandaById(widget.comandaId!);
      if (comandaResponse.success && comandaResponse.data != null && mounted) {
        setState(() {
          _comanda = comandaResponse.data;
        });
      }
    }
  }

  /// Carrega configuração do restaurante se necessário
  Future<void> _carregarConfiguracao() async {
    if (!mounted) return;
    
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    if (!servicesProvider.configuracaoRestauranteCarregada) {
      await servicesProvider.carregarConfiguracaoRestaurante();
    }
  }

  /// Inicializa novo pedido no provider
  Future<bool> _iniciarPedido() async {
    if (!mounted) return false;
    
    final pedidoProvider = Provider.of<PedidoProvider>(context, listen: false);
    
    debugPrint('📋 [NovoPedidoRestauranteScreen] Chamando iniciarNovoPedido:');
    debugPrint('  - MesaId: ${widget.mesaId}');
    debugPrint('  - ComandaId: ${widget.comandaId}');

        final sucesso = await pedidoProvider.iniciarNovoPedido(
          mesaId: widget.mesaId,
          comandaId: widget.comandaId,
        );

    return sucesso;
  }

  @override
  void initState() {
    super.initState();
    // Inicializar pedido quando a tela é aberta
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      // Mostra loading enquanto inicializa
      LoadingHelper.show(context);
      
      try {
        // Verifica se há venda pendente (apenas para venda balcão)
        if (!_verificarVendaPendente()) {
          LoadingHelper.hide(context);
          return;
        }

        if (!mounted) {
          LoadingHelper.hide(context);
          return;
        }

        // Carrega configuração do restaurante se necessário
        await _carregarConfiguracao();
        
        if (!mounted) {
          LoadingHelper.hide(context);
          return;
        }

        // Busca dados de mesa/comanda se houver
        await _buscarMesaOuComanda();

        if (!mounted) {
          LoadingHelper.hide(context);
          return;
        }

        // Inicializa novo pedido no provider
        final sucesso = await _iniciarPedido();

        if (!mounted) {
          LoadingHelper.hide(context);
          return;
        }

        // Fecha o loading
        LoadingHelper.hide(context);

        // Se usuário cancelou a abertura de sessão, volta para tela anterior
        if (!sucesso && widget.mesaId != null && mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        // Fecha o loading em caso de erro
        LoadingHelper.hide(context);
        
        debugPrint('❌ Erro ao inicializar pedido: $e');
        ErrorHelper.show(context, 'Erro ao inicializar pedido: ${e.toString()}');
      }
    });
  }

  @override
  void dispose() {
    _mostrarBuscaNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    
    // Conteúdo comum
    Widget buildContent() {
      return Column(
        children: [
          // Conteúdo principal
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 1024;
                
                if (isMobile) {
                  // Layout mobile: painel como bottom sheet ou aba
                  return Stack(
                    children: [
                      CategoriaNavigationTree(
                        mostrarBuscaNotifier: _mostrarBuscaNotifier,
                        onProdutoSelected: (produto) {
                          debugPrint('Produto selecionado: ${produto.produtoNome}');
                        },
                      ),
                      // Botão flutuante para abrir resumo do pedido
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Consumer<PedidoProvider>(
                          builder: (context, pedidoProvider, child) {
                            if (pedidoProvider.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return FloatingActionButton.extended(
                              onPressed: () {
                                _mostrarResumoPedidoMobile(context);
                              },
                              backgroundColor: AppTheme.primaryColor,
                              icon: Stack(
                                children: [
                                  const Icon(Icons.shopping_cart, color: Colors.white),
                                  if (pedidoProvider.quantidadeTotal > 0)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Text(
                                          '${pedidoProvider.quantidadeTotal}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              label: Text(
                                'R\$ ${pedidoProvider.total.toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                } else {
                  // Layout desktop: divisão lado a lado
                  return Row(
                    children: [
                      // Área principal de navegação (70% da largura)
                      Expanded(
                        flex: 7,
                        child: CategoriaNavigationTree(
                          mostrarBuscaNotifier: _mostrarBuscaNotifier,
                          onProdutoSelected: (produto) {
                            debugPrint('Produto selecionado: ${produto.produtoNome}');
                          },
                        ),
                      ),
                      // Painel lateral com resumo do pedido (30% da largura, mínimo 350px)
                      Container(
                        width: 400,
                        constraints: const BoxConstraints(minWidth: 350, maxWidth: 500),
                        child: PedidoResumoPanel(
                          onFinalizarPedido: () {
                            _finalizarPedido(context);
                          },
                          onLimparPedido: () {
                            // O botão de limpar já está no header do painel
                          },
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      );
    }

    // Modal: usa Dialog
    if (widget.isModal && adaptive != null) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: adaptive.isDesktop ? 40 : 20,
          vertical: adaptive.isDesktop ? 20 : 10,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: adaptive.isDesktop ? 1400 : 1200,
            maxHeight: MediaQuery.of(context).size.height * 0.95,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // Header do modal com fundo azul
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2563EB), // Azul médio-escuro
                      const Color(0xFF1E40AF), // Azul escuro
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981), // Verde vibrante
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: adaptive.isMobile ? 20 : 24,
                        vertical: adaptive.isMobile ? 18 : 22,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Novo Pedido',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                if (_mesa != null || _comanda != null) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: _buildMesaComandaBadgesLegacy(), // Versão legada para modal
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(false),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Conteúdo com scroll
              Expanded(
                child: buildContent(),
              ),
            ],
          ),
        ),
      );
    }

    // Tela cheia: usa Scaffold (mobile)
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // Barra de ferramentas com título usando ElevatedToolbarContainer
          _buildBarraFerramentasComTitulo(adaptive),
          // Conteúdo principal
          Expanded(
            child: buildContent(),
          ),
        ],
      ),
    );
  }

  /// Barra de ferramentas com título usando ElevatedToolbarContainer
  Widget _buildBarraFerramentasComTitulo(AdaptiveLayoutProvider? adaptive) {
    if (adaptive == null) return const SizedBox.shrink();
    
    return ElevatedToolbarContainer(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.isMobile ? 12 : 16,
        vertical: adaptive.isMobile ? 8 : 10,
      ),
      child: Row(
        children: [
          // Botão voltar (apenas mobile) - padrão igual detalhes da mesa
          if (adaptive.isMobile) ...[
            _buildBackButton(adaptive),
            const SizedBox(width: 8),
          ],
          
          // Título
          Expanded(
            child: Text(
              'Novo Pedido',
              style: GoogleFonts.plusJakartaSans(
                fontSize: adaptive.isMobile ? 16 : 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
                height: 1.2,
              ),
            ),
          ),
          
          // Mini badges de mesa/comanda (compactos, apenas ícone + número)
          if (_mesa != null || _comanda != null) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: _buildMiniBadgesWithSpacing(adaptive),
            ),
            const SizedBox(width: 8),
          ],
          
          // Ações (botão de busca em mobile) - padrão igual área de mesas
          if (adaptive.isMobile) ...[
            _buildToolButtonCompact(
              adaptive,
              icon: Icons.search_rounded,
              onTap: () {
                _mostrarBuscaNotifier.value = !_mostrarBuscaNotifier.value;
              },
              isPrimary: true,
              tooltip: 'Buscar produto',
            ),
          ],
        ],
      ),
    );
  }

  /// Retorna lista de badges de mesa/comanda (versão legada para modal)
  List<Widget> _buildMesaComandaBadgesLegacy() {
    final badges = <Widget>[];
    
    if (_mesa != null) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.table_restaurant_rounded,
                size: 12,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 5),
              Text(
                'Mesa ${_mesa!.numero}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_comanda != null) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppTheme.accentColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 12,
                color: AppTheme.accentColor,
              ),
              const SizedBox(width: 5),
              Text(
                'Comanda ${_comanda!.numero}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentColor,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return badges;
  }

  /// Mini badges compactos de mesa/comanda (ícone pequeno acima + número)
  /// Altura igual aos botões, layout vertical compacto
  List<Widget> _buildMiniBadges(AdaptiveLayoutProvider adaptive) {
    final badges = <Widget>[];
    final buttonPadding = adaptive.isMobile ? 10.0 : 12.0; // Mesma altura dos botões
    
    if (_mesa != null) {
      badges.add(
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: adaptive.isMobile ? 6 : 8,
            vertical: buttonPadding, // Mesma altura dos botões
          ),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(adaptive.isMobile ? 10 : 12),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícone pequeno acima
              Icon(
                Icons.table_restaurant_rounded,
                size: adaptive.isMobile ? 12 : 14,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 2),
              // Número reduzido
              Text(
                _mesa!.numero,
                style: GoogleFonts.inter(
                  fontSize: adaptive.isMobile ? 10 : 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                  height: 1.0, // Altura de linha reduzida
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_comanda != null) {
      badges.add(
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: adaptive.isMobile ? 6 : 8,
            vertical: buttonPadding, // Mesma altura dos botões
          ),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(adaptive.isMobile ? 10 : 12),
            border: Border.all(
              color: AppTheme.accentColor.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícone pequeno acima
              Icon(
                Icons.receipt_long_rounded,
                size: adaptive.isMobile ? 12 : 14,
                color: AppTheme.accentColor,
              ),
              const SizedBox(height: 2),
              // Número reduzido
              Text(
                _comanda!.numero,
                style: GoogleFonts.inter(
                  fontSize: adaptive.isMobile ? 10 : 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentColor,
                  height: 1.0, // Altura de linha reduzida
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return badges;
  }

  /// Retorna mini badges com espaçamento entre eles
  List<Widget> _buildMiniBadgesWithSpacing(AdaptiveLayoutProvider adaptive) {
    final badges = _buildMiniBadges(adaptive);
    if (badges.isEmpty) return [];
    
    final result = <Widget>[];
    for (int i = 0; i < badges.length; i++) {
      result.add(badges[i]);
      if (i < badges.length - 1) {
        result.add(const SizedBox(width: 8));
      }
    }
    return result;
  }

  /// Botão voltar padrão único do sistema (apenas mobile)
  Widget _buildBackButton(AdaptiveLayoutProvider adaptive) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
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

  /// Botão de ferramenta compacto (padrão igual área de mesas)
  Widget _buildToolButtonCompact(
    AdaptiveLayoutProvider adaptive, {
    required IconData icon,
    required VoidCallback? onTap,
    required bool isPrimary,
    required String tooltip,
  }) {
    final buttonContent = Container(
      padding: EdgeInsets.all(adaptive.isMobile ? 10 : 12),
      decoration: BoxDecoration(
        gradient: isPrimary
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withOpacity(0.85),
                ],
              )
            : null,
        color: isPrimary ? null : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 10 : 12),
        border: Border.all(
          color: isPrimary
              ? AppTheme.primaryColor.withOpacity(0.2)
              : Colors.grey.shade300,
          width: isPrimary ? 0 : 1,
        ),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Icon(
        icon,
        color: isPrimary ? Colors.white : AppTheme.textPrimary,
        size: adaptive.isMobile ? 20 : 22,
      ),
    );
    
    if (onTap == null) {
      return Tooltip(
        message: tooltip,
        child: buttonContent,
      );
    }
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 10 : 12),
        child: Tooltip(
          message: tooltip,
          child: buttonContent,
        ),
      ),
    );
  }



  Future<void> _finalizarPedido(BuildContext context) async {
    final pedidoProvider = Provider.of<PedidoProvider>(context, listen: false);
    
    if (pedidoProvider.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos um item ao pedido'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostra loading
    LoadingHelper.show(context);

    try {
      // ✅ Usa método comum do PedidoProvider para finalizar
      // Para balcão: permitirHive=false (não salva no Hive se falhar)
      // Para mesa/comanda: permitirHive=true (salva no Hive se falhar)
      final isBalcao = widget.tipoVenda == TipoVenda.balcao;
      final result = await pedidoProvider.finalizarPedido(permitirHive: !isBalcao);

      if (!mounted) {
        LoadingHelper.hide(context);
        return;
      }

      // Fecha o loading
      LoadingHelper.hide(context);

      if (!result.sucesso) {
        // Mostra erro
        final mensagemErro = result.erro ?? 'Erro ao finalizar pedido. Tente novamente.';
        ErrorHelper.show(context, mensagemErro);
        return;
      }

      // Se for balcão, salva vendaId pendente e abre pagamento
      if (isBalcao) {
        if (result.vendaId == null) {
          ErrorHelper.show(context, 'Erro ao criar pedido. Tente novamente.');
          return;
        }

        // Salva vendaId pendente usando provider
        // A BalcaoScreen detecta isso e abre o pagamento automaticamente
        final vendaBalcaoProvider = Provider.of<VendaBalcaoProvider>(context, listen: false);
        await vendaBalcaoProvider.salvarVendaPendente(result.vendaId!);
        debugPrint('✅ VendaId salvo como pendente: ${result.vendaId}');

        // Fecha tela de pedido
        // A BalcaoScreen vai detectar a venda pendente e abrir o pagamento
        if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        return;
      }

      // Para mesa/comanda: mostra mensagem de sucesso e fecha
      // A sincronização é automática via listener do Hive (se foi salvo no Hive)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.foiEnviadoDireto 
                        ? 'Pedido enviado com sucesso!'
                        : 'Pedido finalizado! Sincronizando...',
                    style: GoogleFonts.plusJakartaSans(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Dispara evento para atualizar mesas/comandas (só se tiver pedidoId)
      if (result.pedidoId != null) {
        AppEventBus.instance.dispararPedidoCriado(
          pedidoId: result.pedidoId!,
          mesaId: widget.mesaId ?? '',
          comandaId: widget.comandaId ?? '',
        );
      }

      // Volta para a tela anterior após um breve delay
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop(true);
      }
    } catch (e) {
      LoadingHelper.hide(context);
      
      if (!mounted) return;
      ErrorHelper.show(context, 'Erro ao finalizar pedido: $e');
    }
  }

  // ✅ Método _finalizarPedidoBalcao removido - agora usa finalizarPedido() comum com permitirHive=false

  void _mostrarResumoPedidoMobile(BuildContext context) {
    // Salva o contexto da tela principal antes de abrir o bottom sheet
    final mainContext = context;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (sheetContext, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Conteúdo do resumo
              Expanded(
                child: PedidoResumoPanel(
                  onFinalizarPedido: () {
                    // Fecha o bottom sheet usando o contexto do bottom sheet
                    Navigator.of(bottomSheetContext).pop();
                    // Usa o contexto da tela principal para finalizar
                    _finalizarPedido(mainContext);
                  },
                  onLimparPedido: () {
                    // O botão de limpar já está no header do painel
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
