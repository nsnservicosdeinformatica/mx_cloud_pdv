import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/adaptive_layout/adaptive_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/teclado_numerico_dialog.dart';
import '../../../data/models/core/pedido_com_itens_pdv_dto.dart';

/// Dialog para editar quantidade de item de pedido
class EditarQuantidadeItemDialog extends StatefulWidget {
  final ItemPedidoPdvDto item;
  final int quantidadeAtual;

  const EditarQuantidadeItemDialog({
    super.key,
    required this.item,
    required this.quantidadeAtual,
  });

  /// Método estático para exibir o dialog
  static Future<int?> show(
    BuildContext context, {
    required ItemPedidoPdvDto item,
    required int quantidadeAtual,
  }) async {
    final adaptive = AdaptiveLayoutProvider.of(context);
    final isMobile = adaptive?.isMobile ?? true;

    if (isMobile) {
      return Navigator.of(context).push<int>(
        MaterialPageRoute(
          builder: (context) => AdaptiveLayout(
            child: EditarQuantidadeItemDialog(
              item: item,
              quantidadeAtual: quantidadeAtual,
            ),
          ),
          fullscreenDialog: true,
        ),
      );
    } else {
      return showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AdaptiveLayout(
          child: EditarQuantidadeItemDialog(
            item: item,
            quantidadeAtual: quantidadeAtual,
          ),
        ),
      );
    }
  }

  @override
  State<EditarQuantidadeItemDialog> createState() =>
      _EditarQuantidadeItemDialogState();
}

class _EditarQuantidadeItemDialogState
    extends State<EditarQuantidadeItemDialog> {
  late TextEditingController _quantidadeController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _quantidadeController = TextEditingController(
      text: widget.quantidadeAtual.toString(),
    );
  }

  @override
  void dispose() {
    _quantidadeController.dispose();
    super.dispose();
  }

  void _confirmar() {
    final quantidadeTexto = _quantidadeController.text.trim();
    if (quantidadeTexto.isEmpty) {
      _mostrarErro('Por favor, informe a quantidade');
      return;
    }

    final quantidade = int.tryParse(quantidadeTexto);
    if (quantidade == null || quantidade < 1) {
      _mostrarErro('A quantidade deve ser um número maior que zero');
      return;
    }

    Navigator.of(context).pop(quantidade);
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

  Future<void> _abrirTecladoNumerico() async {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) return;

    final quantidade = await TecladoNumericoDialog.show(
      context,
      titulo: 'Quantidade',
      valorInicial: _quantidadeController.text,
      permiteDecimal: false,
    );

    if (quantidade != null && quantidade.isNotEmpty) {
      final quantidadeInt = int.tryParse(quantidade);
      if (quantidadeInt != null && quantidadeInt >= 1) {
        setState(() {
          _quantidadeController.text = quantidade;
        });
      } else {
        _mostrarErro('A quantidade deve ser um número maior que zero');
      }
    }
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
            'Editar Quantidade',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: _buildConteudo(adaptive, nomeExibido, temVariacao),
        bottomNavigationBar: _buildBottomBar(adaptive),
      );
    } else {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: 450,
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
                        'Editar Quantidade',
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
              Flexible(child: _buildConteudo(adaptive, nomeExibido, temVariacao)),
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
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(adaptive.isMobile ? 20 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Informações do produto
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Produto',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
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
                const SizedBox(height: 8),
                Text(
                  'Preço unitário: R\$ ${widget.item.precoUnitario.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Campo de quantidade
          Text(
            'Nova Quantidade',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _quantidadeController,
            keyboardType: TextInputType.number,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: 'Digite a quantidade',
              suffixIcon: IconButton(
                icon: const Icon(Icons.keyboard, color: AppTheme.primaryColor),
                onPressed: _abrirTecladoNumerico,
                tooltip: 'Abrir teclado numérico',
              ),
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
            ),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Informação de total
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Builder(
                  builder: (context) {
                    final quantidade = int.tryParse(_quantidadeController.text) ?? 0;
                    final total = quantidade * widget.item.precoUnitario;
                    return Text(
                      'R\$ ${total.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    );
                  },
                ),
              ],
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
              backgroundColor: AppTheme.primaryColor,
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
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Confirmar',
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

