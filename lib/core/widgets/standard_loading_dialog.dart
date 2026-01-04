import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/h4nd_loading.dart';
import '../theme/app_theme.dart';

/// Componente padronizado de loading para todo o sistema
/// 
/// Exibe uma caixa cinza com:
/// - Texto informativo sobre o que está sendo feito
/// - Loading H4ND no centro
/// 
/// Usado por LoadingHelper e PaymentFlowStatusModal
class StandardLoadingDialog extends StatelessWidget {
  /// Mensagem principal a ser exibida
  final String message;
  
  /// Mensagem secundária (opcional)
  final String? subtitle;
  
  /// Tamanho do loading H4ND (padrão: 80)
  final double loadingSize;
  
  /// Se deve mostrar barreira escura (padrão: true)
  final bool showBarrier;

  const StandardLoadingDialog({
    Key? key,
    required this.message,
    this.subtitle,
    this.loadingSize = 80.0,
    this.showBarrier = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Retorna apenas o conteúdo (Container), não o Dialog
    // Isso permite usar tanto no LoadingHelper (com Dialog) quanto no PaymentFlowStatusModal (já tem Dialog)
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade100, // Caixa cinza
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Loading H4ND no centro
          H4ndLoading(
            size: loadingSize,
          ),
          
          const SizedBox(height: 24),
          
          // Mensagem principal
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          
          // Mensagem secundária (se houver)
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

