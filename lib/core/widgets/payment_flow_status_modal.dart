import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../../core/payment/payment_flow_state.dart';
import '../../presentation/providers/payment_flow_provider.dart';
import 'standard_loading_dialog.dart';

/// Modal padrão para indicar o status do fluxo de pagamento
/// 
/// Aparece automaticamente quando o estado é de processamento e desaparece quando completa ou falha.
/// Reutilizável em qualquer lugar da aplicação.
class PaymentFlowStatusModal {
  static bool _isShowing = false;
  static BuildContext? _currentContext;

  /// Mostra o modal se necessário baseado no estado do provider
  /// 
  /// Deve ser chamado no build() da tela que usa PaymentFlowProvider
  /// Usa addPostFrameCallback para evitar erro de setState durante build
  static void showIfNeeded(BuildContext context, PaymentFlowProvider provider) {
    final state = provider.currentState;
    
    // ✅ Usa addPostFrameCallback para garantir que mostra/esconde APÓS o build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      
      // Se está processando e modal não está mostrando, mostra
      if (state.isProcessing && !_isShowing) {
        _show(context, provider);
      }
      // Se não está processando e modal está mostrando, esconde
      else if (!state.isProcessing && _isShowing && _currentContext == context) {
        _hide(context);
      }
    });
  }

  /// Esconde o modal se estiver mostrando
  static void hideIfShowing(BuildContext context) {
    if (_isShowing && _currentContext == context) {
      _hide(context);
    }
  }

  static void _show(BuildContext context, PaymentFlowProvider provider) {
    if (_isShowing) return;
    
    // ✅ Usa Future.microtask para garantir que mostra APÓS todas as operações síncronas
    // Evita conflito com Navigator durante build
    Future.microtask(() {
      if (!context.mounted || _isShowing) return;
      
      _isShowing = true;
      _currentContext = context;
      
      showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Consumer<PaymentFlowProvider>(
          builder: (context, providerDialog, child) {
            // Se não está mais processando, fecha automaticamente
            // Usa Future.microtask para garantir que fecha após todas as operações síncronas
            if (!providerDialog.currentState.isProcessing) {
              Future.microtask(() {
                // Verifica novamente se ainda não está processando e se o dialog ainda está montado
                if (dialogContext.mounted && !providerDialog.currentState.isProcessing) {
                  _hide(dialogContext);
                }
              });
            }
            
            return _buildModalContent(providerDialog);
          },
        ),
      ),
      ).then((_) {
        _isShowing = false;
        _currentContext = null;
      });
    });
  }

  static void _hide(BuildContext context) {
    if (!_isShowing) return;
    
    // Marca como não mostrando imediatamente para evitar múltiplas tentativas
    _isShowing = false;
    _currentContext = null;
    
    // Usa Future.microtask para garantir que fecha após todas as operações síncronas
    // Evita erro de Navigator durante build ou draw frame
    Future.microtask(() {
      if (context.mounted && Navigator.canPop(context)) {
        try {
          Navigator.of(context).pop();
        } catch (e) {
          // Ignora erros de Navigator (pode já ter sido fechado)
          debugPrint('⚠️ [PaymentFlowStatusModal] Erro ao fechar modal: $e');
        }
      }
    });
  }

  static Widget _buildModalContent(PaymentFlowProvider provider) {
    final state = provider.currentState;
    final (icon, color, message, subtitle) = _getStatusInfo(state, provider);

    // Se está processando, usa o componente padronizado de loading
    if (state.isProcessing) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: StandardLoadingDialog(
          message: message,
          subtitle: subtitle,
          loadingSize: 80.0,
        ),
      );
    }

    // Se não está processando (sucesso/erro), mostra Dialog com ícone e informações
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone estático
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: color,
              ),
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
            if (subtitle != null && subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            
            // Tentativas (se houver)
            if (provider.tentativasEmissao > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Tentativa ${provider.tentativasEmissao}/${PaymentFlowProvider.MAX_TENTATIVAS_EMISSAO}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            
            // Informações da nota (se disponível e relevante)
            if (provider.notaFiscalStatus != null &&
                provider.notaFiscalStatus!.isError) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.errorColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Motivo da Rejeição:',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.notaFiscalStatus!.motivoRejeicao ??
                          provider.notaFiscalStatus!.erro ??
                          'Motivo não informado',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Botão de retry (se pode fazer retry)
            if (provider.canRetry) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    provider.retry();
                    // Modal será fechado automaticamente quando estado mudar
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Tentar Novamente',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Obtém informações do status atual
  static (IconData icon, Color color, String message, String? subtitle) _getStatusInfo(
    PaymentFlowState state,
    PaymentFlowProvider provider,
  ) {
    switch (state) {
      case PaymentFlowState.registeringPayment:
        return (
          Icons.cloud_upload,
          AppTheme.primaryColor,
          'Registrando Pagamento',
          'Aguarde enquanto registramos o pagamento no servidor...',
        );
      
      case PaymentFlowState.concludingSale:
        return (
          Icons.hourglass_empty,
          AppTheme.primaryColor,
          'Concluindo Venda',
          'Aguarde enquanto finalizamos a venda...',
        );
      
      case PaymentFlowState.creatingInvoice:
        return (
          Icons.receipt_long,
          AppTheme.primaryColor,
          'Criando Nota Fiscal',
          'Aguarde enquanto criamos a nota fiscal...',
        );
      
      case PaymentFlowState.sendingToSefaz:
        return (
          Icons.cloud_upload,
          AppTheme.primaryColor,
          'Enviando para SEFAZ',
          'Aguarde enquanto enviamos a nota fiscal para a SEFAZ...',
        );
      
      case PaymentFlowState.invoiceAuthorized:
        return (
          Icons.check_circle,
          AppTheme.successColor,
          'Nota Fiscal Autorizada',
          'A nota fiscal foi autorizada com sucesso!',
        );
      
      case PaymentFlowState.printingInvoice:
        return (
          Icons.print,
          AppTheme.primaryColor,
          'Imprimindo Nota Fiscal',
          'Aguarde enquanto imprimimos a nota fiscal...',
        );
      
      case PaymentFlowState.completed:
        return (
          Icons.check_circle,
          AppTheme.successColor,
          'Venda Concluída',
          'A venda foi concluída com sucesso!',
        );
      
      case PaymentFlowState.completionFailed:
        return (
          Icons.error,
          AppTheme.errorColor,
          'Erro ao Concluir Venda',
          provider.errorMessage,
        );
      
      case PaymentFlowState.invoiceFailed:
        return (
          Icons.error,
          AppTheme.errorColor,
          'Erro ao Emitir Nota Fiscal',
          provider.errorMessage,
        );
      
      case PaymentFlowState.printFailed:
        return (
          Icons.error,
          AppTheme.errorColor,
          'Erro ao Imprimir Nota Fiscal',
          provider.errorMessage,
        );
      
      default:
        return (
          Icons.info,
          AppTheme.textSecondary,
          'Processando...',
          null,
        );
    }
  }
}

