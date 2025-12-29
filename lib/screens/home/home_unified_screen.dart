import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/services_provider.dart';
import '../../data/models/home/home_widget_type.dart';
import '../../data/models/home/home_widget_type.dart' show HomeWidgetAvailability;
import '../../data/models/home/home_widget_config.dart';
import '../../data/repositories/home_widget_config_repository.dart';
import '../../data/repositories/pedido_local_repository.dart';
import '../../data/models/local/pedido_local.dart';
import '../../data/models/local/sync_status_pedido.dart';
import '../../widgets/home/draggable_resizable_widget.dart';
import '../../widgets/home/grid_layout_manager.dart';
import '../sync/sync_dialog.dart';
import '../pedidos/pedidos_sync_screen.dart';
import '../mesas_comandas/mesas_comandas_screen.dart';
import '../mesas_comandas/mesas_comandas_screen.dart' show TipoVisualizacao;
import '../pedidos/restaurante/novo_pedido_restaurante_screen.dart';
import '../pedidos/restaurante/dialogs/selecionar_mesa_comanda_dialog.dart';
import '../patio/patio_screen.dart';
import '../pedidos/pedidos_screen.dart';
import '../profile/profile_screen.dart';

/// Tela de home unificada e personalizável
class HomeUnifiedScreen extends StatefulWidget {
  const HomeUnifiedScreen({super.key});

  @override
  State<HomeUnifiedScreen> createState() => _HomeUnifiedScreenState();
}

class _HomeUnifiedScreenState extends State<HomeUnifiedScreen> {
  final _configRepo = HomeWidgetConfigRepository();
  final _pedidoRepo = PedidoLocalRepository();
  int? _setor;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isAbrindoNovoPedido = false; // Proteção contra múltiplos cliques
  final GlobalKey _containerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
      final setor = await authProvider.getSetorOrganizacao();
      
      if (mounted) {
        setState(() {
          _setor = setor;
        });
        
        // Inicializa configuração padrão se necessário
        await _configRepo.initializeDefaultConfig(setor);
        await _pedidoRepo.getAll(); // Garante que a box está aberta
        
        // Carrega configuração do restaurante (cacheada no ServicesProvider)
        // Não bloqueia a UI se falhar
        servicesProvider.carregarConfiguracaoRestaurante().catchError((e) {
          debugPrint('⚠️ Erro ao carregar configuração do restaurante: $e');
        });
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleWidgetTap(HomeWidgetType type) {
    switch (type) {
      case HomeWidgetType.sincronizarProdutos:
        _mostrarDialogSincronizacao();
        break;
      case HomeWidgetType.sincronizarVendas:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const PedidosSyncScreen(),
          ),
        );
        break;
      case HomeWidgetType.mesas:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AdaptiveLayout(
              child: const MesasComandasScreen(
                tipoInicial: TipoVisualizacao.mesas,
              ),
            ),
          ),
        );
        break;
      case HomeWidgetType.comandas:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AdaptiveLayout(
              child: const MesasComandasScreen(
                tipoInicial: TipoVisualizacao.comandas,
              ),
            ),
          ),
        );
        break;
      case HomeWidgetType.configuracoes:
        // TODO: Navegar para tela de configurações
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações em desenvolvimento')),
        );
        break;
      case HomeWidgetType.perfil:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AdaptiveLayout(
              child: const ProfileScreen(),
            ),
          ),
        );
        break;
      case HomeWidgetType.realizarPedido:
        _abrirNovoPedido();
        break;
      case HomeWidgetType.patio:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AdaptiveLayout(
              child: const PatioScreen(),
            ),
          ),
        );
        break;
      case HomeWidgetType.pedidos:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AdaptiveLayout(
              child: const PedidosScreen(),
            ),
          ),
        );
        break;
    }
  }

  Future<void> _abrirNovoPedido() async {
    // Proteção contra múltiplos cliques
    if (_isAbrindoNovoPedido) {
      debugPrint('⚠️ [HomeUnifiedScreen] Já está abrindo novo pedido, ignorando clique');
      return;
    }
    
    setState(() {
      _isAbrindoNovoPedido = true;
    });
    
    try {
      if (_setor == 2) {
        // Restaurante: mostra dialog para selecionar mesa/comanda
        // Venda avulsa permite sem mesa/comanda (independente da configuração)
        final resultado = await SelecionarMesaComandaDialog.show(
          context,
          permiteVendaAvulsa: true, // Sempre permite venda avulsa
        );
        if (resultado != null && mounted) {
          // Usa o método show() que detecta automaticamente se deve usar modal ou tela cheia
          await NovoPedidoRestauranteScreen.show(
            context,
            mesaId: resultado.mesa?.id,
            comandaId: resultado.comanda?.id,
          );
        }
      } else {
        // Outros setores: TODO implementar tela de pedido genérica
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Realizar pedido em desenvolvimento')),
        );
      }
    } finally {
      // Sempre libera o flag, mesmo se houver erro
      if (mounted) {
        setState(() {
          _isAbrindoNovoPedido = false;
        });
      }
    }
  }

  void _mostrarDialogSincronizacao() {
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    final syncProvider = servicesProvider.syncProvider;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SyncDialog(syncProvider: syncProvider),
    );
  }

  int? _getBadgeCount(HomeWidgetType type) {
    if (type == HomeWidgetType.sincronizarVendas) {
      if (!Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
        return null;
      }
      final box = Hive.box<PedidoLocal>(PedidoLocalRepository.boxName);
      return box.values
          .where((p) => p.syncStatus != SyncStatusPedido.sincronizado)
          .length;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null || _isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _configRepo.initializeDefaultConfig(_setor),
          builder: (context, snapshot) {
            if (!Hive.isBoxOpen(HomeWidgetConfigRepository.boxName)) {
              return const Center(child: CircularProgressIndicator());
            }

            return Consumer<ServicesProvider>(
              builder: (context, servicesProvider, _) {
                return ValueListenableBuilder<Box<HomeWidgetUserConfig>>(
                  valueListenable: _configRepo.listenable(),
                  builder: (context, box, _) {
                    final configRestaurante = servicesProvider.configuracaoRestaurante;
                    
                    // Filtra widgets baseado na configuração do restaurante
                    var availableWidgets = HomeWidgetAvailability.getAvailableWidgets(_setor);
                    
                    // Se configuração é PorMesa, remove widget de comandas
                    if (_setor == 2 && configRestaurante != null && configRestaurante.controlePorMesa) {
                      availableWidgets = availableWidgets.where((type) => type != HomeWidgetType.comandas).toList();
                    }
                
                final configs = availableWidgets.map((type) {
                  final config = box.get(type.index);
                  return config ?? HomeWidgetUserConfig(
                    type: type,
                    enabled: true,
                    order: type.index,
                    size: HomeWidgetSize.medio,
                  );
                }).where((config) => config.enabled).toList()
                  ..sort((a, b) => a.order.compareTo(b.order));

                if (configs.isEmpty) {
                  return Center(
                    child: Text(
                      'Nenhum widget habilitado',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    // Header com botão de edição e configuração
                    Padding(
                      padding: EdgeInsets.all(adaptive.isMobile ? 16 : adaptive.getPadding()),
                      child: Row(
                        children: [
                          Expanded(child: _buildHeader(context, adaptive)),
                          // Botão de arranjo automático (só aparece quando está editando)
                          if (_isEditing)
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withOpacity(0.2),
                                  ),
                                ),
                                child: Icon(
                                  Icons.auto_awesome,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                              ),
                              onPressed: () {
                                // Obtém o tamanho disponível do LayoutBuilder
                                final renderBox = _containerKey.currentContext?.findRenderObject() as RenderBox?;
                                if (renderBox != null) {
                                  final size = renderBox.size;
                                  _arrangeWidgetsAutomatically(configs, size.width, size.height);
                                }
                              },
                              tooltip: 'Arranjo automático',
                            ),
                          if (_isEditing) const SizedBox(width: 8),
                          // Botão de editar layout
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _isEditing 
                                    ? AppTheme.primaryColor 
                                    : AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.primaryColor.withOpacity(0.2),
                                ),
                              ),
                              child: Icon(
                                _isEditing ? Icons.check : Icons.edit,
                                color: _isEditing ? Colors.white : AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _isEditing = !_isEditing;
                              });
                            },
                            tooltip: _isEditing ? 'Finalizar edição' : 'Editar layout',
                          ),
                        ],
                      ),
                    ),
                    // Área de widgets com grid automático e scroll
                    Expanded(
                      child: LayoutBuilder(
                        key: _containerKey,
                        builder: (context, constraints) {
                          // Usa um tamanho base fixo para o grid (evita mudanças durante movimento)
                          const baseCanvasWidth = 1200.0;
                          const baseCanvasHeight = 800.0;
                          
                          // Usa o tamanho disponível da viewport como referência
                          final availableWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0 
                              ? constraints.maxWidth 
                              : baseCanvasWidth;
                          final availableHeight = constraints.maxHeight.isFinite && constraints.maxHeight > 0 
                              ? constraints.maxHeight 
                              : baseCanvasHeight;
                          
                          // Calcula tamanho dinâmico do canvas baseado nas posições dos widgets
                          // As posições são em porcentagem (0.0 a 1.0)
                          double maxRight = 0;
                          double maxBottom = 0;
                          const padding = 100.0; // Padding menor para evitar espaço desnecessário
                          
                          // Calcula posições máximas dos widgets
                          if (configs.isNotEmpty) {
                            for (final config in configs) {
                              final position = config.positionOrDefault;
                              // Posições são em porcentagem, então x + width dá a posição final em %
                              final right = position.x + position.width;
                              final bottom = position.y + position.height;
                              if (right > maxRight) maxRight = right;
                              if (bottom > maxBottom) maxBottom = bottom;
                            }
                          }
                          
                          // Converte de porcentagem para pixels usando o tamanho base fixo
                          // Isso garante que o grid seja estável
                          final requiredWidth = maxRight * baseCanvasWidth;
                          final requiredHeight = maxBottom * baseCanvasHeight;
                          
                          // Se todos os widgets cabem na viewport, usa exatamente o tamanho disponível
                          // Caso contrário, adiciona padding para permitir movimento
                          final canvasWidth = configs.isNotEmpty 
                              ? (requiredWidth <= availableWidth 
                                  ? availableWidth 
                                  : requiredWidth + padding)
                              : availableWidth;
                          final canvasHeight = configs.isNotEmpty
                              ? (requiredHeight <= availableHeight 
                                  ? availableHeight 
                                  : requiredHeight + padding)
                              : availableHeight;
                          
                          // Define grid de 12 colunas com tamanho de célula fixo
                          // Usa o tamanho base para manter estabilidade - NUNCA muda
                          const gridColumns = 12;
                          const cellWidth = baseCanvasWidth / gridColumns; // Tamanho fixo baseado no canvas base
                          const cellHeight = 100.0;
                          final gridRows = (baseCanvasHeight / cellHeight).ceil(); // Fixo baseado no tamanho base
                          
                          final gridManager = GridLayoutManager(
                            columns: gridColumns,
                            rows: gridRows,
                            cellWidth: cellWidth,
                            cellHeight: cellHeight,
                          );

                          // Container com tamanho dinâmico para o canvas
                          // Mas usa tamanho base para conversões de grid
                          final canvasSize = Size(canvasWidth, canvasHeight);
                          final baseCanvasSize = Size(baseCanvasWidth, baseCanvasHeight);

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SizedBox(
                                width: canvasWidth,
                                height: canvasHeight,
                                child: Stack(
                                  children: configs.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final config = entry.value;
                                    final badgeCount = _getBadgeCount(config.type);
                                    return DraggableResizableWidget(
                                      config: config,
                                      badgeCount: badgeCount,
                                      onTap: () => _handleWidgetTap(config.type),
                                      onPositionChanged: (newPosition) {
                                        _updateWidgetPosition(config.type, newPosition);
                                      },
                                      isEditing: _isEditing,
                                      parentSize: canvasSize,
                                      baseSize: baseCanvasSize,
                                      gridManager: gridManager,
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _updateWidgetPosition(
    HomeWidgetType changedType,
    HomeWidgetPosition newPosition,
  ) async {
    // Apenas atualiza a posição do widget que foi movido
    // Não tenta reorganizar outros widgets - deixa livre para o usuário posicionar como quiser
    if (!Hive.isBoxOpen(HomeWidgetConfigRepository.boxName)) return;
    
    final box = Hive.box<HomeWidgetUserConfig>(HomeWidgetConfigRepository.boxName);
    final config = box.get(changedType.index);
    
    if (config != null) {
      await _configRepo.updateConfig(
        config.copyWith(position: newPosition),
      );
    }
  }

  Future<void> _arrangeWidgetsAutomatically(
    List<HomeWidgetUserConfig> configs,
    double availableWidth,
    double availableHeight,
  ) async {
    if (configs.isEmpty) return;
    
    const baseCanvasWidth = 1200.0;
    const baseCanvasHeight = 800.0;
    const margin = 4.0;
    const padding = 16.0;
    
    // Calcula quantas colunas cabem na tela (baseado no tamanho médio dos widgets)
    // Assumindo widgets médios de ~200px de largura
    final widgetWidth = 200.0;
    final cols = ((availableWidth - padding * 2) / (widgetWidth + margin * 2)).floor().clamp(1, 12);
    
    // Calcula altura padrão dos widgets
    final widgetHeight = 140.0;
    final rowHeight = widgetHeight + margin * 2;
    
    // Organiza os widgets em grid
    for (int i = 0; i < configs.length; i++) {
      final row = (i / cols).floor();
      final col = i % cols;
      
      // Calcula posição em porcentagem do canvas base
      final x = (col * (widgetWidth + margin * 2) + padding) / baseCanvasWidth;
      final y = (row * rowHeight + padding) / baseCanvasHeight;
      final width = widgetWidth / baseCanvasWidth;
      final height = widgetHeight / baseCanvasHeight;
      
      final newPosition = HomeWidgetPosition(
        x: x.clamp(0.0, 1.0),
        y: y.clamp(0.0, 1.0),
        width: width.clamp(0.05, 1.0),
        height: height.clamp(0.05, 1.0),
      );
      
      await _configRepo.updateConfig(
        configs[i].copyWith(position: newPosition),
      );
    }
  }


  Widget _buildHeader(BuildContext context, AdaptiveLayoutProvider adaptive) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(adaptive.isMobile ? 12 : 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withOpacity(0.15),
                AppTheme.primaryColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(adaptive.isMobile ? 14 : 16),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.dashboard,
            color: AppTheme.primaryColor,
            size: adaptive.isMobile ? 28 : 32,
          ),
        ),
        SizedBox(width: adaptive.isMobile ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Painel Principal',
                style: GoogleFonts.inter(
                  fontSize: adaptive.isMobile ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: adaptive.isMobile ? 2 : 4),
              Text(
                'Acesso rápido às principais funcionalidades',
                style: GoogleFonts.inter(
                  fontSize: adaptive.isMobile ? 13 : 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

