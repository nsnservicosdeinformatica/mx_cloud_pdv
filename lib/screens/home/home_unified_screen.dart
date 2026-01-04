import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/config/connection_config_service.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/services_provider.dart';
import '../../data/models/home/home_widget_type.dart';
import '../../data/models/home/home_widget_type.dart' show HomeWidgetAvailability;
import '../../data/models/home/home_widget_config.dart';
import '../../data/repositories/home_widget_config_repository.dart';
import '../../data/repositories/pedido_local_repository.dart';
import '../../data/models/local/pedido_local.dart';
import '../../data/models/local/sync_status_pedido.dart';
import '../sync/sync_dialog.dart';
import '../sync/api_local_sync_dialog.dart';
import '../pedidos/pedidos_sync_screen.dart';
import '../mesas_comandas/mesas_comandas_screen.dart';
import '../mesas_comandas/mesas_comandas_screen.dart' show TipoVisualizacao;
import '../pedidos/restaurante/novo_pedido_restaurante_screen.dart';
import '../dialogs/selecionar_mesa_comanda_dialog.dart';
import '../patio/patio_screen.dart';
import '../pedidos/pedidos_screen.dart';
import '../profile/profile_screen.dart';

/// Tela de home unificada e personalizável
class HomeUnifiedScreen extends StatefulWidget {
  final ValueNotifier<int>? navigationIndexNotifier;
  
  const HomeUnifiedScreen({
    super.key,
    this.navigationIndexNotifier,
  });

  @override
  State<HomeUnifiedScreen> createState() => _HomeUnifiedScreenState();
}

class _HomeUnifiedScreenState extends State<HomeUnifiedScreen> {
  final _configRepo = HomeWidgetConfigRepository();
  final _pedidoRepo = PedidoLocalRepository();
  int? _setor;
  bool _isLoading = true;
  bool _isAbrindoNovoPedido = false; // Proteção contra múltiplos cliques

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
          
          // Após a inicialização estar completa, verifica sincronização
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _verificarESincronizar(servicesProvider);
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

  /// Verifica se precisa sincronizar e sincroniza automaticamente após inicialização completa
  void _verificarESincronizar(ServicesProvider servicesProvider) {
    if (!mounted) return;
    
    final syncProvider = servicesProvider.syncProvider;
    
    // Verifica se precisa sincronizar (retorna true se nunca sincronizou)
    syncProvider.verificarSePrecisaSincronizar().then((precisaSync) {
      if (!mounted) return;
      
      if (precisaSync) {
        final ultimaSync = syncProvider.ultimaSincronizacao;
        final isPrimeiraVez = ultimaSync == null;
        
        debugPrint('🔄 [Home] Sincronização necessária (última sync: ${ultimaSync ?? "nunca"}), iniciando sincronização automática...');
        debugPrint('🔄 [Home] ${isPrimeiraVez ? "Primeira sincronização - forçando" : "Sincronização automática"}...');
        
        // Mostra o dialog de sincronização para exibir o progresso
        // Se é primeira vez, força sincronização
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => SyncDialog(
            syncProvider: syncProvider,
            forcar: isPrimeiraVez,
          ),
        );
      } else {
        final ultimaSync = syncProvider.ultimaSincronizacao;
        debugPrint('✅ [Home] Sincronização não necessária ou já realizada recentemente (última sync: $ultimaSync)');
      }
    }).catchError((e) {
      debugPrint('⚠️ Erro ao verificar necessidade de sincronização: $e');
    });
  }

  // Método será usado na próxima etapa quando implementarmos o novo layout
  // ignore: unused_element
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

  Future<void> _mostrarDialogSincronizacao() async {
    // Mostra dialog de confirmação primeiro
    final confirmado = await AppDialog.showConfirm(
      context: context,
      title: 'Confirmar Sincronização',
      message: 'A sincronização irá atualizar os preços e produtos no dispositivo. '
          'Esta ação pode alterar os valores dos produtos cadastrados.\n\n'
          'Deseja continuar?',
      confirmText: 'Sincronizar',
      cancelText: 'Cancelar',
      icon: Icons.sync,
      iconColor: const Color(0xFF0284C7),
      confirmColor: const Color(0xFF0284C7),
    );

    // Se o usuário confirmou, inicia a sincronização
    if (confirmado == true && mounted) {
    final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
    final syncProvider = servicesProvider.syncProvider;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SyncDialog(syncProvider: syncProvider),
    );
    }
  }

  Future<void> _mostrarDialogSincronizacaoApiLocal() async {
    // Mostra dialog de confirmação primeiro
    final confirmado = await AppDialog.showConfirm(
      context: context,
      title: 'Confirmar Sincronização do Servidor',
      message: 'A sincronização irá buscar dados atualizados do servidor cloud para a API local. '
          'Esta ação pode demorar alguns minutos.\n\n'
          'Deseja continuar?',
      confirmText: 'Sincronizar',
      cancelText: 'Cancelar',
      icon: Icons.cloud_sync,
      iconColor: const Color(0xFF10B981),
      confirmColor: const Color(0xFF10B981),
    );

    // Se o usuário confirmou, inicia a sincronização
    if (confirmado == true && mounted) {
      final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
      final apiLocalSyncService = servicesProvider.apiLocalSyncService;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ApiLocalSyncDialog(
          apiLocalSyncService: apiLocalSyncService,
        ),
      );
    }
  }

  // Método será usado na próxima etapa quando implementarmos o novo layout
  // ignore: unused_element
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
      body: FutureBuilder<void>(
          future: _configRepo.initializeDefaultConfig(_setor),
          builder: (context, snapshot) {
            if (!Hive.isBoxOpen(HomeWidgetConfigRepository.boxName)) {
              return const Center(child: CircularProgressIndicator());
            }

            return Consumer<ServicesProvider>(
              builder: (context, servicesProvider, _) {
                // Escuta mudanças no SyncProvider para atualizar a UI quando sincronização terminar
                return ListenableBuilder(
                  listenable: servicesProvider.syncProvider,
                  builder: (context, _) {
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

              // Grid de botões funcionais - preenche 100% da tela até o bottom navigation
              return _buildFunctionalButtonsGrid(context, adaptive, servicesProvider);
                      },
                    );
                  },
                );
              },
            );
          },
      ),
    );
  }



  Widget _buildFunctionalButtonsGrid(
    BuildContext context,
    AdaptiveLayoutProvider adaptive,
    ServicesProvider servicesProvider,
  ) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final syncProvider = servicesProvider.syncProvider;
    final user = authProvider.user;
    final vendasPendentes = _getBadgeCount(HomeWidgetType.sincronizarVendas) ?? 0;
    final ultimaSync = syncProvider.ultimaSincronizacao;
    final serverUrl = ConnectionConfigService.getServerUrl() ?? 'Não configurado';
    final serverStatus = ConnectionConfigService.isConfigured() ? 'Conectado' : 'Desconectado';
    final isLocalServer = ConnectionConfigService.getCurrentConfig()?.isLocal ?? false;

    // Lista de botões funcionais
    final buttons = <_ButtonData>[];
    
    // Se for servidor local, adiciona botão de sincronização da API local primeiro
    if (isLocalServer) {
      buttons.add(
        _ButtonData(
          title: 'Sincronizar Servidor',
          icon: Icons.cloud_sync,
          color: const Color(0xFF10B981), // Verde
          subtitle: 'Sincronizar dados do servidor cloud',
          onTap: _mostrarDialogSincronizacaoApiLocal,
        ),
      );
    }
    
    // Botão de sincronização do Hive (sempre presente)
    buttons.add(
      _ButtonData(
        title: 'Sincronização de Dados',
        icon: Icons.sync,
        color: const Color(0xFF0284C7), // Azul
        subtitle: ultimaSync != null
            ? 'Última sync: ${_formatDate(ultimaSync)}'
            : 'Nunca sincronizado',
        onTap: _mostrarDialogSincronizacao,
      ),
    );
    buttons.add(
      _ButtonData(
        title: 'Vendas Pendentes',
        icon: Icons.pending_actions,
        color: const Color(0xFFDC2626), // Vermelho
        subtitle: vendasPendentes > 0
            ? '$vendasPendentes ${vendasPendentes == 1 ? 'venda pendente' : 'vendas pendentes'}'
            : 'Todas sincronizadas',
        badge: vendasPendentes > 0 ? vendasPendentes : null,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const PedidosSyncScreen(),
            ),
          );
        },
      ),
    );
    buttons.add(
      _ButtonData(
        title: 'Impressoras',
        icon: Icons.print,
        color: const Color(0xFF7C3AED), // Roxo
        subtitle: 'Gerenciar impressoras',
        onTap: () {},
      ),
    );
    buttons.add(
      _ButtonData(
        title: 'Configuração do Servidor',
        icon: Icons.settings,
        color: const Color(0xFF059669), // Verde
        subtitle: '$serverUrl\nStatus: $serverStatus',
        status: serverStatus == 'Conectado',
        onTap: () {},
      ),
    );
    buttons.add(
      _ButtonData(
        title: 'Vendas Recentes',
        icon: Icons.receipt_long,
        color: const Color(0xFFD97706), // Amber
        subtitle: 'Visualizar vendas recentes',
        onTap: () {},
      ),
    );
    buttons.add(
      _ButtonData(
        title: 'Usuário Logado',
        icon: Icons.person,
        color: const Color(0xFF4F46E5), // Indigo
        subtitle: user?.name ?? 'Não identificado',
        onTap: () {
          // Navega para perfil usando uma rota que mantém o bottom navigation visível
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AdaptiveLayout(
                child: const ProfileScreen(),
              ),
              fullscreenDialog: false,
            ),
          );
        },
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcula número de colunas baseado no tamanho da tela
        final screenWidth = constraints.maxWidth;
        int columns;
        if (screenWidth < 600) {
          columns = 2; // Mobile: 2 colunas
        } else if (screenWidth < 1200) {
          columns = 3; // Tablet: 3 colunas
        } else {
          columns = 3; // Desktop: 3 colunas
        }

        // Calcula número de linhas necessárias
        final rows = (buttons.length / columns).ceil();
        
        // Calcula altura disponível e ajusta aspect ratio para ocupar 100%
        final availableHeight = constraints.maxHeight;
        final buttonHeight = availableHeight / rows;
        final buttonWidth = screenWidth / columns;
        final aspectRatio = buttonWidth / buttonHeight;

        return GridView.builder(
          padding: EdgeInsets.zero, // Sem margem
          physics: const NeverScrollableScrollPhysics(), // Desabilita scroll
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: aspectRatio, // Calculado dinamicamente para ocupar 100% da altura
            crossAxisSpacing: 0, // Sem espaçamento
            mainAxisSpacing: 0, // Sem espaçamento
          ),
          itemCount: buttons.length,
          itemBuilder: (context, index) {
            return _buildFunctionalButton(buttons[index], adaptive);
          },
        );
      },
    );
  }

  Widget _buildFunctionalButton(_ButtonData button, AdaptiveLayoutProvider adaptive) {
    return Material(
      color: button.color,
      child: InkWell(
        onTap: button.onTap,
        child: Container(
          padding: EdgeInsets.all(adaptive.isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: button.color,
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícone e badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    button.icon,
                    color: Colors.white,
                    size: adaptive.isMobile ? 32 : 40,
                  ),
                  if (button.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${button.badge}',
                        style: GoogleFonts.inter(
                          color: button.color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (button.status != null)
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: button.status! ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Título
              Text(
                button.title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: adaptive.isMobile ? 16 : 20,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Subtítulo
              Expanded(
                child: Text(
                  button.subtitle,
                style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: adaptive.isMobile ? 12 : 14,
                  fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Agora';
        }
        return '${difference.inMinutes}min atrás';
      }
      return '${difference.inHours}h atrás';
    } else if (difference.inDays == 1) {
      return 'Ontem';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d atrás';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

}

/// Classe auxiliar para dados dos botões funcionais
class _ButtonData {
  final String title;
  final IconData icon;
  final Color color;
  final String subtitle;
  final int? badge;
  final bool? status; // true = conectado, false = desconectado
  final VoidCallback onTap;

  _ButtonData({
    required this.title,
    required this.icon,
    required this.color,
    required this.subtitle,
    this.badge,
    this.status,
    required this.onTap,
  });
}

