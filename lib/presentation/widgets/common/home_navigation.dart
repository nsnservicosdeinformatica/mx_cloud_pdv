import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/services_provider.dart';
import '../../../screens/home/home_unified_screen.dart';
import '../../../screens/mesas_comandas/mesas_comandas_screen.dart';
import '../../../screens/pedidos/pedidos_screen.dart';
import '../../../screens/balcao/balcao_screen.dart';
import '../../../screens/patio/patio_screen.dart';
import '../../../screens/profile/profile_screen.dart';

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
    // Usa WidgetsBinding para garantir que o contexto está pronto
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSetor();
    });
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

  List<NavigationItem> _getNavigationItems() {
    // Home unificada para todos os setores
    final homeItem = NavigationItem(
      icon: Icons.home,
      label: 'Home',
      screen: const HomeUnifiedScreen(),
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
        NavigationItem(
          icon: Icons.person,
          label: 'Perfil',
          screen: const ProfileScreen(),
        ),
      ];
    }

    switch (_setor) {
      case 2: // Restaurante
        final items = [
          homeItem,
          NavigationItem(
            icon: Icons.table_restaurant,
            label: 'Mesas e Comandas',
            screen: const MesasComandasScreen(hideAppBar: true),
          ),
        ];
        
        // Adiciona item "Balcão" para venda balcão
        // Não usa const para garantir que a tela seja reconstruída quando necessário
        items.add(
          NavigationItem(
            icon: Icons.shopping_cart,
            label: 'Balcão',
            screen: BalcaoScreen(hideAppBar: true),
          ),
        );
        
        items.add(
          NavigationItem(
            icon: Icons.person,
            label: 'Perfil',
            screen: const ProfileScreen(),
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
          NavigationItem(
            icon: Icons.person,
            label: 'Perfil',
            screen: const ProfileScreen(),
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
          NavigationItem(
            icon: Icons.person,
            label: 'Perfil',
            screen: const ProfileScreen(),
          ),
        ];
    }
  }

  /// Retorna a cor específica para cada item de navegação
  Color _getItemColor(NavigationItem item) {
    // Cores vibrantes para cada botão
    final colorMap = {
      'Home': const Color(0xFF6366F1), // Indigo
      'Pedidos': const Color(0xFF10B981), // Emerald
      'Mesas e Comandas': const Color(0xFFFF6B6B), // Coral
      'Balcão': const Color(0xFFF59E0B), // Amber
      'Pátio': const Color(0xFF4DABF7), // Azul brilhante
      'Perfil': const Color(0xFF8B5CF6), // Purple
    };

    return colorMap[item.label] ?? Theme.of(context).colorScheme.primary;
  }

  /// Constrói o conteúdo da barra de navegação inferior
  Widget _buildBottomNavigationContent(
    BuildContext context,
    List<NavigationItem> navigationItems,
  ) {
    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    // ✅ Botão inteiro colorido
                    color: isActive
                        ? itemColor // Cor completa quando ativo
                        : itemColor.withOpacity(0.15), // Cor suave quando inativo
                    borderRadius: BorderRadius.circular(16),
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
                        size: isActive ? 26 : 24,
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: isActive ? 12 : 11,
                          color: isActive
                              ? Colors.white // Texto branco quando botão está colorido
                              : itemColor, // Texto colorido quando botão está suave
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
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
        final navigationItems = _getNavigationItems();

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
