import 'package:flutter/material.dart';
import '../../data/services/sync/api_local_sync_service.dart';
import '../../core/theme/app_theme.dart';

class ApiLocalSyncDialog extends StatefulWidget {
  final ApiLocalSyncService apiLocalSyncService;

  const ApiLocalSyncDialog({
    super.key,
    required this.apiLocalSyncService,
  });

  @override
  State<ApiLocalSyncDialog> createState() => _ApiLocalSyncDialogState();
}

class _ApiLocalSyncDialogState extends State<ApiLocalSyncDialog> {
  bool _isSyncing = false;
  ApiLocalSyncProgress? _currentProgress;
  ApiLocalSyncResult? _result;

  @override
  void initState() {
    super.initState();
    // Aguarda um frame para garantir que o dialog está montado antes de iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _iniciarSincronizacao();
    });
  }

  Future<void> _iniciarSincronizacao() async {
    if (!mounted) return;

    setState(() {
      _isSyncing = true;
      _currentProgress = null;
      _result = null;
    });

    try {
      final result = await widget.apiLocalSyncService.sincronizarCompleto(
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _currentProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isSyncing = false;
          _result = result;
        });

        // Fechar dialog após um breve delay para mostrar o resultado
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pop();

            // Mostrar resultado
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
                duration: const Duration(seconds: 4),
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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _result = ApiLocalSyncResult(
            sucesso: false,
            erro: e.toString(),
          );
        });

        // Fechar dialog e mostrar erro
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pop();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Erro: ${e.toString()}'),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppTheme.errorColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSyncing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_result != null)
            Icon(
              _result!.sucesso ? Icons.check_circle : Icons.error,
              color: _result!.sucesso ? AppTheme.successColor : AppTheme.errorColor,
            )
          else
            const Icon(Icons.cloud_sync, color: Color(0xFF10B981)),
          const SizedBox(width: 12),
          const Text('Sincronizando Servidor...'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentProgress != null && _isSyncing) ...[
            Text(
              _currentProgress!.etapa,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _currentProgress!.progresso / 100,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF10B981),
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              _currentProgress!.mensagem,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ] else if (_result != null) ...[
            Icon(
              _result!.sucesso ? Icons.check_circle : Icons.error,
              color: _result!.sucesso ? AppTheme.successColor : AppTheme.errorColor,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _result!.sucesso
                  ? _buildMensagemSucesso(_result!)
                  : 'Erro: ${_result!.erro ?? "Erro desconhecido"}',
              style: Theme.of(context).textTheme.bodyMedium,
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
          onPressed: _isSyncing
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }

  String _buildMensagemSucesso(ApiLocalSyncResult result) {
    final partes = <String>[];
    
    if (result.tabelasProcessadas > 0) {
      partes.add('${result.tabelasProcessadas} tabela(s)');
    }
    if (result.registrosProcessados > 0) {
      partes.add('${result.registrosProcessados} registro(s) processado(s)');
    }
    if (result.registrosInseridos > 0) {
      partes.add('${result.registrosInseridos} inserido(s)');
    }
    if (result.registrosAtualizados > 0) {
      partes.add('${result.registrosAtualizados} atualizado(s)');
    }
    
    if (partes.isEmpty) {
      return 'Sincronização do servidor concluída';
    }
    
    return 'Sincronização concluída: ${partes.join(', ')}';
  }
}

