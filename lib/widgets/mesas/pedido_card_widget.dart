import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/core/pedido_com_itens_pdv_dto.dart';

/// Widget para exibir card de pedido com seus itens
class PedidoCardWidget extends StatelessWidget {
  final PedidoComItensPdvDto pedido;
  final AdaptiveLayoutProvider adaptive;
  final VoidCallback? onCancelarPedido;
  final Function(ItemPedidoPdvDto)? onEditarItem;
  final Function(ItemPedidoPdvDto)? onExcluirItem;

  const PedidoCardWidget({
    super.key,
    required this.pedido,
    required this.adaptive,
    this.onCancelarPedido,
    this.onEditarItem,
    this.onExcluirItem,
  });

  /// Calcula o total do pedido somando todos os itens
  double _calcularTotalPedido() {
    return pedido.itens.fold(0.0, (sum, item) => sum + (item.precoUnitario * item.quantidade));
  }

  /// Conta o total de itens no pedido
  int _contarTotalItens() {
    return pedido.itens.fold(0, (sum, item) => sum + item.quantidade);
  }

  @override
  Widget build(BuildContext context) {
    final totalPedido = _calcularTotalPedido();
    final totalItens = _contarTotalItens();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do pedido
          Container(
            padding: EdgeInsets.all(adaptive.isMobile ? 14 : 16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(adaptive.isMobile ? 12 : 14),
                topRight: Radius.circular(adaptive.isMobile ? 12 : 14),
              ),
            ),
            child: Row(
              children: [
                // Ícone de pedido
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: adaptive.isMobile ? 18 : 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Número do pedido
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedido ${pedido.numero}',
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 16 : 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalItens ${totalItens == 1 ? 'item' : 'itens'}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Total do pedido e menu de opções
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'R\$ ${totalPedido.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: adaptive.isMobile ? 18 : 19,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    // Menu de opções (apenas se houver callback)
                    if (onCancelarPedido != null) ...[
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: AppTheme.textSecondary,
                          size: adaptive.isMobile ? 20 : 22,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        itemBuilder: (context) {
                          return [
                            PopupMenuItem<String>(
                              value: 'cancelar',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.cancel_outlined,
                                    size: 20,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Cancelar Pedido',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ];
                        },
                        onSelected: (value) {
                          if (value == 'cancelar' && onCancelarPedido != null) {
                            onCancelarPedido!();
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Lista de itens do pedido
          Padding(
            padding: EdgeInsets.all(adaptive.isMobile ? 14 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título da seção de itens
                Text(
                  'Itens:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                // Lista de itens
                ...pedido.itens.map((item) {
                  final temVariacao = item.produtoVariacaoNome != null && 
                                      item.produtoVariacaoNome!.isNotEmpty;
                  final nomeExibido = temVariacao 
                      ? item.produtoVariacaoNome! 
                      : item.produtoNome;
                  final totalItem = item.precoUnitario * item.quantidade;
                  final temAcoes = onEditarItem != null || onExcluirItem != null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge de quantidade
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item.quantidade}x',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Nome do produto
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                nomeExibido,
                                style: GoogleFonts.inter(
                                  fontSize: adaptive.isMobile ? 14 : 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              if (temVariacao) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.produtoNome,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'R\$ ${item.precoUnitario.toStringAsFixed(2)} cada',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Total do item e botões de ação
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Total do item
                            Text(
                              'R\$ ${totalItem.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontSize: adaptive.isMobile ? 14 : 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            // Botões de ação (se houver callbacks)
                            if (temAcoes) ...[
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: AppTheme.textSecondary,
                                  size: adaptive.isMobile ? 18 : 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                itemBuilder: (context) {
                                  final items = <PopupMenuEntry<String>>[];
                                  
                                  if (onEditarItem != null) {
                                    items.add(
                                      PopupMenuItem<String>(
                                        value: 'editar',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                              color: AppTheme.primaryColor,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Editar Quantidade',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  
                                  if (onExcluirItem != null) {
                                    items.add(
                                      PopupMenuItem<String>(
                                        value: 'excluir',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                              color: Colors.red.shade700,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Excluir Item',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  
                                  return items;
                                },
                                onSelected: (value) {
                                  if (value == 'editar' && onEditarItem != null) {
                                    onEditarItem!(item);
                                  } else if (value == 'excluir' && onExcluirItem != null) {
                                    onExcluirItem!(item);
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

