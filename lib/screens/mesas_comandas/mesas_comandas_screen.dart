import 'package:flutter/material.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../mesas/mesas_screen.dart';
import '../comandas/comandas_screen.dart';
import '../../widgets/h4nd_loading.dart';

/// Tipo de visualização selecionada
enum TipoVisualizacao {
  mesas,
  comandas,
}

/// Tela unificada de Mesas e Comandas
/// Permite alternar entre visualização de mesas ou comandas
class MesasComandasScreen extends StatefulWidget {
  /// Se deve ocultar o AppBar (usado quando acessada via bottom navigation)
  final bool hideAppBar;
  /// Tipo inicial de visualização (opcional)
  final TipoVisualizacao? tipoInicial;
  /// ID da mesa/comanda para selecionar automaticamente ao carregar
  final String? entidadeId;

  const MesasComandasScreen({
    super.key,
    this.hideAppBar = false,
    this.tipoInicial,
    this.entidadeId,
  });

  @override
  State<MesasComandasScreen> createState() => _MesasComandasScreenState();
}

class _MesasComandasScreenState extends State<MesasComandasScreen> {
  TipoVisualizacao _tipoVisualizacao = TipoVisualizacao.mesas;

  @override
  void initState() {
    super.initState();
    
    // Define tipo inicial
    if (widget.tipoInicial != null) {
      _tipoVisualizacao = widget.tipoInicial!;
    }
  }

  /// Alterna o tipo de visualização
  void _alternarTipoVisualizacao(TipoVisualizacao novoTipo) {
    if (_tipoVisualizacao != novoTipo) {
      setState(() {
        _tipoVisualizacao = novoTipo;
      });
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: widget.hideAppBar
          ? null
          : AppHeader(
              title: 'Mesas e Comandas',
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.textPrimary,
              actions: [
                // Toggle compacto Mesas/Comandas
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildToggleCompacto(adaptive),
                ),
              ],
            ),
      body: _buildConteudoComToggle(adaptive),
    );
  }

  /// Conteúdo de Mesas ou Comandas
  /// Usa IndexedStack para manter estado ao alternar entre as telas
  Widget _buildConteudoComToggle(AdaptiveLayoutProvider adaptive) {
    final toggleWidget = _buildToggleCompacto(adaptive);
    
    return IndexedStack(
      index: _tipoVisualizacao == TipoVisualizacao.mesas ? 0 : 1,
      children: [
        // Tela de Mesas com toggle injetado na barra de ferramentas
        MesasScreen(
          hideAppBar: widget.hideAppBar,
          toolbarPrefix: widget.hideAppBar ? toggleWidget : null,
        ),
        // Tela de Comandas com toggle injetado
        ComandasScreen(
          hideAppBar: widget.hideAppBar,
          toolbarPrefix: widget.hideAppBar ? toggleWidget : null,
        ),
      ],
    );
  }


  /// Toggle ultra-compacto (apenas ícones lado a lado, sem container)
  Widget _buildToggleCompacto(AdaptiveLayoutProvider adaptive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botão Mesas
        _buildToggleItem(
          adaptive,
          icon: Icons.table_restaurant,
          isSelected: _tipoVisualizacao == TipoVisualizacao.mesas,
          onTap: () => _alternarTipoVisualizacao(TipoVisualizacao.mesas),
        ),
        SizedBox(width: adaptive.isMobile ? 4 : 6),
        // Botão Comandas
        _buildToggleItem(
          adaptive,
          icon: Icons.receipt_long,
          isSelected: _tipoVisualizacao == TipoVisualizacao.comandas,
          onTap: () => _alternarTipoVisualizacao(TipoVisualizacao.comandas),
        ),
      ],
    );
  }

  /// Item do toggle (apenas ícone, ultra-compacto)
  Widget _buildToggleItem(
    AdaptiveLayoutProvider adaptive, {
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 6 : 8),
        child: Container(
          padding: EdgeInsets.all(adaptive.isMobile ? 6 : 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(adaptive.isMobile ? 6 : 8),
            border: isSelected
                ? Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.5),
                    width: 1.5,
                  )
                : null,
          ),
          child: Icon(
            icon,
            size: adaptive.isMobile ? 20 : 22,
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

