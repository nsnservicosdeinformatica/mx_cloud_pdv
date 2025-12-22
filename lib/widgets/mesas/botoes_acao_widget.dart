import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/core/produto_agrupado.dart';
import '../../data/models/core/vendas/pagamento_venda_dto.dart';
import 'compact_header_widget.dart';

/// Widget para botões de ação (novo pedido, imprimir, pagar/finalizar)
class BotoesAcaoWidget extends StatelessWidget {
  final AdaptiveLayoutProvider adaptive;
  final bool podeCriarPedido;
  final bool deveMostrarBotoesAcao;
  final List<ProdutoAgrupado> produtos;
  final double total;
  final double valorPago;
  final List<PagamentoVendaDto> pagamentos;
  final bool historicoExpandido;
  final VoidCallback onToggleHistorico;
  final VoidCallback onNovoPedido;
  final VoidCallback onImprimirParcial;
  final VoidCallback onPagar;
  final VoidCallback onFinalizar;
  final bool saldoZero;

  const BotoesAcaoWidget({
    super.key,
    required this.adaptive,
    required this.podeCriarPedido,
    required this.deveMostrarBotoesAcao,
    required this.produtos,
    required this.total,
    required this.valorPago,
    required this.pagamentos,
    required this.historicoExpandido,
    required this.onToggleHistorico,
    required this.onNovoPedido,
    required this.onImprimirParcial,
    required this.onPagar,
    required this.onFinalizar,
    required this.saldoZero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header compacto com valores financeiros
          CompactHeaderWidget(
            adaptive: adaptive,
            total: total,
            valorPago: valorPago,
            pagamentos: pagamentos,
            historicoExpandido: historicoExpandido,
            onToggleHistorico: onToggleHistorico,
          ),
          
          // Botões de ação
          Padding(
            padding: EdgeInsets.fromLTRB(
              adaptive.isMobile ? 16 : 20,
              12,
              adaptive.isMobile ? 16 : 20,
              adaptive.isMobile ? 16 : 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botão Novo Pedido
                if (podeCriarPedido)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onNovoPedido,
                      icon: const Icon(Icons.add_shopping_cart, size: 20),
                      label: Text(
                        'Novo Pedido',
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 15 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: adaptive.isMobile ? 12 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
                        ),
                      ),
                    ),
                  ),
                // Botões de impressão e pagamento
                if (deveMostrarBotoesAcao) ...[
                  if (podeCriarPedido) const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onImprimirParcial,
                          icon: const Icon(Icons.print, size: 18),
                          label: Text(
                            'Imprimir Parcial',
                            style: GoogleFonts.inter(
                              fontSize: adaptive.isMobile ? 14 : 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(color: AppTheme.primaryColor),
                            padding: EdgeInsets.symmetric(
                              vertical: adaptive.isMobile ? 12 : 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: saldoZero ? onFinalizar : onPagar,
                          icon: Icon(
                            saldoZero ? Icons.check_circle : Icons.payment,
                            size: 18,
                          ),
                          label: Text(
                            saldoZero ? 'Finalizar' : 'Pagar',
                            style: GoogleFonts.inter(
                              fontSize: adaptive.isMobile ? 14 : 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: saldoZero ? AppTheme.primaryColor : AppTheme.successColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: adaptive.isMobile ? 12 : 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
