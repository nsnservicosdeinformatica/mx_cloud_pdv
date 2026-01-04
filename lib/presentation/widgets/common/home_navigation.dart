import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/services_provider.dart';
import '../../../screens/home/home_unified_screen.dart';
import '../../../screens/mesas_comandas/mesas_comandas_screen.dart';
import '../../../screens/mesas/mesas_screen.dart';
import '../../../screens/comandas/comandas_screen.dart';
import '../../../screens/pedidos/pedidos_screen.dart';
import '../../../screens/balcao/balcao_screen.dart';
import '../../../screens/patio/patio_screen.dart';

/// Widget principal de navegação com bottom navigation bar
class HomeNavigation extends StatefulWidget {
  const HomeNavigation({super.key});

  @override
  State<HomeNavigation> createState() => _HomeNavigationState();
}

class _HomeNavigationState extends State<HomeNavigation> {
  int _currentIndex = 0;
  int? _setor;
  bool _isLoadingSetor = true;
  final ValueNotifier<int> _navigationIndexNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    // Inicializa o notifier com o índice inicial
    _navigationIndexNotifier.value = _currentIndex;
    // Listener para atualizar o índice quando o notifier mudar
    _navigationIndexNotifier.addListener(_onNavigationIndexChanged);
    // Usa WidgetsBinding para garantir que o contexto está pronto
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSetor();
    });
  }

  void _onNavigationIndexChanged() {
    if (mounted && _navigationIndexNotifier.value != _currentIndex) {
      setState(() {
        _currentIndex = _navigationIndexNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    _navigationIndexNotifier.removeListener(_onNavigationIndexChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Garante que configuração do restaurante está carregada se for setor restaurante
    if (_setor == 2) {
      final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
      if (!servicesProvider.configuracaoRestauranteCarregada) {
        servicesProvider.carregarConfiguracaoRestaurante().catchError((e) {
          debugPrint('⚠️ Erro ao carregar configuração do restaurante: $e');
        });
      }
    }
  }

  Future<void> _loadSetor() async {
    // Pequeno delay para garantir que o contexto está pronto
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (!mounted) return;
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Adiciona timeout para evitar travamento
      final setor = await authProvider.getSetorOrganizacao()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              print('Timeout ao carregar setor, usando padrão (Varejo)');
              return null;
            },
          );
      
      if (mounted) {
        setState(() {
          _setor = setor;
          _isLoadingSetor = false;
        });
        
        // Se for restaurante, carrega configuração
        if (setor == 2) {
          final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
          if (!servicesProvider.configuracaoRestauranteCarregada) {
            servicesProvider.carregarConfiguracaoRestaurante().catchError((e) {
              debugPrint('⚠️ Erro ao carregar configuração do restaurante: $e');
            });
          }
        }
      }
    } catch (e) {
      // Em caso de erro, usa o padrão (Varejo) e continua
      print('Erro ao carregar setor: $e');
      if (mounted) {
        setState(() {
          _setor = null; // Default para Varejo
          _isLoadingSetor = false;
        });
      }
    }
  }

  List<NavigationItem> _getNavigationItems(ServicesProvider? servicesProvider) {
    // Home unificada para todos os setores
    final homeItem = NavigationItem(
      icon: Icons.home,
      label: 'Home',
      screen: HomeUnifiedScreen(
        navigationIndexNotifier: _navigationIndexNotifier,
      ),
    );

    if (_setor == null) {
      // Default: Varejo
      return [
        homeItem,
        NavigationItem(
          icon: Icons.receipt_long,
          label: 'Pedidos',
          screen: const PedidosScreen(),
        ),
      ];
    }

    switch (_setor) {
      case 2: // Restaurante
        final items = [homeItem];
        
        // Verificar configuração do restaurante para determinar o item de navegação
        final config = servicesProvider?.configuracaoRestaurante;
        
        if (config != null) {
          if (config.isControlePorMesa) {
            // Apenas Mesa: mostrar apenas "Mesas"
            items.add(
              NavigationItem(
                icon: Icons.table_restaurant,
                label: 'Mesas',
                screen: const MesasScreen(hideAppBar: true),
              ),
            );
          } else if (config.isControlePorComanda) {
            // Apenas Comanda: mostrar apenas "Comandas"
            items.add(
              NavigationItem(
                icon: Icons.receipt_long,
                label: 'Comandas',
                screen: const ComandasScreen(hideAppBar: true),
              ),
            );
          } else if (config.isControlePorMesaOuComanda) {
            // Mesa ou Comanda: mostrar "Mesas e Comandas"
            items.add(
              NavigationItem(
                icon: Icons.table_restaurant,
                label: 'Mesas e Comandas',
                screen: const MesasComandasScreen(hideAppBar: true),
              ),
            );
          } else {
            // Fallback: se configuração inválida, mostra "Mesas e Comandas"
            items.add(
              NavigationItem(
                icon: Icons.table_restaurant,
                label: 'Mesas e Comandas',
                screen: const MesasComandasScreen(hideAppBar: true),
              ),
            );
          }
        } else {
          // Se configuração não carregada ainda, mostra "Mesas e Comandas" como padrão
          items.add(
          NavigationItem(
            icon: Icons.table_restaurant,
            label: 'Mesas e Comandas',
            screen: const MesasComandasScreen(hideAppBar: true),
          ),
          );
        }
        
        // Adiciona item "Balcão" para venda balcão
        // Não usa const para garantir que a tela seja reconstruída quando necessário
        items.add(
          NavigationItem(
            icon: Icons.shopping_cart,
            label: 'Balcão',
            screen: BalcaoScreen(hideAppBar: true),
          ),
        );
        
        return items;
      case 3: // Oficina
        return [
          homeItem,
          NavigationItem(
            icon: Icons.directions_car,
            label: 'Pátio',
            screen: const PatioScreen(),
          ),
        ];
      default: // Varejo (1 ou null)
        return [
          homeItem,
          NavigationItem(
            icon: Icons.receipt_long,
            label: 'Pedidos',
            screen: const PedidosScreen(),
          ),
        ];
    }
  }

  /// Retorna a cor específica para cada item de navegação
  Color _getItemColor(NavigationItem item) {
    // Cores mais fortes e vibrantes para cada botão
    final colorMap = {
      'Home': const Color(0xFF4F46E5), // Indigo mais forte
      'Pedidos': const Color(0xFF059669), // Emerald mais forte
      'Mesas': const Color(0xFFDC2626), // Vermelho mais forte
      'Comandas': const Color(0xFFDC2626), // Vermelho mais forte
      'Mesas e Comandas': const Color(0xFFDC2626), // Vermelho mais forte
      'Balcão': const Color(0xFFD97706), // Amber mais forte
      'Pátio': const Color(0xFF0284C7), // Azul mais forte
    };

    return colorMap[item.label] ?? Theme.of(context).colorScheme.primary;
  }

  /// Constrói o conteúdo da barra de navegação inferior
  Widget _buildBottomNavigationContent(
    BuildContext context,
    List<NavigationItem> navigationItems,
  ) {
    final content = Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: navigationItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isActive = _currentIndex == index;
          final itemColor = _getItemColor(item);

          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentIndex = index;
                  });
                  _navigationIndexNotifier.value = index;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    // ✅ Botão inteiro colorido sem bordas arredondadas
                    color: isActive
                        ? itemColor // Cor completa quando ativo
                        : itemColor.withOpacity(0.2), // Cor mais forte quando inativo
                    // Sombra forte para destacar botão ativo
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: itemColor.withOpacity(0.8),
                              blurRadius: 16,
                              offset: const Offset(0, -4),
                              spreadRadius: 3,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Ícone branco quando ativo, cor do botão quando inativo
                      Icon(
                        item.icon,
                        color: isActive
                            ? Colors.white // Ícone branco quando botão está colorido
                            : itemColor, // Ícone colorido quando botão está suave
                        size: 24, // Tamanho fixo
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: 11, // Tamanho fixo
                          color: isActive
                              ? Colors.white // Texto branco quando botão está colorido
                              : itemColor, // Texto colorido quando botão está suave
                          fontWeight: FontWeight.w600, // Peso fixo
                          height: 1.2,
                        ),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
    
    // Sempre usa SafeArea para evitar sobreposição com barras do sistema
    return SafeArea(
      top: false,
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Se ainda está carregando, mostra loading
    if (_isLoadingSetor) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Carregando...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Usa Consumer para reagir a mudanças na configuração do restaurante
    return Consumer<ServicesProvider>(
      builder: (context, servicesProvider, _) {
        final navigationItems = _getNavigationItems(servicesProvider);

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: navigationItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              // Passa o notifier para BalcaoScreen se for a tela balcão
              if (item.screen is BalcaoScreen) {
                return BalcaoScreen(
                  hideAppBar: (item.screen as BalcaoScreen).hideAppBar,
                  navigationIndexNotifier: _navigationIndexNotifier,
                  screenIndex: index,
                );
              }
              return item.screen;
            }).toList(),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: _buildBottomNavigationContent(context, navigationItems),
          ),
        );
      },
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final Widget screen;

  NavigationItem({
    required this.icon,
    required this.label,
    required this.screen,
  });
}
