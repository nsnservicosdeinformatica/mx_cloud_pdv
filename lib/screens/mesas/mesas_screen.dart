import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../presentation/providers/services_provider.dart';
import '../../presentation/providers/mesas_provider.dart';
import '../../data/models/modules/restaurante/mesa_list_item.dart';
import '../../data/models/local/pedido_local.dart';
import '../../data/models/local/sync_status_pedido.dart';
import '../../data/repositories/pedido_local_repository.dart';
import 'detalhes_mesa_screen.dart';
import 'detalhes_produtos_mesa_screen.dart';
import '../../models/mesas/entidade_produtos.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tela de listagem de mesas (Restaurante)
class MesasScreen extends StatefulWidget {
  /// Se deve ocultar o AppBar (usado quando acessada via bottom navigation)
  final bool hideAppBar;

  const MesasScreen({
    super.key,
    this.hideAppBar = false,
  });

  @override
  State<MesasScreen> createState() => _MesasScreenState();
}

class _MesasScreenState extends State<MesasScreen> {
  late MesasProvider _provider;
  final TextEditingController _searchController = TextEditingController();

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
    
    _searchController.addListener(_onSearchChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Inicializa o provider (configura listeners e carrega mesas)
      _provider.initialize();
    });
  }
  
  void _onSearchChanged() {
    _provider.filterMesas(_searchController.text);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _provider.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'livre':
        return AppTheme.successColor; // Verde
      case 'ocupada':
        return AppTheme.warningColor; // Laranja/Amarelo - não é erro, é ocupação normal
      case 'reservada':
        return AppTheme.infoColor; // Azul
      case 'manutencao':
        return AppTheme.errorColor; // Vermelho - realmente um problema
      case 'suspensa':
        return AppTheme.textSecondary; // Cinza
      default:
        return AppTheme.textSecondary;
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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
                  title: 'Mesas',
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.textPrimary,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => _provider.loadMesas(refresh: true),
                      tooltip: 'Atualizar',
                      color: AppTheme.textPrimary,
                    ),
                  ],
                ),
      body: Column(
        children: [
          // Campo de pesquisa
          Container(
            padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
            color: Colors.white,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(adaptive.isMobile ? 14 : 16),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) {
                  _provider.filterMesas(_searchController.text);
                },
                decoration: InputDecoration(
                  hintText: 'Pesquisar por número da mesa...',
                  hintStyle: GoogleFonts.inter(
                    color: Colors.grey.shade500,
                    fontSize: adaptive.isMobile ? 14 : 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey.shade400,
                    size: adaptive.isMobile ? 20 : 22,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.grey.shade400,
                            size: adaptive.isMobile ? 20 : 22,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _provider.filterMesas('');
                          },
                        )
                      : const SizedBox.shrink(),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: adaptive.isMobile ? 16 : 20,
                    vertical: adaptive.isMobile ? 14 : 16,
                  ),
                ),
                style: GoogleFonts.inter(
                  fontSize: adaptive.isMobile ? 15 : 16,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          // Lista de mesas - Layout responsivo
          Expanded(
            child: adaptive.isMobile
                ? _buildMobileLayout(adaptive)
                : _buildDesktopLayout(adaptive),
          ),
        ],
      ),
        );
      },
    );
  }


  /// Calcula o número de colunas dinamicamente baseado na largura disponível
  /// Mantém um tamanho mínimo fixo para os cards (mais compacto)
  int _calculateColumnsCount(AdaptiveLayoutProvider adaptive, double availableWidth) {
    if (adaptive.isMobile) {
      return 2; // Mobile sempre 2 colunas
    }
    
    // Tamanho mínimo desejado para cada card (incluindo espaçamento) - reduzido para cards menores
    const double minCardWidth = 140.0; // Largura mínima do card (reduzida)
    const double spacing = 12.0; // Espaçamento entre cards
    const double padding = 24.0 * 2; // Padding lateral total
    
    // Calcula quantos cards cabem
    final double usableWidth = availableWidth - padding;
    final int columns = (usableWidth / (minCardWidth + spacing)).floor();
    
    // Garante mínimo de 2 e máximo razoável
    return columns.clamp(2, 10);
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

    // Tamanhos responsivos - design iconizado e compacto
    final isDesktop = adaptive.isDesktop;
    final cardPadding = isDesktop ? 8.0 : (adaptive.isMobile ? 8.0 : 10.0);
    final borderRadius = isDesktop ? 14.0 : (adaptive.isMobile ? 14.0 : 16.0);
    final iconSize = isDesktop ? 28.0 : (adaptive.isMobile ? 30.0 : 32.0);
    final numeroSize = isDesktop ? 20.0 : (adaptive.isMobile ? 22.0 : 24.0);

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
        borderRadius: BorderRadius.circular(borderRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.05)
                : statusColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isSelected 
                  ? AppTheme.primaryColor
                  : statusColor.withOpacity(0.4),
              width: isSelected ? 2.5 : 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppTheme.primaryColor.withOpacity(0.2)
                    : statusColor.withOpacity(0.15),
                blurRadius: isSelected ? 16 : 10,
                offset: Offset(0, isSelected ? 4 : 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Conteúdo principal - layout iconizado, centralizado e ocupando mais espaço
              Center(
                child: Padding(
                  padding: EdgeInsets.all(cardPadding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Ícone centralizado - elemento principal iconizado
                      Container(
                        padding: EdgeInsets.all(isDesktop ? 8 : (adaptive.isMobile ? 9 : 10)),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          statusIcon,
                          size: iconSize,
                          color: statusColor,
                        ),
                      ),
                      
                      SizedBox(height: isDesktop ? 8 : (adaptive.isMobile ? 10 : 12)),
                      
                      // Número da mesa - discreto mas visível, com constraints para não sair
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: double.infinity,
                        ),
                        child: Text(
                          temNumero ? numeroMesa : '?',
                          style: GoogleFonts.inter(
                            fontSize: numeroSize,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            height: 1.0,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      SizedBox(height: isDesktop ? 6 : 8),
                      
                      // Label de status - texto pequeno e discreto, com constraints
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: double.infinity,
                        ),
                        child: Text(
                          statusLabel.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: isDesktop ? 9 : 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Badge de pedidos pendentes (se houver) - posicionado no canto superior direito
              // O Provider já mantém o status atualizado via ListenableBuilder
              Builder(
                builder: (context) {
                  final pedidosPendentes = _provider.getPedidosPendentesCount(mesa.id);
                  if (pedidosPendentes > 0) {
                    return Positioned(
                      top: cardPadding * 0.5,
                      right: cardPadding * 0.5,
                      child: Container(
                        padding: EdgeInsets.all(isDesktop ? 5 : 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$pedidosPendentes',
                          style: GoogleFonts.inter(
                            fontSize: isDesktop ? 9 : 10,
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

  /// Layout para mobile (comportamento atual)
  Widget _buildMobileLayout(AdaptiveLayoutProvider adaptive) {
    return Container(
      color: Colors.white,
      child: _provider.errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _provider.errorMessage!,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _provider.loadMesas(refresh: true),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            )
          : _provider.isLoading && _provider.mesas.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _provider.filteredMesas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchController.text.isNotEmpty
                                ? Icons.search_off
                                : Icons.table_restaurant_outlined,
                            size: 64,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'Nenhuma mesa encontrada com número "${_searchController.text}"'
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
                    child: GridView.builder(
                      padding: EdgeInsets.all(adaptive.isMobile ? 12 : 24),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: adaptive.isMobile ? 3 : 3,
                        crossAxisSpacing: adaptive.isMobile ? 8 : 16,
                        mainAxisSpacing: adaptive.isMobile ? 8 : 16,
                        childAspectRatio: adaptive.isMobile ? 1.0 : 1.05,
                      ),
                      itemCount: _provider.filteredMesas.length,
                      itemBuilder: (context, index) {
                        final mesa = _provider.filteredMesas[index];
                          return _buildMesaCard(mesa, adaptive);
                        },
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: false,
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
            // Coluna esquerda: GridView de mesas
            Expanded(
              flex: 4, // 40% da largura
              child: Container(
                color: Colors.white,
                child: _provider.errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: AppTheme.errorColor,
                            ),
                            const SizedBox(height: 16),
                              Text(
                                _provider.errorMessage!,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => _provider.loadMesas(refresh: true),
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      )
                    : _provider.isLoading && _provider.mesas.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : _provider.filteredMesas.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _searchController.text.isNotEmpty
                                          ? Icons.search_off
                                          : Icons.table_restaurant_outlined,
                                      size: 64,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchController.text.isNotEmpty
                                          ? 'Nenhuma mesa encontrada com número "${_searchController.text}"'
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
                          child: GridView.builder(
                            padding: EdgeInsets.all(adaptive.isMobile ? 16 : 24),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columnsCount,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: adaptive.isDesktop ? 1.0 : 1.05,
                            ),
                            itemCount: _provider.filteredMesas.length,
                            itemBuilder: (context, index) {
                              final mesa = _provider.filteredMesas[index];
                              final isSelected = _provider.selectedMesa?.id == mesa.id;
                                    return _buildMesaCard(mesa, adaptive, isSelected: isSelected);
                                  },
                                  addAutomaticKeepAlives: false,
                                  addRepaintBoundaries: false,
                                ),
                              ),
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
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : (adaptive.isDesktop ? 10 : 14)),
            border: Border.all(
              color: statusColor.withOpacity(0.4),
              width: 1.5,
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
