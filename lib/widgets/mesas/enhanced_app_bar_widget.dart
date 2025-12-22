import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../models/mesas/entidade_produtos.dart';
import '../../core/utils/status_utils.dart';

/// AppBar customizado com informações da mesa/comanda e status
class EnhancedAppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final MesaComandaInfo entidade;
  final AdaptiveLayoutProvider adaptive;
  final VoidCallback? onRefresh;
  
  // Status dinâmico (opcional - se não fornecido, usa entidade.status)
  final String? statusDinamico;
  
  // Status de sincronização (opcional)
  final bool estaSincronizando;
  final bool temErros;
  final int pedidosPendentes;

  const EnhancedAppBarWidget({
    super.key,
    required this.entidade,
    required this.adaptive,
    this.onRefresh,
    this.statusDinamico,
    this.estaSincronizando = false,
    this.temErros = false,
    this.pedidosPendentes = 0,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      // Ocultar botão de voltar no desktop (layout dividido)
      leading: adaptive.isMobile
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      automaticallyImplyLeading: false, // Não mostrar botão de voltar automaticamente no desktop
      title: Row(
        children: [
          // Ícone da mesa/comanda
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              entidade.tipo == TipoEntidade.mesa 
                  ? Icons.table_restaurant 
                  : Icons.receipt_long,
              size: 20,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          // Nome e status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${entidade.tipo == TipoEntidade.mesa ? 'Mesa' : 'Comanda'} ${entidade.numero}',
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 16 : 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Badge de status (usa status dinâmico se disponível)
                    Builder(
                      builder: (context) {
                        final statusExibido = statusDinamico ?? entidade.status;
                        final statusColor = StatusUtils.getStatusColor(statusExibido, entidade.tipo);
                        
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: statusColor.withOpacity(0.4),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                statusExibido,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            // Indicador de sincronização
                            if (estaSincronizando) ...[
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                ),
                              ),
                            ],
                            // Indicador de erro
                            if (temErros) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.error_outline,
                                size: 14,
                                color: AppTheme.errorColor,
                              ),
                            ],
                            // Indicador de pendente
                            if (pedidosPendentes > 0 && !estaSincronizando && !temErros) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.warningColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$pedidosPendentes',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.warningColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
                // Descrição ou código de barras (se houver)
                if ((entidade.descricao != null && entidade.descricao!.isNotEmpty) ||
                    (entidade.codigoBarras != null && entidade.codigoBarras!.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      entidade.descricao ?? 
                      (entidade.codigoBarras != null ? 'Código: ${entidade.codigoBarras}' : ''),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (onRefresh != null)
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textPrimary),
            onPressed: onRefresh,
            tooltip: 'Atualizar',
          ),
      ],
    );
  }
}
