import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/core/produto_agrupado.dart';

/// Widget para exibir card de produto agrupado
class ProdutoCardWidget extends StatelessWidget {
  final ProdutoAgrupado produto;
  final AdaptiveLayoutProvider adaptive;

  const ProdutoCardWidget({
    super.key,
    required this.produto,
    required this.adaptive,
  });

  @override
  Widget build(BuildContext context) {
    final temVariacao = produto.produtoVariacaoNome != null && produto.produtoVariacaoNome!.isNotEmpty;
    // Nome a ser exibido: variação se houver, senão nome do produto
    final nomeExibido = temVariacao ? produto.produtoVariacaoNome! : produto.produtoNome;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Padding(
        padding: EdgeInsets.all(adaptive.isMobile ? 14 : 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge de quantidade
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${produto.quantidadeTotal}x',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Informações do produto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nome do produto ou variação
                  Text(
                    nomeExibido,
                    style: GoogleFonts.inter(
                      fontSize: adaptive.isMobile ? 15 : 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Preço unitário
                  Text(
                    'R\$ ${produto.precoUnitario.toStringAsFixed(2)} cada',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Preço total
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
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
                  'R\$ ${produto.precoTotal.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: adaptive.isMobile ? 16 : 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
