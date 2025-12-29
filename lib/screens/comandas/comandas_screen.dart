import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/elevated_toolbar_container.dart';
import '../../presentation/providers/services_provider.dart';
import '../../presentation/providers/comandas_provider.dart';
import '../../data/models/modules/restaurante/comanda_list_item.dart';
import '../../data/repositories/pedido_local_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../../data/models/user_preferences.dart';
import '../../core/widgets/teclado_numerico_dialog.dart';
import 'detalhes_comanda_screen.dart';
import '../mesas/detalhes_produtos_mesa_screen.dart';
import '../../models/mesas/entidade_produtos.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../widgets/h4nd_loading.dart';

/// Classe auxiliar para armazenar tamanhos do card
class _ComandaCardSizes {
  final double iconSize;
  final double numeroSize;
  final double statusSize;
  final double cardPadding;
  final double borderRadius;
  final double minWidth;
  final double minHeight;

  _ComandaCardSizes({
    required this.iconSize,
    required this.numeroSize,
    required this.statusSize,
    required this.cardPadding,
    required this.borderRadius,
    required this.minWidth,
    required this.minHeight,
  });
}

/// Tela de listagem de comandas (Restaurante)
class ComandasScreen extends StatefulWidget {
  /// Se deve ocultar o AppBar (usado quando acessada via bottom navigation)
  final bool hideAppBar;
  /// ID da comanda para selecionar automaticamente ao carregar
  final String? comandaId;
  /// Widget opcional para adicionar no início da barra de ferramentas
  final Widget? toolbarPrefix;

  const ComandasScreen({
    super.key,
    this.hideAppBar = false,
    this.comandaId,
    this.toolbarPrefix,
  });

  @override
  State<ComandasScreen> createState() => _ComandasScreenState();
}

class _ComandasScreenState extends State<ComandasScreen> {
  late ComandasProvider _provider;
  late UserPreferencesRepository _preferencesRepo;
  MesaViewSize _comandaViewSize = MesaViewSize.medio;
  String? _filtroAtivo; // Armazena o número da comanda filtrada

  @override
  void initState() {
    super.initState();
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    
    // Cria o provider
    _provider = ComandasProvider(
      comandaService: servicesProvider.comandaService,
      pedidoRepo: PedidoLocalRepository(),
      servicesProvider: servicesProvider,
    );
    
    // Repositório de preferências
    _preferencesRepo = UserPreferencesRepository();
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Carrega preferências do usuário
      final preferences = await _preferencesRepo.loadPreferences();
      if (mounted) {
        setState(() {
          _comandaViewSize = preferences.mesaViewSize; // Reutiliza o mesmo enum
        });
      }
      
      // Inicializa o provider (configura listeners e carrega comandas)
      _provider.initialize();
      
      // Seleciona comanda por ID se fornecido
      if (widget.comandaId != null) {
        // Aguarda um pouco para garantir que as comandas foram carregadas
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _provider.selecionarComandaPorId(widget.comandaId!);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  /// Atualiza o tamanho de visualização
  Future<void> _atualizarTamanhoVisualizacao(MesaViewSize novoSize) async {
    setState(() {
      _comandaViewSize = novoSize;
    });
    await _preferencesRepo.saveMesaViewSize(novoSize);
  }
  
  /// Abre teclado numérico para buscar comanda
  Future<void> _abrirBuscaComanda() async {
    final numero = await TecladoNumericoDialog.show(
      context,
      titulo: 'Buscar Comanda',
      valorInicial: _filtroAtivo,
      hint: 'Número da comanda',
      icon: Icons.receipt_long,
      cor: AppTheme.primaryColor,
    );

    if (numero != null && numero.trim().isNotEmpty) {
        setState(() {
        _filtroAtivo = numero.trim();
      });
      _provider.filterComandas(numero.trim());
    }
  }
  
  /// Remove o filtro ativo
  void _removerFiltro() {
        setState(() {
      _filtroAtivo = null;
    });
    _provider.filterComandas('');
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'livre':
        return AppTheme.successColor;
      case 'em uso':
        return AppTheme.warningColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) {
      return Scaffold(
        body: Center(
          child: H4ndLoading(size: 60),
        ),
      );
    }

    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: widget.hideAppBar
          ? null
          : AppHeader(
        title: 'Comandas',
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
                onPressed: () => _provider.loadComandas(refresh: true),
            tooltip: 'Atualizar',
            color: AppTheme.textPrimary,
          ),
        ],
      ),
          body: adaptive.isMobile
              ? Column(
                  children: [
                    // Barra de ferramentas (apenas mobile)
                    _buildBarraFerramentas(adaptive),
                    // Lista de comandas - Layout mobile
                    Expanded(
                      child: _buildMobileLayout(adaptive),
                    ),
                  ],
                )
              : _buildDesktopLayout(adaptive),
        );
      },
    );
  }

  /// Barra de ferramentas compacta usando o componente padrão
  Widget _buildBarraFerramentas(AdaptiveLayoutProvider adaptive) {
    return ElevatedToolbarContainer(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.isMobile ? 12 : 16,
        vertical: adaptive.isMobile ? 8 : 10,
      ),
      child: Row(
        children: [
          // Widget prefixo opcional (ex: toggle Mesas/Comandas)
          if (widget.toolbarPrefix != null) ...[
            widget.toolbarPrefix!,
            const SizedBox(width: 8),
          ],
          // Botão de busca - compacto
          _buildToolButtonCompact(
            adaptive,
            icon: Icons.search_rounded,
            onTap: _abrirBuscaComanda,
            isPrimary: true,
            tooltip: 'Buscar comanda',
          ),
          
          const SizedBox(width: 8),
          
          // Indicador de filtro ativo (se houver) - compacto
          if (_filtroAtivo != null) ...[
            Expanded(
              child: _buildFiltroBadgeCompact(adaptive),
            ),
            const SizedBox(width: 8),
          ] else ...[
            const Spacer(),
          ],
          
          // Seletor de visualização - compacto
          PopupMenuButton<MesaViewSize>(
            onSelected: _atualizarTamanhoVisualizacao,
            tooltip: 'Tamanho de visualização',
            child: _buildToolButtonCompact(
              adaptive,
              icon: _comandaViewSize.icon,
              onTap: null,
              isPrimary: false,
              tooltip: 'Visualização: ${_comandaViewSize.label}',
            ),
            itemBuilder: (context) => _buildViewSizeMenu(),
          ),
          
          const SizedBox(width: 8),
          
          // Botão de atualizar - compacto
          _buildToolButtonCompact(
            adaptive,
            icon: Icons.refresh_rounded,
            onTap: () => _provider.loadComandas(refresh: true),
            isPrimary: false,
            tooltip: 'Atualizar',
          ),
        ],
      ),
    );
  }
  
  /// Botão de ferramenta compacto (apenas ícone)
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
  
  /// Badge de filtro ativo compacto
  Widget _buildFiltroBadgeCompact(AdaptiveLayoutProvider adaptive) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.isMobile ? 10 : 12,
        vertical: adaptive.isMobile ? 6 : 8,
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
          Icon(
            Icons.filter_alt_rounded,
            size: adaptive.isMobile ? 16 : 18,
            color: AppTheme.primaryColor,
          ),
          SizedBox(width: adaptive.isMobile ? 6 : 8),
          Flexible(
            child: Text(
              'Comanda: $_filtroAtivo',
                style: GoogleFonts.inter(
                fontSize: adaptive.isMobile ? 13 : 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: adaptive.isMobile ? 6 : 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _removerFiltro,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: adaptive.isMobile ? 16 : 18,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Menu popup para seleção de tamanho
  List<PopupMenuItem<MesaViewSize>> _buildViewSizeMenu() {
    return MesaViewSize.values.map((size) {
      return PopupMenuItem<MesaViewSize>(
        value: size,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _comandaViewSize == size
                    ? AppTheme.primaryColor.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                size.icon,
                size: 20,
                color: _comandaViewSize == size
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              size.label,
              style: GoogleFonts.inter(
                fontWeight: _comandaViewSize == size
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: _comandaViewSize == size
                    ? AppTheme.primaryColor
                    : AppTheme.textPrimary,
              ),
            ),
            if (_comandaViewSize == size) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  /// Calcula o número de colunas dinamicamente baseado na largura disponível e tamanho de visualização
  int _calculateColumnsCount(AdaptiveLayoutProvider adaptive, double availableWidth) {
    if (adaptive.isMobile) {
      // Mobile: baseado no tamanho de visualização
      switch (_comandaViewSize) {
        case MesaViewSize.pequeno:
          return 3;
        case MesaViewSize.medio:
          return 2;
        case MesaViewSize.grande:
          return 2;
      }
    }
    
    // Desktop: calcula baseado no tamanho de visualização
    final tamanhos = _calcularTamanhosCard(adaptive);
    final larguraCard = tamanhos.minWidth;
    final espacamento = adaptive.isMobile ? 8.0 : 16.0;
    const double padding = 24.0 * 2;
    
    final double usableWidth = availableWidth - padding;
    int colunas = (usableWidth / (larguraCard + espacamento)).floor();
    
    // Limites baseados no tamanho de visualização
    switch (_comandaViewSize) {
      case MesaViewSize.pequeno:
        return colunas.clamp(4, 8);
      case MesaViewSize.medio:
        return colunas.clamp(3, 6);
      case MesaViewSize.grande:
        return colunas.clamp(2, 4);
    }
  }

  /// Calcula tamanhos do card baseado no tamanho de visualização
  _ComandaCardSizes _calcularTamanhosCard(AdaptiveLayoutProvider adaptive) {
    final baseSize = adaptive.isMobile ? 0.9 : 1.0;
    
    switch (_comandaViewSize) {
      case MesaViewSize.pequeno:
        return _ComandaCardSizes(
          iconSize: 20.0 * baseSize,
          numeroSize: 20.0 * baseSize,
          statusSize: 8.0 * baseSize,
          cardPadding: 6.0 * baseSize,
          borderRadius: 12.0,
          minWidth: 80.0,
          minHeight: 80.0,
        );
      case MesaViewSize.medio:
        return _ComandaCardSizes(
          iconSize: 28.0 * baseSize,
          numeroSize: 28.0 * baseSize,
          statusSize: 10.0 * baseSize,
          cardPadding: 10.0 * baseSize,
          borderRadius: 14.0,
          minWidth: 100.0,
          minHeight: 100.0,
        );
      case MesaViewSize.grande:
        return _ComandaCardSizes(
          iconSize: 42.0 * baseSize,
          numeroSize: 36.0 * baseSize,
          statusSize: 12.0 * baseSize,
          cardPadding: 14.0 * baseSize,
          borderRadius: 16.0,
          minWidth: 140.0,
          minHeight: 140.0,
        );
    }
  }

  Widget _buildMobileLayout(AdaptiveLayoutProvider adaptive) {
    if (_provider.errorMessage != null) {
      return _buildErrorWidget(adaptive);
    }

    if (_provider.isLoading && _provider.comandas.isEmpty) {
      return Center(child: H4ndLoading(size: 60));
    }

    if (_provider.filteredComandas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _filtroAtivo != null
                  ? Icons.search_off
                  : Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _filtroAtivo != null
                  ? 'Nenhuma comanda encontrada'
                  : 'Nenhuma comanda cadastrada',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnsCount = _calculateColumnsCount(adaptive, constraints.maxWidth);
        return RefreshIndicator(
          onRefresh: () => _provider.loadComandas(refresh: true),
          child: GridView.builder(
      padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columnsCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
            itemCount: _provider.filteredComandas.length,
      itemBuilder: (context, index) {
              final comanda = _provider.filteredComandas[index];
        return _buildComandaCard(comanda, adaptive);
            },
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout(AdaptiveLayoutProvider adaptive) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcula largura disponível para o grid (40% da tela)
        final double gridWidth = constraints.maxWidth * 0.4;
        final int columnsCount = _calculateColumnsCount(adaptive, gridWidth);
        
        return Row(
          children: [
            // Coluna esquerda: Barra de ferramentas + GridView de comandas
            Expanded(
              flex: 4, // 40% da largura
              child: Column(
                children: [
                  // Barra de ferramentas (apenas desktop - dentro da coluna de comandas)
                  _buildBarraFerramentas(adaptive),
                  // GridView de comandas
                  Expanded(
                    child: _provider.errorMessage != null
                        ? _buildErrorWidget(adaptive)
                        : Container(
                            color: Colors.white,
                            child: _provider.isLoading && _provider.comandas.isEmpty
                                ? Center(
                                    child: H4ndLoading(size: 60),
                                  )
                                : _provider.filteredComandas.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _filtroAtivo != null
                                                  ? Icons.search_off
                                                  : Icons.receipt_long_outlined,
                                              size: 64,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              _filtroAtivo != null
                                                  ? 'Nenhuma comanda encontrada'
                                                  : 'Nenhuma comanda cadastrada',
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : RefreshIndicator(
                                        onRefresh: () => _provider.loadComandas(refresh: true),
                                        child: GridView.builder(
                                          padding: EdgeInsets.all(adaptive.isMobile ? 16 : 24),
                                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: columnsCount,
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 12,
                                            childAspectRatio: adaptive.isDesktop ? 1.0 : 1.05,
                                          ),
                                          itemCount: _provider.filteredComandas.length,
                                          itemBuilder: (context, index) {
                                            final comanda = _provider.filteredComandas[index];
                                            final isSelected = _provider.selectedComanda?.id == comanda.id;
                                            return _buildComandaCard(comanda, adaptive, isSelected: isSelected);
                                          },
                                          addAutomaticKeepAlives: false,
                                          addRepaintBoundaries: false,
                                        ),
                                      ),
                          ),
                  ),
                ],
              ),
            ),
            // Divisor vertical
            Container(
              width: 1,
              color: Colors.grey.shade300,
            ),
            // Coluna direita: Detalhes da comanda selecionada
            Expanded(
              flex: 6, // 60% da largura
              child: _provider.selectedComanda == null
                  ? _buildEmptyDetailsPanel(adaptive)
                  : DetalhesProdutosMesaScreen(
                      key: ValueKey('comanda_detalhes_${_provider.selectedComanda!.id}'),
                      entidade: MesaComandaInfo(
                        id: _provider.selectedComanda!.id,
                        numero: _provider.selectedComanda!.numero,
                        descricao: _provider.selectedComanda!.descricao,
                        status: _provider.getStatusVisualComanda(_provider.selectedComanda!),
                        tipo: TipoEntidade.comanda,
                        codigoBarras: _provider.selectedComanda!.codigoBarras,
                      ),
                    ),
            ),
          ],
        );
      },
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
                    ? 'Sistema Offline'
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
                      ? 'Sistema offline. Não é possível consultar as comandas atualizadas. Verifique sua conexão com o servidor e tente novamente.'
                      : 'Não foi possível carregar as comandas. Por favor, tente novamente.',
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
                    : () => _provider.loadComandas(refresh: true),
                icon: _provider.isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: H4ndLoadingCompact(
                          size: 20,
                          blueColor: Colors.white,
                          greenColor: Colors.white70,
                        ),
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
              
              // Mensagem de erro técnica (opcional, menor)
              if (!isConnectionError && _provider.errorMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _provider.errorMessage!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
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

  /// Painel vazio quando nenhuma comanda está selecionada
  Widget _buildEmptyDetailsPanel(AdaptiveLayoutProvider adaptive) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Selecione uma comanda para ver os detalhes',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComandaCard(ComandaListItemDto comanda, AdaptiveLayoutProvider adaptive, {bool isSelected = false}) {
    // Usa status visual que considera pedidos pendentes locais
    final statusVisual = _provider.getStatusVisualComanda(comanda);
    final statusColor = _getStatusColor(statusVisual);
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final pedidosPendentes = _provider.getPedidosPendentesCount(comanda.id);

    // Tamanhos baseados na preferência do usuário
    final tamanhos = _calcularTamanhosCard(adaptive);

    return Material(
      color: Colors.transparent,
      // Key inclui status visual para forçar rebuild quando status mudar
      key: ValueKey('comanda_${comanda.numero}_${comanda.id}_$statusVisual'),
      child: InkWell(
        onTap: () {
          final adaptive = AdaptiveLayoutProvider.of(context);
          if (adaptive == null) return;
          
          // Mobile: navega para outra tela
          // Tablet/Desktop: atualiza comanda selecionada
          if (adaptive.isMobile) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AdaptiveLayout(
                  child: DetalhesComandaScreen(comanda: comanda),
                ),
              ),
            );
          } else {
            // Tablet/Desktop: atualiza estado para mostrar painel lateral
            _provider.setSelectedComanda(comanda);
          }
        },
        borderRadius: BorderRadius.circular(tamanhos.borderRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          constraints: BoxConstraints(
            minWidth: tamanhos.minWidth,
            minHeight: tamanhos.minHeight,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.05)
                : statusColor.withOpacity(0.18),
            borderRadius: BorderRadius.circular(tamanhos.borderRadius),
            border: Border.all(
              color: isSelected 
                  ? AppTheme.primaryColor
                  : statusColor.withOpacity(0.7),
              width: isSelected ? 2.5 : 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppTheme.primaryColor.withOpacity(0.2)
                    : statusColor.withOpacity(0.3),
                blurRadius: isSelected ? 16 : 12,
                offset: Offset(0, isSelected ? 4 : 3),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Conteúdo principal - layout iconizado, centralizado e ocupando mais espaço
              Center(
                child: Padding(
                  padding: EdgeInsets.all(tamanhos.cardPadding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ícone centralizado - elemento principal iconizado
                      Container(
                        padding: EdgeInsets.all(tamanhos.cardPadding * 0.8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: statusColor.withOpacity(0.6),
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          size: tamanhos.iconSize,
                          color: statusColor,
                        ),
                      ),
                      
                      SizedBox(height: tamanhos.cardPadding * 0.8),
                      
                      // Número da comanda - com maior destaque
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            comanda.numero,
                            style: GoogleFonts.inter(
                              fontSize: tamanhos.numeroSize,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              height: 1.0,
                              letterSpacing: 1.0,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      
                      SizedBox(height: tamanhos.cardPadding * 0.6),
                      
                      // Label de status - texto com melhor contraste e legibilidade
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: tamanhos.statusSize * 0.6,
                              vertical: tamanhos.statusSize * 0.25,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(tamanhos.statusSize * 0.5),
                            ),
                            child: Text(
                              statusVisual.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: tamanhos.statusSize,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                                letterSpacing: 0.8,
                                height: 1.0,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      
                      // Informações adicionais (se houver pedidos)
                      if (comanda.totalPedidosAtivos > 0) ...[
                        SizedBox(height: tamanhos.cardPadding * 0.4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              currencyFormat.format(comanda.valorTotalPedidosAtivos),
                              style: GoogleFonts.inter(
                                fontSize: tamanhos.statusSize * 1.1,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              // Badge de pedidos pendentes (se houver) - posicionado no canto superior direito
              if (pedidosPendentes > 0)
                Positioned(
                  top: tamanhos.cardPadding * 0.5,
                  right: tamanhos.cardPadding * 0.5,
                  child: Container(
                    padding: EdgeInsets.all(tamanhos.statusSize * 0.5),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade600,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.shade600.withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '$pedidosPendentes',
                      style: GoogleFonts.inter(
                        fontSize: tamanhos.statusSize * 0.9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
