import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../adaptive_layout/adaptive_layout.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Componente reutilizável para entrada numérica com teclado numérico
/// Pode ser usado para números de mesa, comanda, quantidades, valores, etc.
class TecladoNumericoDialog extends StatefulWidget {
  final String titulo;
  final String? valorInicial;
  final String? hint;
  final IconData? icon;
  final Color? cor;
  final bool permiteDecimal;
  final Function(String)? onConfirmar;
  final VoidCallback? onCancelar;

  const TecladoNumericoDialog({
    super.key,
    required this.titulo,
    this.valorInicial,
    this.hint,
    this.icon,
    this.cor,
    this.permiteDecimal = false,
    this.onConfirmar,
    this.onCancelar,
  });

  /// Mostra o dialog/tela de entrada numérica
  /// Retorna o valor digitado ou null se cancelado
  static Future<String?> show(
    BuildContext context, {
    required String titulo,
    String? valorInicial,
    String? hint,
    IconData? icon,
    Color? cor,
    bool permiteDecimal = false,
  }) async {
    String? resultado;
    
    final adaptive = AdaptiveLayoutProvider.of(context);
    final isMobile = adaptive?.isMobile ?? true;
    
    if (isMobile) {
      // Em mobile: tela cheia
      resultado = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => AdaptiveLayout(
            child: TecladoNumericoDialog(
              titulo: titulo,
              valorInicial: valorInicial,
              hint: hint,
              icon: icon,
              cor: cor ?? AppTheme.primaryColor,
              permiteDecimal: permiteDecimal,
            ),
          ),
          fullscreenDialog: true,
        ),
      );
    } else {
      // Em desktop: modal adaptativo (não fixo)
      resultado = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AdaptiveLayout(
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(40),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calcula altura máxima disponível (90% da tela)
                final maxHeight = MediaQuery.of(context).size.height * 0.9;
                // Largura fixa, altura adaptativa
                final width = 600.0;
                final height = maxHeight.clamp(500.0, 800.0); // Mínimo 500, máximo 800
                
                return Container(
                  width: width,
                  height: height,
                  constraints: BoxConstraints(
                    maxHeight: maxHeight,
                    minHeight: 500.0,
                  ),
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
                  child: TecladoNumericoDialog(
                    titulo: titulo,
                    valorInicial: valorInicial,
                    hint: hint,
                    icon: icon,
                    cor: cor ?? AppTheme.primaryColor,
                    permiteDecimal: permiteDecimal,
                  ),
                );
              },
            ),
          ),
        ),
      );
    }
    
    return resultado;
  }

  @override
  State<TecladoNumericoDialog> createState() => _TecladoNumericoDialogState();
}

class _TecladoNumericoDialogState extends State<TecladoNumericoDialog> {
  String _valor = '';

  @override
  void initState() {
    super.initState();
    _valor = widget.valorInicial ?? '';
  }

  void _adicionarDigito(String digito) {
    if (widget.permiteDecimal && digito == '.' && _valor.contains('.')) {
      return; // Não permite dois pontos decimais
    }
    setState(() {
      _valor += digito;
    });
  }

  void _removerUltimoDigito() {
    if (_valor.isNotEmpty) {
      setState(() {
        _valor = _valor.substring(0, _valor.length - 1);
      });
    }
  }

  void _limpar() {
    setState(() {
      _valor = '';
    });
  }

  void _confirmar() {
    if (widget.onConfirmar != null) {
      widget.onConfirmar!(_valor);
    } else {
      Navigator.of(context).pop(_valor.isEmpty ? null : _valor);
    }
  }

  void _cancelar() {
    if (widget.onCancelar != null) {
      widget.onCancelar!();
    } else {
      Navigator.of(context).pop(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) return const SizedBox.shrink();

    final isMobile = adaptive.isMobile;
    final cor = widget.cor ?? AppTheme.primaryColor;

    if (isMobile) {
      // Mobile: Scaffold (tela cheia)
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
            widget.titulo,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: _buildConteudo(adaptive, cor),
      );
    } else {
      // Desktop: conteúdo do Dialog
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header compacto
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.titulo,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _cancelar,
                ),
              ],
            ),
          ),
          // Conteúdo
          Expanded(child: _buildConteudo(adaptive, cor)),
        ],
      );
    }
  }

  Widget _buildConteudo(AdaptiveLayoutProvider adaptive, Color cor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcula espaços disponíveis de forma adaptativa
        final isDesktop = !adaptive.isMobile;
        final padding = adaptive.isMobile ? 24.0 : 20.0;
        final inputPadding = adaptive.isMobile ? 20.0 : 16.0;
        final inputVerticalPadding = adaptive.isMobile ? 20.0 : 14.0;
        final spacing = adaptive.isMobile ? 40.0 : 24.0;
        final buttonSpacing = adaptive.isMobile ? 24.0 : 16.0;
        
        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Campo de exibição do valor (compacto)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: inputPadding,
                  vertical: inputVerticalPadding,
                ),
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(adaptive.isMobile ? 16 : 18),
                  border: Border.all(color: cor, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        color: cor,
                        size: adaptive.isMobile ? 32 : 28,
                      ),
                      SizedBox(width: adaptive.isMobile ? 16 : 12),
                    ],
                    Flexible(
                      child: Text(
                        _valor.isEmpty ? (widget.hint ?? 'Digite...') : _valor,
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 24 : 22,
                          fontWeight: FontWeight.w600,
                          color: _valor.isEmpty ? Colors.grey.shade500 : cor,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: spacing),
              
              // Teclado numérico (usa todo espaço disponível)
              Expanded(
                child: _buildTecladoNumerico(adaptive, cor),
              ),
              
              SizedBox(height: buttonSpacing),
              
              // Botões de ação (compactos)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelar,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: adaptive.isMobile ? 16 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 12),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 16 : 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: adaptive.isMobile ? 16 : 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _valor.isEmpty ? null : _confirmar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: adaptive.isMobile ? 16 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 12),
                        ),
                      ),
                      child: Text(
                        'Confirmar',
                        style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 16 : 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTecladoNumerico(AdaptiveLayoutProvider adaptive, Color cor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcula padding e espaçamentos adaptativos
        final padding = adaptive.isMobile ? 12.0 : 10.0;
        final spacing = adaptive.isMobile ? 8.0 : 6.0;
        final buttonSpacing = adaptive.isMobile ? 8.0 : 6.0;
        
        // Altura disponível para os botões (descontando padding e espaçamentos)
        final alturaBotao = (constraints.maxHeight - (padding * 2) - buttonSpacing) / 4;
        
        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(adaptive.isMobile ? 16 : 18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              // Linhas 1-3, 4-6, 7-9
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    for (int linha = 0; linha < 3; linha++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: linha < 2 ? spacing : 0,
                          ),
                          child: Row(
                            children: [
                              for (int coluna = 0; coluna < 3; coluna++)
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: spacing),
                                    child: _buildBotaoTeclado(
                                      adaptive,
                                      '${linha * 3 + coluna + 1}',
                                      onTap: () => _adicionarDigito('${linha * 3 + coluna + 1}'),
                                      cor: cor,
                                      alturaDisponivel: alturaBotao,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Espaçamento entre linhas numéricas e linha de ações
              SizedBox(height: buttonSpacing),
              
              // Linha 0, ponto decimal (se permitido), backspace, limpar
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: spacing),
                        child: _buildBotaoTeclado(
                          adaptive,
                          '0',
                          onTap: () => _adicionarDigito('0'),
                          cor: cor,
                          alturaDisponivel: alturaBotao,
                        ),
                      ),
                    ),
                    if (widget.permiteDecimal)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: spacing),
                          child: _buildBotaoTeclado(
                            adaptive,
                            '.',
                            onTap: () => _adicionarDigito('.'),
                            cor: cor,
                            alturaDisponivel: alturaBotao,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: spacing),
                        child: _buildBotaoTeclado(
                          adaptive,
                          '⌫',
                          onTap: _removerUltimoDigito,
                          cor: AppTheme.warningColor,
                          alturaDisponivel: alturaBotao,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: spacing),
                        child: _buildBotaoTeclado(
                          adaptive,
                          '✕',
                          onTap: _limpar,
                          cor: AppTheme.errorColor,
                          alturaDisponivel: alturaBotao,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBotaoTeclado(
    AdaptiveLayoutProvider adaptive,
    String texto, {
    required VoidCallback onTap,
    required Color cor,
    required double alturaDisponivel,
  }) {
    // Calcula tamanho da fonte baseado na altura disponível
    // Usa 40% da altura do botão como tamanho da fonte (mantém proporção)
    final fontSizeBase = alturaDisponivel * 0.4;
    // Limita entre 20 e 40 para não ficar muito pequeno ou grande
    final fontSize = fontSizeBase.clamp(20.0, 40.0);
    
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(adaptive.isMobile ? 14 : 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 14 : 14),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(adaptive.isMobile ? 14 : 14),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              texto,
              style: GoogleFonts.inter(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: cor,
                height: 1.0, // Altura de linha fixa para manter proporção
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }
}

