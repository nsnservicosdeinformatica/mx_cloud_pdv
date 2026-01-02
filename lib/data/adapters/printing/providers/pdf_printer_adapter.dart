import '../../../../core/printing/print_provider.dart';
import '../../../../core/printing/print_data.dart';
import '../../../../core/printing/nfce_print_data.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Provider de impressão PDF (sempre disponível)
class PDFPrinterAdapter implements PrintProvider {
  @override
  String get providerName => 'PDF';
  
  @override
  PrintType get printType => PrintType.pdf;
  
  @override
  bool get isAvailable => true; // Sempre disponível
  
  @override
  Future<void> initialize() async {
    // PDF não precisa inicializar
  }
  
  @override
  Future<void> disconnect() async {
    // Nada a fazer
  }
  
  @override
  Future<PrintResult> printComanda(PrintData data) async {
    try {
      debugPrint('📄 Gerando PDF da comanda...');
      
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Cabeçalho
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        data.header.title,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (data.header.subtitle != null)
                        pw.Text(
                          data.header.subtitle!,
                          style: pw.TextStyle(fontSize: 12),
                        ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        _formatDateTime(data.header.dateTime),
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                pw.Divider(),
                pw.SizedBox(height: 8),
                
                // Informações
                if (data.entityInfo.mesaNome != null)
                  pw.Text('Mesa: ${data.entityInfo.mesaNome}', style: pw.TextStyle(fontSize: 10)),
                if (data.entityInfo.comandaCodigo != null)
                  pw.Text('Comanda: ${data.entityInfo.comandaCodigo}', style: pw.TextStyle(fontSize: 10)),
                pw.Text('Cliente: ${data.entityInfo.clienteNome}', style: pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.SizedBox(height: 8),
                
                // Itens
                ...data.items.map((item) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item.produtoNome,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      if (item.produtoVariacaoNome != null)
                        pw.Text(
                          '  Variação: ${item.produtoVariacaoNome}',
                          style: pw.TextStyle(fontSize: 9),
                        ),
                      pw.Text(
                        '${item.quantidade.toStringAsFixed(0)}x ${_formatCurrency(item.precoUnitario)} = ${_formatCurrency(item.valorTotal)}',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      if (item.componentesRemovidos.isNotEmpty)
                        pw.Text(
                          '  Sem: ${item.componentesRemovidos.join(', ')}',
                          style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
                        ),
                    ],
                  ),
                )),
                
                pw.Divider(),
                pw.SizedBox(height: 8),
                
                // Totais
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('SUBTOTAL:', style: pw.TextStyle(fontSize: 10)),
                    pw.Text(_formatCurrency(data.totals.subtotal), style: pw.TextStyle(fontSize: 10)),
                  ],
                ),
                if (data.totals.descontoTotal > 0)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 4),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('DESCONTO:', style: pw.TextStyle(fontSize: 10)),
                        pw.Text(_formatCurrency(-data.totals.descontoTotal), style: pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TOTAL:',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        _formatCurrency(data.totals.valorTotal),
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Rodapé
                if (data.footer.message != null) ...[
                  pw.SizedBox(height: 16),
                  pw.Divider(),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    data.footer.message!,
                    style: pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ],
            );
          },
        ),
      );
      
      // Compartilhar/abrir o PDF
      final pdfBytes = await pdf.save();
      
      // Printing.layoutPdf funciona em todas as plataformas:
      // - Web: abre visualizador do navegador com opção de download
      // - Mobile: abre visualizador nativo com opção de compartilhar
      // - Desktop: abre visualizador de PDF padrão
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
      
      debugPrint('✅ PDF gerado e compartilhado com sucesso');
      
      return PrintResult(
        success: true,
        printJobId: 'PDF-${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao gerar PDF: $e');
      debugPrint('Stack trace: $stackTrace');
      return PrintResult(
        success: false,
        errorMessage: 'Erro ao gerar PDF: ${e.toString()}',
      );
    }
  }
  
  @override
  Future<PrintResult> printNfce(NfcePrintData data) async {
    try {
      debugPrint('📄 Gerando PDF da NFC-e...');
      
      // Gerar QR Code antes de criar o PDF (se houver)
      Uint8List? qrCodeImageBytes;
      if (data.qrCodeTexto != null && data.qrCodeTexto!.isNotEmpty) {
        qrCodeImageBytes = await _gerarQrCodeImagem(data.qrCodeTexto!);
      }
      
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // ========== CABEÇALHO - DADOS DO EMITENTE ==========
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        data.empresaRazaoSocial,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      if (data.empresaNomeFantasia != null && data.empresaNomeFantasia!.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 4),
                          child: pw.Text(
                            data.empresaNomeFantasia!,
                            style: const pw.TextStyle(fontSize: 12),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'CNPJ: ${_formatCNPJ(data.empresaCnpj)}',
                        style: const pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.Text(
                        'IE: ${data.empresaInscricaoEstadual}',
                        style: const pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.center,
                      ),
                      if (data.empresaEnderecoCompleto != null && data.empresaEnderecoCompleto!.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 4),
                          child: pw.Text(
                            data.empresaEnderecoCompleto!,
                            style: const pw.TextStyle(fontSize: 9),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      if (data.empresaTelefone != null && data.empresaTelefone!.isNotEmpty)
                        pw.Text(
                          'Tel: ${data.empresaTelefone}',
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 16),
                pw.Divider(),
                pw.SizedBox(height: 16),
                
                // ========== DADOS DA NOTA FISCAL ==========
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'DANFE NFC-e',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Nº ${data.numero}  Série ${data.serie}',
                        style: const pw.TextStyle(fontSize: 11),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 8),
                      if (data.chaveAcesso.isNotEmpty) ...[
                        pw.Text(
                          'Chave de Acesso:',
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _formatarChaveAcesso(data.chaveAcesso),
                          style: const pw.TextStyle(fontSize: 8),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Emissão: ${_formatDateTime(data.dataEmissao)}',
                        style: const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.center,
                      ),
                      if (data.dataAutorizacao != null)
                        pw.Text(
                          'Autorização: ${_formatDateTime(data.dataAutorizacao!)}',
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                      if (data.protocoloAutorizacao != null && data.protocoloAutorizacao!.isNotEmpty)
                        pw.Text(
                          'Protocolo: ${data.protocoloAutorizacao}',
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 16),
                pw.Divider(),
                pw.SizedBox(height: 16),
                
                // ========== DADOS DO CLIENTE (se informado) ==========
                if (data.clienteNome != null && data.clienteNome!.isNotEmpty) ...[
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'CONSUMIDOR',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Nome: ${data.clienteNome}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        if (data.clienteCPF != null && data.clienteCPF!.isNotEmpty)
                          pw.Text(
                            'CPF: ${_formatCPF(data.clienteCPF!)}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Divider(),
                  pw.SizedBox(height: 16),
                ],
                
                // ========== ITENS ==========
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ITENS',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      ...data.itens.map((item) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 12),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                item.descricao,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                () {
                                  var codigoInfo = 'Cód: ${item.codigo}';
                                  if (item.ncm != null && item.ncm!.isNotEmpty) {
                                    codigoInfo += '  NCM: ${item.ncm}';
                                  }
                                  if (item.cfop != null && item.cfop!.isNotEmpty) {
                                    codigoInfo += '  CFOP: ${item.cfop}';
                                  }
                                  return codigoInfo;
                                }(),
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                    '${item.quantidade.toStringAsFixed(2)} ${item.unidade} x ${_formatCurrency(item.valorUnitario)}',
                                    style: pw.TextStyle(fontSize: 9),
                                  ),
                                  pw.Text(
                                    _formatCurrency(item.valorTotal),
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 16),
                pw.Divider(),
                pw.SizedBox(height: 16),
                
                // ========== TOTAIS ==========
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'TOTAIS',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Subtotal:',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.Text(
                            _formatCurrency(data.valorTotalProdutos),
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                      if (data.valorTotalDesconto > 0)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 4),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Desconto:',
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                              pw.Text(
                                _formatCurrency(data.valorTotalDesconto),
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      if (data.valorTotalImpostos > 0)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 4),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Impostos:',
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                              pw.Text(
                                _formatCurrency(data.valorTotalImpostos),
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      pw.SizedBox(height: 8),
                      pw.Divider(),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'TOTAL:',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            _formatCurrency(data.valorTotalNota),
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // ========== FORMAS DE PAGAMENTO ==========
                if (data.pagamentos.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Divider(),
                  pw.SizedBox(height: 16),
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FORMA DE PAGAMENTO',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        ...data.pagamentos.map((pagamento) {
                          return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 4),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  pagamento.formaPagamento,
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                                pw.Row(
                                  children: [
                                    pw.Text(
                                      _formatCurrency(pagamento.valor),
                                      style: const pw.TextStyle(fontSize: 10),
                                    ),
                                    if (pagamento.troco != null && pagamento.troco! > 0)
                                      pw.Text(
                                        ' (Troco: ${_formatCurrency(pagamento.troco!)})',
                                        style: const pw.TextStyle(fontSize: 9),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
                
                // ========== QR CODE ==========
                if (data.qrCodeTexto != null && data.qrCodeTexto!.isNotEmpty) ...[
                  pw.SizedBox(height: 24),
                  pw.Divider(),
                  pw.SizedBox(height: 16),
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'Consulte pela Chave de Acesso em:',
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                        if (data.urlConsultaChave != null && data.urlConsultaChave!.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 4),
                            child: pw.Text(
                              data.urlConsultaChave!,
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        pw.SizedBox(height: 16),
                        // QR Code (já gerado anteriormente)
                        if (qrCodeImageBytes != null)
                          pw.Image(
                            pw.MemoryImage(qrCodeImageBytes),
                            width: 150,
                            height: 150,
                          )
                        else
                          pw.Text(
                            'QR Code não disponível',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                      ],
                    ),
                  ),
                ],
                
                // ========== INFORMAÇÕES ADICIONAIS ==========
                if (data.informacoesAdicionais != null && data.informacoesAdicionais!.isNotEmpty) ...[
                  pw.SizedBox(height: 24),
                  pw.Divider(),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    data.informacoesAdicionais!,
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
                
                pw.SizedBox(height: 24),
                pw.Divider(),
                pw.SizedBox(height: 16),
                
                // ========== RODAPÉ ==========
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Documento Auxiliar da Nota Fiscal de',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.Text(
                        'Consumidor Eletrônica',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Este documento não substitui a consulta',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.Text(
                        'pela Chave de Acesso',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
      
      // Compartilhar/abrir o PDF
      final pdfBytes = await pdf.save();
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
      
      debugPrint('✅ PDF da NFC-e gerado e compartilhado com sucesso');
      
      return PrintResult(
        success: true,
        printJobId: 'PDF-NFCE-${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao gerar PDF da NFC-e: $e');
      debugPrint('Stack trace: $stackTrace');
    return PrintResult(
      success: false,
        errorMessage: 'Erro ao gerar PDF da NFC-e: ${e.toString()}',
    );
    }
  }
  
  @override
  Future<bool> checkPrinterStatus() async {
    return true; // PDF sempre disponível
  }
  
  String _formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  /// Formata CNPJ (14 dígitos) para formato XX.XXX.XXX/XXXX-XX
  String _formatCNPJ(String cnpj) {
    final cleaned = cnpj.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length != 14) return cnpj;
    return '${cleaned.substring(0, 2)}.${cleaned.substring(2, 5)}.${cleaned.substring(5, 8)}/${cleaned.substring(8, 12)}-${cleaned.substring(12, 14)}';
  }
  
  /// Formata CPF (11 dígitos) para formato XXX.XXX.XXX-XX
  String _formatCPF(String cpf) {
    final cleaned = cpf.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length != 11) return cpf;
    return '${cleaned.substring(0, 3)}.${cleaned.substring(3, 6)}.${cleaned.substring(6, 9)}-${cleaned.substring(9, 11)}';
  }
  
  /// Formata chave de acesso (44 dígitos) em grupos de 4
  String _formatarChaveAcesso(String chave) {
    final cleaned = chave.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length != 44) return chave;
    final grupos = <String>[];
    for (int i = 0; i < cleaned.length; i += 4) {
      final tamanho = (i + 4 <= cleaned.length) ? 4 : cleaned.length - i;
      grupos.add(cleaned.substring(i, i + tamanho));
    }
    return grupos.join(' ');
  }
  
  /// Gera QR Code como imagem PNG para incluir no PDF
  Future<Uint8List?> _gerarQrCodeImagem(String qrCodeTexto) async {
    try {
      debugPrint('🔲 Gerando QR Code para PDF...');
      
      // Tamanho do QR Code para PDF (maior que para impressora térmica)
      const qrSize = 300.0;
      const padding = 20.0;
      const totalSize = qrSize + (padding * 2);
      
      // Criar QR Code painter
      final qrPainter = QrPainter(
        data: qrCodeTexto,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        color: const ui.Color(0xFF000000),
        emptyColor: const ui.Color(0xFFFFFFFF),
      );
      
      // Criar canvas
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Pintar fundo branco
      final backgroundPaint = Paint()..color = const ui.Color(0xFFFFFFFF);
      canvas.drawRect(Rect.fromLTWH(0, 0, totalSize, totalSize), backgroundPaint);
      
      // Pintar QR Code centralizado
      canvas.save();
      canvas.translate(padding, padding);
      qrPainter.paint(canvas, Size(qrSize, qrSize));
      canvas.restore();
      
      // Converter para imagem
      final picture = recorder.endRecording();
      final image = await picture.toImage(totalSize.toInt(), totalSize.toInt());
      
      // Converter para PNG bytes
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('❌ Erro: byteData é null');
        return null;
      }
      
      final pngBytes = byteData.buffer.asUint8List();
      debugPrint('✅ QR Code gerado para PDF: ${pngBytes.length} bytes');
      
      return pngBytes;
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao gerar QR Code para PDF: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }
}

