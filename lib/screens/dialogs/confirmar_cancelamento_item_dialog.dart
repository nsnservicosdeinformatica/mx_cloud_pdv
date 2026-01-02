import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/adaptive_layout/adaptive_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/core/pedido_com_itens_pdv_dto.dart';

/// Resultado do dialog de cancelamento de item
class CancelamentoItemResult {
  final String motivo;

  CancelamentoItemResult({required this.motivo});
}

/// Dialog para confirmar cancelamento de item de pedido
class ConfirmarCancelamentoItemDialog extends StatefulWidget {
  final ItemPedidoPdvDto item;

  const ConfirmarCancelamentoItemDialog({
    super.key,
    required this.item,
  });

  /// Método estático para exibir o dialog
  static Future<CancelamentoItemResult?> show(
    BuildContext context, {
    required ItemPedidoPdvDto item,
  }) async {
    final adaptive = AdaptiveLayoutProvider.of(context);
    final isMobile = adaptive?.isMobile ?? true;

    if (isMobile) {
      return Navigator.of(context).push<CancelamentoItemResult>(
        MaterialPageRoute(
          builder: (context) => AdaptiveLayout(
            child: ConfirmarCancelamentoItemDialog(item: item),
          ),
          fullscreenDialog: true,
        ),
      );
    } else {
      return showDialog<CancelamentoItemResult>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AdaptiveLayout(
          child: ConfirmarCancelamentoItemDialog(item: item),
        ),
      );
    }
  }

  @override
  State<ConfirmarCancelamentoItemDialog> createState() =>
      _ConfirmarCancelamentoItemDialogState();
}

class _ConfirmarCancelamentoItemDialogState
    extends State<ConfirmarCancelamentoItemDialog> {
  final TextEditingController _motivoController = TextEditingController();
  final FocusNode _motivoFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void dispose() {
    _motivoController.dispose();
    _motivoFocusNode.dispose();
    super.dispose();
  }

  void _confirmar() {
    final motivo = _motivoController.text.trim();
    if (motivo.isEmpty) {
      _mostrarErro('Por favor, informe o motivo do cancelamento');
      _motivoFocusNode.requestFocus();
      return;
    }

    if (motivo.length > 500) {
      _mostrarErro('O motivo deve ter no máximo 500 caracteres');
      _motivoFocusNode.requestFocus();
      return;
    }

    Navigator.of(context).pop(
      CancelamentoItemResult(motivo: motivo),
    );
  }

  void _cancelar() {
    Navigator.of(context).pop(null);
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) return const SizedBox.shrink();

    final isMobile = adaptive.isMobile;
    final temVariacao = widget.item.produtoVariacaoNome != null &&
        widget.item.produtoVariacaoNome!.isNotEmpty;
    final nomeExibido = temVariacao
        ? widget.item.produtoVariacaoNome!
        : widget.item.produtoNome;
    final totalItem = widget.item.precoUnitario * widget.item.quantidade;

    if (isMobile) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textPrimary),
            onPressed: _cancelar,
          ),
          title: Text(
            'Cancelar Item',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: _buildConteudo(adaptive, nomeExibido, temVariacao, totalItem),
        bottomNavigationBar: _buildBottomBar(adaptive),
      );
    } else {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: 500,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cabeçalho
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cancelar Item',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: _cancelar,
                    ),
                  ],
                ),
              ),
              // Conteúdo
              Flexible(
                child: _buildConteudo(
                  adaptive,
                  nomeExibido,
                  temVariacao,
                  totalItem,
                ),
              ),
              // Rodapé
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: _buildBotoes(adaptive),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildConteudo(
    AdaptiveLayoutProvider adaptive,
    String nomeExibido,
    bool temVariacao,
    double totalItem,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(adaptive.isMobile ? 20 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aviso
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tem certeza que deseja cancelar este item?',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Informações do produto
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Item a ser cancelado',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  nomeExibido,
                  style: GoogleFonts.inter(
                    fontSize: adaptive.isMobile ? 16 : 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (temVariacao) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.item.produtoNome,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quantidade',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${widget.item.quantidade}x',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Preço unitário',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      'R\$ ${widget.item.precoUnitario.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'R\$ ${totalItem.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Campo de motivo
          Text(
            'Motivo do Cancelamento *',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _motivoController,
            focusNode: _motivoFocusNode,
            enabled: !_isLoading,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Informe o motivo do cancelamento...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              counterText: '${_motivoController.text.length}/500',
            ),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
            onChanged: (value) {
              setState(() {}); // Atualiza contador
            },
          ),
          const SizedBox(height: 8),
          Text(
            '* Campo obrigatório',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(AdaptiveLayoutProvider adaptive) {
    return Container(
      padding: EdgeInsets.all(adaptive.isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: _buildBotoes(adaptive),
    );
  }

  Widget _buildBotoes(AdaptiveLayoutProvider adaptive) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : _cancelar,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                vertical: adaptive.isMobile ? 14 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(
                fontSize: adaptive.isMobile ? 15 : 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _confirmar,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                vertical: adaptive.isMobile ? 14 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Confirmar Cancelamento',
                    style: GoogleFonts.inter(
                      fontSize: adaptive.isMobile ? 15 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

