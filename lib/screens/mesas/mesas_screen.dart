import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/elevated_toolbar_container.dart';
import '../../presentation/providers/services_provider.dart';
import '../../presentation/providers/mesas_provider.dart';
import '../../data/models/modules/restaurante/mesa_list_item.dart';
import '../../data/models/local/pedido_local.dart';
import '../../data/models/local/sync_status_pedido.dart';
import '../../data/repositories/pedido_local_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../../data/models/user_preferences.dart';
import '../../core/widgets/teclado_numerico_dialog.dart';
import 'detalhes_mesa_screen.dart';
import 'detalhes_produtos_mesa_screen.dart';
import '../../models/mesas/entidade_produtos.dart';
import '../../data/models/mesa_alerta.dart';
import 'widgets/mesa_insights_panel.dart';
import 'widgets/mesa_alerta_badge.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/h4nd_loading.dart';

/// Classe auxiliar para armazenar tamanhos do card
class _MesaCardSizes {
  final double iconSize;
  final double numeroSize;
  final double statusSize;
  final double cardPadding;
  final double borderRadius;
  final double minWidth;
  final double minHeight;

  _MesaCardSizes({
    required this.iconSize,
    required this.numeroSize,
    required this.statusSize,
    required this.cardPadding,
    required this.borderRadius,
    required this.minWidth,
    required this.minHeight,
  });
}

/// Tela de listagem de mesas (Restaurante)
class MesasScreen extends StatefulWidget {
  /// Se deve ocultar o AppBar (usado quando acessada via bottom navigation)
  final bool hideAppBar;
  /// Widget opcional para adicionar no início da barra de ferramentas
  final Widget? toolbarPrefix;

  const MesasScreen({
    super.key,
    this.hideAppBar = false,
    this.toolbarPrefix,
  });

  @override
  State<MesasScreen> createState() => _MesasScreenState();
}

class _MesasScreenState extends State<MesasScreen> {
  late MesasProvider _provider;
  final UserPreferencesRepository _preferencesRepo = UserPreferencesRepository();
  MesaViewSize _mesaViewSize = MesaViewSize.medio;
  String? _filtroAtivo; // Armazena o número da mesa filtrada
  bool _filtroApenasAlertas = false; // Filtro para mostrar apenas mesas com alertas
  List<MesaAlerta> _alertas = []; // Lista de alertas mockados

  @override
  void initState() {
    super.initState();
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    
    // Cria o provider
    _provider = MesasProvider(
      mesaService: servicesProvider.mesaService,
      pedidoRepo: PedidoLocalRepository(),
      servicesProvider: servicesProvider,
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Carrega preferências do usuário
      final preferences = await _preferencesRepo.loadPreferences();
      if (mounted) {
        setState(() {
          _mesaViewSize = preferences.mesaViewSize;
        });
      }
      
      // Inicializa o provider (configura listeners e carrega mesas)
      _provider.initialize();
      
      // Gera alertas mockados após carregar mesas
      _gerarAlertasMockados();
    });
  }
  
  /// Gera alertas mockados para todas as mesas ocupadas
  /// Por enquanto, todas as mesas ocupadas terão os 2 tipos de alertas
  void _gerarAlertasMockados() {
    // Aguarda um pouco para garantir que as mesas foram carregadas
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      final mesasOcupadas = _provider.filteredMesas
          .where((mesa) => mesa.status.toLowerCase() == 'ocupada')
          .toList();
      
      final alertas = <MesaAlerta>[];
      
      for (final mesa in mesasOcupadas) {
        // Usa hashCode do String id para gerar valores consistentes
        final hash = mesa.id.hashCode;
        
        // Alerta 1: Tempo sem pedir (mock: 10-20 minutos)
        final tempoSemPedir = Duration(minutes: 10 + (hash.abs() % 10));
        alertas.add(MesaAlerta(
          mesaId: mesa.id,
          numeroMesa: mesa.numero,
          tipo: TipoAlertaMesa.tempoSemPedir,
          tempoDecorrido: tempoSemPedir,
        ));
        
        // Alerta 2: Itens aguardando (mock: 15-30 minutos, 1-5 itens)
        final tempoItens = Duration(minutes: 15 + (hash.abs() % 15));
        final quantidadeItens = 1 + (hash.abs() % 5);
        alertas.add(MesaAlerta(
          mesaId: mesa.id,
          numeroMesa: mesa.numero,
          tipo: TipoAlertaMesa.itensAguardando,
          tempoDecorrido: tempoItens,
          detalhes: '$quantidadeItens ${quantidadeItens == 1 ? 'item' : 'itens'} aguardando',
        ));
      }
      
      if (mounted) {
        setState(() {
          _alertas = alertas;
        });
      }
    });
  }
  
  /// Alterna o filtro de alertas
  void _toggleFiltroAlertas() {
    setState(() {
      _filtroApenasAlertas = !_filtroApenasAlertas;
    });
  }
  
  /// Retorna as mesas filtradas (considerando filtro de alertas)
  List<MesaListItemDto> get _mesasFiltradas {
    var mesas = _provider.filteredMesas;
    
    if (_filtroApenasAlertas) {
      final idsComAlerta = _alertas.map((a) => a.mesaId).toSet();
      mesas = mesas.where((mesa) => idsComAlerta.contains(mesa.id)).toList();
    }
    
    return mesas;
  }
  
  /// Retorna os alertas de uma mesa específica
  List<MesaAlerta> _getAlertasMesa(String mesaId) {
    return _alertas.where((a) => a.mesaId == mesaId).toList();
  }
  
  /// Atualiza o tamanho de visualização e salva a preferência
  Future<void> _atualizarTamanhoVisualizacao(MesaViewSize novoSize) async {
    setState(() {
      _mesaViewSize = novoSize;
    });
    await _preferencesRepo.saveMesaViewSize(novoSize);
  }
  
  /// Abre teclado numérico para buscar mesa
  Future<void> _abrirBuscaMesa() async {
    final numero = await TecladoNumericoDialog.show(
      context,
      titulo: 'Buscar Mesa',
      valorInicial: _filtroAtivo,
      hint: 'Número da mesa',
      icon: Icons.table_restaurant,
      cor: AppTheme.primaryColor,
    );

    if (numero != null && numero.trim().isNotEmpty) {
      setState(() {
        _filtroAtivo = numero.trim();
      });
      _provider.filterMesas(numero.trim());
    }
  }
  
  /// Remove o filtro ativo
  void _removerFiltro() {
    setState(() {
      _filtroAtivo = null;
    });
    _provider.filterMesas('');
  }
  
  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'livre':
        return const Color(0xFF10B981); // Verde vibrante
      case 'ocupada':
        return const Color(0xFFF59E0B); // Laranja vibrante
      case 'reservada':
        return const Color(0xFF3B82F6); // Azul vibrante
      case 'manutencao':
        return const Color(0xFFEF4444); // Vermelho vibrante
      case 'suspensa':
        return const Color(0xFF6B7280); // Cinza médio
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'livre':
        return 'Livre';
      case 'ocupada':
        return 'Ocupada';
      case 'reservada':
        return 'Reservada';
      case 'manutencao':
        return 'Manutenção';
      case 'suspensa':
        return 'Suspensa';
      default:
        return status;
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
          body: adaptive.isMobile
              ? Column(
                  children: [
                    // Barra de ferramentas (apenas mobile)
                    _buildBarraFerramentas(adaptive),
                    // Lista de mesas - Layout mobile
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


  /// Calcula o número de colunas dinamicamente baseado na largura disponível
  /// Mantém um tamanho mínimo fixo para os cards (mais compacto)
  int _calculateColumnsCount(AdaptiveLayoutProvider adaptive, double availableWidth) {
    return _calcularColunasGrid(adaptive, availableWidth);
  }
  
  /// Calcula o aspect ratio baseado no tamanho de visualização
  double _calcularAspectRatio(AdaptiveLayoutProvider adaptive) {
    final tamanhos = _calcularTamanhosCard(adaptive);
    // Aspect ratio baseado nas dimensões mínimas
    return tamanhos.minWidth / tamanhos.minHeight;
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'livre':
        return Icons.check_circle_outline;
      case 'ocupada':
        return Icons.people_outline;
      case 'reservada':
        return Icons.event_available_outlined;
      case 'manutencao':
        return Icons.build_outlined;
      case 'suspensa':
        return Icons.block_outlined;
      default:
        return Icons.help_outline;
    }
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
            onTap: _abrirBuscaMesa,
            isPrimary: true,
            tooltip: 'Buscar mesa',
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
              icon: _mesaViewSize.icon,
              onTap: null,
              isPrimary: false,
              tooltip: 'Visualização: ${_mesaViewSize.label}',
            ),
            itemBuilder: (context) => _buildViewSizeMenu(),
          ),
          
          const SizedBox(width: 8),
          
          // Botão de filtro de alertas - compacto (apenas desktop)
          if (!adaptive.isMobile) ...[
            Stack(
              children: [
                _buildToolButtonCompact(
                  adaptive,
                  icon: Icons.warning_rounded,
                  onTap: _toggleFiltroAlertas,
                  isPrimary: _filtroApenasAlertas,
                  tooltip: _filtroApenasAlertas
                      ? 'Mostrar todas as mesas'
                      : 'Mostrar apenas mesas com alertas',
                ),
                if (_alertas.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${_alertas.length}',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
          ],
          
          // Botão de atualizar - compacto
          _buildToolButtonCompact(
            adaptive,
            icon: Icons.refresh_rounded,
            onTap: () => _provider.loadMesas(refresh: true),
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
            size: 14,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Mesa $_filtroAtivo',
              style: GoogleFonts.inter(
                fontSize: adaptive.isMobile ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _removerFiltro,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Menu popup para seleção de tamanho (método auxiliar)
  List<PopupMenuItem<MesaViewSize>> _buildViewSizeMenu() {
    return MesaViewSize.values.map((size) {
      return PopupMenuItem<MesaViewSize>(
        value: size,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _mesaViewSize == size
                    ? AppTheme.primaryColor.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                size.icon,
                size: 20,
                color: _mesaViewSize == size
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              size.label,
              style: GoogleFonts.inter(
                fontWeight: _mesaViewSize == size
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: _mesaViewSize == size
                    ? AppTheme.primaryColor
                    : AppTheme.textPrimary,
              ),
            ),
            if (_mesaViewSize == size) ...[
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

  /// Seletor de tamanho de visualização (método antigo - mantido para compatibilidade)
  Widget _buildViewSizeSelector(AdaptiveLayoutProvider adaptive) {
    return PopupMenuButton<MesaViewSize>(
      icon: Icon(
        _mesaViewSize.icon,
        color: AppTheme.textPrimary,
      ),
      tooltip: 'Tamanho de visualização',
      onSelected: _atualizarTamanhoVisualizacao,
      itemBuilder: (context) => MesaViewSize.values.map((size) {
        return PopupMenuItem<MesaViewSize>(
          value: size,
          child: Row(
            children: [
              Icon(
                size.icon,
                size: 20,
                color: _mesaViewSize == size 
                    ? AppTheme.primaryColor 
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                size.label,
                style: GoogleFonts.inter(
                  fontWeight: _mesaViewSize == size 
                      ? FontWeight.w600 
                      : FontWeight.normal,
                  color: _mesaViewSize == size 
                      ? AppTheme.primaryColor 
                      : AppTheme.textPrimary,
                ),
              ),
              if (_mesaViewSize == size) ...[
                const Spacer(),
                Icon(
                  Icons.check,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Calcula os tamanhos baseados no tamanho de visualização selecionado
  _MesaCardSizes _calcularTamanhosCard(AdaptiveLayoutProvider adaptive) {
    final baseSize = adaptive.isMobile ? 1.0 : (adaptive.isDesktop ? 0.8 : 1.0);
    
    switch (_mesaViewSize) {
      case MesaViewSize.pequeno:
        return _MesaCardSizes(
          iconSize: 20.0 * baseSize, // Reduzido de 24 para 20
          numeroSize: 20.0 * baseSize, // Aumentado de 16 para 20
          statusSize: 8.0 * baseSize,
          cardPadding: 6.0 * baseSize,
          borderRadius: 12.0,
          minWidth: 80.0,
          minHeight: 80.0,
        );
      case MesaViewSize.medio:
        return _MesaCardSizes(
          iconSize: 28.0 * baseSize, // Reduzido de 32 para 28
          numeroSize: 28.0 * baseSize, // Aumentado de 22 para 28
          statusSize: 10.0 * baseSize,
          cardPadding: 10.0 * baseSize,
          borderRadius: 14.0,
          minWidth: 100.0,
          minHeight: 100.0,
        );
      case MesaViewSize.grande:
        return _MesaCardSizes(
          iconSize: 42.0 * baseSize, // Reduzido de 48 para 42
          numeroSize: 36.0 * baseSize, // Aumentado de 28 para 36
          statusSize: 12.0 * baseSize,
          cardPadding: 14.0 * baseSize,
          borderRadius: 16.0,
          minWidth: 140.0,
          minHeight: 140.0,
        );
    }
  }

  /// Calcula o número de colunas baseado no tamanho de visualização
  int _calcularColunasGrid(AdaptiveLayoutProvider adaptive, double larguraDisponivel) {
    final tamanhos = _calcularTamanhosCard(adaptive);
    final larguraCard = tamanhos.minWidth;
    final espacamento = adaptive.isMobile ? 8.0 : 16.0;
    
    // Calcula quantos cards cabem na largura disponível
    int colunas = (larguraDisponivel / (larguraCard + espacamento)).floor();
    
    // Garante mínimo de 2 colunas e máximo baseado no tamanho
    switch (_mesaViewSize) {
      case MesaViewSize.pequeno:
        return colunas.clamp(4, 8);
      case MesaViewSize.medio:
        return colunas.clamp(3, 6);
      case MesaViewSize.grande:
        return colunas.clamp(2, 4);
    }
  }

  Widget _buildMesaCard(MesaListItemDto mesa, AdaptiveLayoutProvider adaptive, {bool isSelected = false}) {
    // O Provider já escuta mudanças no Hive e recalcula status automaticamente
    // Não precisa mais de ValueListenableBuilder aqui - o ListenableBuilder do Provider já cuida disso
    return _buildMesaCardContent(mesa, adaptive, isSelected: isSelected);
  }
  
  
  /// Conteúdo do card da mesa (extraído para reutilização)
  Widget _buildMesaCardContent(MesaListItemDto mesa, AdaptiveLayoutProvider adaptive, {bool isSelected = false}) {
    // Usa status visual que considera pedidos pendentes locais
    final statusVisual = _provider.getStatusVisualMesa(mesa);
    final statusColor = _getStatusColor(statusVisual);
    final statusLabel = _getStatusLabel(statusVisual);
    final statusIcon = _getStatusIcon(statusVisual);
    final statusLower = statusVisual.toLowerCase();
    final isOcupada = statusLower == 'ocupada';
    final isLivre = statusLower == 'livre';
    final isReservada = statusLower == 'reservada';
    
    // Valida se o número da mesa está preenchido (é String)
    final numeroMesa = mesa.numero.trim();
    final temNumero = numeroMesa.isNotEmpty;

    // Tamanhos baseados na preferência do usuário
    final tamanhos = _calcularTamanhosCard(adaptive);

    return Material(
      color: Colors.transparent,
      // Key inclui status visual para forçar rebuild quando status mudar
      key: ValueKey('mesa_${mesa.numero}_${mesa.id}_$statusVisual'),
      child: InkWell(
        onTap: () {
          final adaptive = AdaptiveLayoutProvider.of(context);
          if (adaptive == null) return;
          
          // Mobile: navega para outra tela
          // Tablet/Desktop: atualiza mesa selecionada
          if (adaptive.isMobile) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AdaptiveLayout(
                  child: DetalhesMesaScreen(mesa: mesa),
                ),
              ),
            );
          } else {
            // Tablet/Desktop: atualiza estado para mostrar painel lateral
            _provider.setSelectedMesa(mesa);
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
                : statusColor.withOpacity(0.18), // Aumentado de 0.08 para 0.18 - mais vivo
            borderRadius: BorderRadius.circular(tamanhos.borderRadius),
            border: Border.all(
              color: isSelected 
                  ? AppTheme.primaryColor
                  : statusColor.withOpacity(0.7), // Aumentado de 0.4 para 0.7 - mais vivo
              width: isSelected ? 2.5 : 2.5, // Aumentado de 2.0 para 2.5
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppTheme.primaryColor.withOpacity(0.2)
                    : statusColor.withOpacity(0.3), // Aumentado de 0.15 para 0.3 - mais vivo
                blurRadius: isSelected ? 16 : 12, // Aumentado de 10 para 12
                offset: Offset(0, isSelected ? 4 : 3), // Aumentado de 2 para 3
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
                          color: Colors.white, // Fundo branco para máximo contraste
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
                          statusIcon,
                          size: tamanhos.iconSize,
                          color: statusColor, // Cor sólida e vibrante para máximo contraste
                        ),
                      ),
                      
                      SizedBox(height: tamanhos.cardPadding * 0.8),
                      
                      // Número da mesa - com maior destaque
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            temNumero ? numeroMesa : '?',
                            style: GoogleFonts.inter(
                              fontSize: tamanhos.numeroSize,
                              fontWeight: FontWeight.w800, // Aumentado de w700 para w800
                              color: AppTheme.textPrimary,
                              height: 1.0,
                              letterSpacing: 1.0, // Aumentado de 0.5 para 1.0
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
                              color: Colors.white, // Fundo branco para máximo contraste
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: statusColor.withOpacity(0.6),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              statusLabel.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: tamanhos.statusSize * 1.1, // Aumentado em 10%
                                fontWeight: FontWeight.w800, // Aumentado de w700 para w800
                                color: statusColor, // Cor sólida e vibrante
                                letterSpacing: 1.0, // Aumentado de 0.8 para 1.0
                                height: 1.0,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Badges de alertas (se houver) - posicionados no canto superior direito
              // Apenas para mesas ocupadas
              if (isOcupada) ...[
                Builder(
                  builder: (context) {
                    final alertasMesa = _getAlertasMesa(mesa.id);
                    if (alertasMesa.isEmpty) return const SizedBox.shrink();
                    
                    return Positioned(
                      top: tamanhos.cardPadding * 0.5,
                      right: tamanhos.cardPadding * 0.5,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Badge de tempo sem pedir
                          if (alertasMesa.any((a) => a.tipo == TipoAlertaMesa.tempoSemPedir))
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: MesaAlertaBadge(
                                tipo: TipoAlertaMesa.tempoSemPedir,
                                tooltip: alertasMesa
                                    .firstWhere((a) => a.tipo == TipoAlertaMesa.tempoSemPedir)
                                    .descricao,
                                size: 20,
                              ),
                            ),
                          // Badge de itens aguardando
                          if (alertasMesa.any((a) => a.tipo == TipoAlertaMesa.itensAguardando))
                            MesaAlertaBadge(
                              tipo: TipoAlertaMesa.itensAguardando,
                              tooltip: alertasMesa
                                  .firstWhere((a) => a.tipo == TipoAlertaMesa.itensAguardando)
                                  .descricao,
                              size: 20,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              
              // Badge de pedidos pendentes (se houver) - posicionado no canto superior direito
              // O Provider já mantém o status atualizado via ListenableBuilder
              Builder(
                builder: (context) {
                  final pedidosPendentes = _provider.getPedidosPendentesCount(mesa.id);
                  if (pedidosPendentes > 0) {
                    return Positioned(
                      top: tamanhos.cardPadding * 0.5,
                      left: tamanhos.cardPadding * 0.5, // Muda para esquerda para não conflitar com alertas
                      child: Container(
                        padding: EdgeInsets.all(tamanhos.cardPadding * 0.5),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$pedidosPendentes',
                          style: GoogleFonts.inter(
                            fontSize: tamanhos.statusSize,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
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
                      ? 'Sistema offline. Não é possível consultar as mesas atualizadas. Verifique sua conexão com o servidor e tente novamente.'
                      : 'Não foi possível carregar as mesas. Por favor, tente novamente.',
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
                    : () => _provider.loadMesas(refresh: true),
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

  /// Layout para mobile (comportamento atual)
  Widget _buildMobileLayout(AdaptiveLayoutProvider adaptive) {
    return Container(
      color: Colors.white,
      child: _provider.errorMessage != null
          ? _buildErrorWidget(adaptive)
          : _provider.isLoading && _provider.mesas.isEmpty
              ? Center(
                  child: H4ndLoading(size: 60),
                )
              : _mesasFiltradas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _filtroAtivo != null || _filtroApenasAlertas
                                ? Icons.search_off
                                : Icons.table_restaurant_outlined,
                            size: 64,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _filtroApenasAlertas
                                ? 'Nenhuma mesa com alertas no momento'
                                : _filtroAtivo != null
                                    ? 'Nenhuma mesa encontrada com número "$_filtroAtivo"'
                                    : 'Nenhuma mesa encontrada',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                : RefreshIndicator(
                    onRefresh: () => _provider.loadMesas(refresh: true),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final colunas = _calcularColunasGrid(adaptive, constraints.maxWidth);
                        final aspectRatio = _calcularAspectRatio(adaptive);
                        return GridView.builder(
                          padding: EdgeInsets.all(adaptive.isMobile ? 12 : 24),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: colunas,
                            crossAxisSpacing: adaptive.isMobile ? 8 : 16,
                            mainAxisSpacing: adaptive.isMobile ? 8 : 16,
                            childAspectRatio: aspectRatio,
                          ),
                                      itemCount: _mesasFiltradas.length,
                                      itemBuilder: (context, index) {
                                        final mesa = _mesasFiltradas[index];
                            return _buildMesaCard(mesa, adaptive);
                          },
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: false,
                        );
                      },
                    ),
                  ),
    );
  }

  /// Layout para tablet/desktop (dividido em duas colunas)
  Widget _buildDesktopLayout(AdaptiveLayoutProvider adaptive) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcula largura disponível para o grid (40% da tela)
        final double gridWidth = constraints.maxWidth * 0.4;
        final int columnsCount = _calculateColumnsCount(adaptive, gridWidth);
        
        return Row(
          children: [
            // Coluna esquerda: Barra de ferramentas + GridView de mesas
            Expanded(
              flex: 4, // 40% da largura
              child: Column(
                children: [
                  // Barra de ferramentas (apenas desktop - dentro da coluna de mesas)
                  _buildBarraFerramentas(adaptive),
                  // Painel de insights (apenas desktop)
                  MesaInsightsPanel(
                    alertas: _alertas,
                    isDesktop: true,
                  ),
                  // GridView de mesas
                  Expanded(
                    child: _provider.errorMessage != null
                        ? _buildErrorWidget(adaptive)
                        : Container(
                            color: Colors.white,
                            child: _provider.isLoading && _provider.mesas.isEmpty
                                ? Center(
                                    child: H4ndLoading(size: 60),
                                  )
                              : _mesasFiltradas.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _filtroAtivo != null || _filtroApenasAlertas
                                                ? Icons.search_off
                                                : Icons.table_restaurant_outlined,
                                            size: 64,
                                            color: AppTheme.textSecondary,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            _filtroApenasAlertas
                                                ? 'Nenhuma mesa com alertas no momento'
                                                : _filtroAtivo != null
                                                    ? 'Nenhuma mesa encontrada com número "$_filtroAtivo"'
                                                    : 'Nenhuma mesa encontrada',
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                            : RefreshIndicator(
                                onRefresh: () => _provider.loadMesas(refresh: true),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final colunas = _calcularColunasGrid(adaptive, constraints.maxWidth);
                                    final aspectRatio = _calcularAspectRatio(adaptive);
                                    return GridView.builder(
                                      padding: EdgeInsets.all(adaptive.isMobile ? 16 : 24),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: colunas,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: aspectRatio,
                                      ),
                                      itemCount: _mesasFiltradas.length,
                                      itemBuilder: (context, index) {
                                        final mesa = _mesasFiltradas[index];
                                        final isSelected = _provider.selectedMesa?.id == mesa.id;
                                        return _buildMesaCard(mesa, adaptive, isSelected: isSelected);
                                      },
                                      addAutomaticKeepAlives: false,
                                      addRepaintBoundaries: false,
                                    );
                                  },
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
        // Coluna direita: Detalhes da mesa selecionada
        Expanded(
          flex: 6, // 60% da largura
          child: _provider.selectedMesa == null
              ? _buildEmptyDetailsPanel(adaptive)
              : DetalhesProdutosMesaScreen(
                  key: ValueKey('mesa_detalhes_${_provider.selectedMesa!.id}'), // Key única força reconstrução
                  entidade: MesaComandaInfo(
                    id: _provider.selectedMesa!.id,
                    numero: _provider.selectedMesa!.numero,
                    descricao: _provider.selectedMesa!.descricao,
                    status: _provider.selectedMesa!.status,
                    tipo: TipoEntidade.mesa,
                  ),
                ),
        ),
          ],
        );
      },
    );
  }

  /// Painel vazio quando nenhuma mesa está selecionada
  Widget _buildEmptyDetailsPanel(AdaptiveLayoutProvider adaptive) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_restaurant_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Selecione uma mesa para ver os detalhes',
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

  Widget _buildStatusBadge(
    AdaptiveLayoutProvider adaptive,
    Color statusColor,
    String statusLabel,
    IconData statusIcon,
    int? pedidosPendentes,
  ) {
    return Column(
      children: [
        // Status badge
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: adaptive.isMobile ? 14 : (adaptive.isDesktop ? 10 : 16),
            vertical: adaptive.isMobile ? 8 : (adaptive.isDesktop ? 6 : 10),
          ),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2), // Aumentado de 0.12 para 0.2 - mais vivo
            borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : (adaptive.isDesktop ? 10 : 14)),
            border: Border.all(
              color: statusColor.withOpacity(0.7), // Aumentado de 0.4 para 0.7 - mais vivo
              width: 2.0, // Aumentado de 1.5 para 2.0
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                statusIcon,
                size: adaptive.isMobile ? 14 : (adaptive.isDesktop ? 12 : 16),
                color: statusColor,
              ),
              SizedBox(width: adaptive.isMobile ? 8 : (adaptive.isDesktop ? 6 : 10)),
              Text(
                statusLabel.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: adaptive.isMobile ? 11 : (adaptive.isDesktop ? 10 : 12),
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        // Badge de pedidos pendentes
        if (pedidosPendentes != null && pedidosPendentes > 0) ...[
          SizedBox(height: adaptive.isDesktop ? 6 : 8),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: adaptive.isMobile ? 10 : (adaptive.isDesktop ? 8 : 12),
              vertical: adaptive.isMobile ? 6 : (adaptive.isDesktop ? 5 : 7),
            ),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(adaptive.isMobile ? 10 : (adaptive.isDesktop ? 8 : 12)),
              border: Border.all(
                color: Colors.orange.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sync_problem,
                  size: adaptive.isMobile ? 13 : (adaptive.isDesktop ? 11 : 15),
                  color: Colors.orange.shade700,
                ),
                SizedBox(width: adaptive.isMobile ? 6 : (adaptive.isDesktop ? 5 : 8)),
                Text(
                  '$pedidosPendentes',
                  style: GoogleFonts.inter(
                    fontSize: adaptive.isMobile ? 11 : (adaptive.isDesktop ? 10 : 12),
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
