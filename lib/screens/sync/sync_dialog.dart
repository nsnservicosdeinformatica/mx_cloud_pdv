import 'package:flutter/material.dart';
import '../../presentation/providers/sync_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/sync/sync_service.dart';

class SyncDialog extends StatefulWidget {
  final SyncProvider syncProvider;
  final bool forcar;

  const SyncDialog({
    super.key,
    required this.syncProvider,
    this.forcar = false,
  });

  @override
  State<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<SyncDialog> {
  @override
  void initState() {
    super.initState();
    widget.syncProvider.addListener(_onSyncUpdate);
    // Aguarda um frame para garantir que o dialog está montado antes de iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.syncProvider.sincronizar(forcar: widget.forcar);
    });
  }

  void _onSyncUpdate() {
    if (mounted) {
      setState(() {});

      // Fechar dialog se concluído
      if (!widget.syncProvider.isSyncing &&
          widget.syncProvider.lastResult != null) {
        Navigator.of(context).pop();

        // Mostrar resultado
        final result = widget.syncProvider.lastResult!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result.sucesso ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.sucesso
                        ? _buildMensagemSucesso(result)
                        : 'Erro: ${result.erro ?? "Erro desconhecido"}',
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: result.sucesso
                ? AppTheme.successColor
                : AppTheme.errorColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.syncProvider.currentProgress;
    final isSyncing = widget.syncProvider.isSyncing;

    return AlertDialog(
      title: Row(
        children: [
          if (isSyncing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.sync, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          const Text('Sincronizando...'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (progress != null && isSyncing) ...[
            Text(
              progress.etapa,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.progresso / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.primaryColor,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              progress.mensagem,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ] else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isSyncing
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }

  String _buildMensagemSucesso(SyncResult result) {
    final partes = <String>[];
    
    if (result.produtosSincronizados > 0) {
      partes.add('${result.produtosSincronizados} produto(s)');
    }
    if (result.gruposSincronizados > 0) {
      partes.add('${result.gruposSincronizados} grupo(s)');
    }
    if (result.mesasSincronizadas > 0) {
      partes.add('${result.mesasSincronizadas} mesa(s)');
    }
    if (result.comandasSincronizadas > 0) {
      partes.add('${result.comandasSincronizadas} comanda(s)');
    }
    if (result.pedidosSincronizados > 0) {
      partes.add('${result.pedidosSincronizados} pedido(s)');
    }
    
    if (partes.isEmpty) {
      return 'Sincronização concluída';
    }
    
    return 'Sincronização concluída: ${partes.join(', ')}';
  }

  @override
  void dispose() {
    widget.syncProvider.removeListener(_onSyncUpdate);
    super.dispose();
  }
}

