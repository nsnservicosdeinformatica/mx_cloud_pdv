import 'package:flutter/material.dart';
import 'standard_loading_dialog.dart';

/// Helper unificado para exibir e ocultar loading dialogs
/// Garante consistência em todo o sistema
class LoadingHelper {
  /// Mostra um loading dialog usando rootNavigator
  /// [context] - Contexto do widget
  /// [message] - Mensagem principal a ser exibida (padrão: "Carregando...")
  /// [subtitle] - Mensagem secundária opcional
  /// [barrierDismissible] - Se o loading pode ser fechado ao tocar fora (padrão: false)
  static void show(
    BuildContext context, {
    String message = 'Carregando...',
    String? subtitle,
    bool barrierDismissible = false,
  }) {
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      useRootNavigator: true,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (dialogContext) => Dialog(
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
      ),
    );
  }

  /// Esconde o loading dialog usando rootNavigator
  /// [context] - Contexto do widget
  static void hide(BuildContext context) {
    if (!context.mounted) return;
    
    try {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      debugPrint('⚠️ [LoadingHelper] Erro ao esconder loading: $e');
    }
  }

  /// Executa uma função assíncrona mostrando loading durante a execução
  /// [context] - Contexto do widget
  /// [action] - Função assíncrona a ser executada
  /// [message] - Mensagem principal a ser exibida (padrão: "Carregando...")
  /// [subtitle] - Mensagem secundária opcional
  /// [barrierDismissible] - Se o loading pode ser fechado ao tocar fora (padrão: false)
  /// Retorna o resultado da função [action]
  static Future<T?> withLoading<T>(
    BuildContext context,
    Future<T> Function() action, {
    String message = 'Carregando...',
    String? subtitle,
    bool barrierDismissible = false,
  }) async {
    show(
      context,
      message: message,
      subtitle: subtitle,
      barrierDismissible: barrierDismissible,
    );
    
    try {
      final result = await action();
      return result;
    } finally {
      hide(context);
    }
  }
}

