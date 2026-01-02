/// Dados estruturados para impressão de NFC-e
class NfcePrintData {
  // Dados do Emitente
  final String empresaRazaoSocial;
  final String? empresaNomeFantasia;
  final String empresaCnpj;
  final String empresaInscricaoEstadual;
  final String? empresaEnderecoCompleto;
  final String? empresaTelefone;

  // Dados da Nota
  final String numero;
  final String serie;
  final String chaveAcesso;
  final DateTime dataEmissao;
  final DateTime? dataAutorizacao;
  final String? protocoloAutorizacao;
  final String situacao;
  final String? tipoEmissao;

  // Dados do Cliente
  final String? clienteNome;
  final String? clienteCPF;

  // Itens
  final List<NfceItemPrintData> itens;

  // Totais
  final double valorTotalProdutos;
  final double valorTotalDesconto;
  final double valorTotalAcrescimo;
  final double valorTotalImpostos;
  final double valorTotalNota;

  // Pagamentos
  final List<NfcePagamentoPrintData> pagamentos;

  // QR Code
  final String? qrCodeTexto;
  final String? urlConsultaChave;

  // Informações Adicionais
  final String? informacoesAdicionais;

  NfcePrintData({
    required this.empresaRazaoSocial,
    this.empresaNomeFantasia,
    required this.empresaCnpj,
    required this.empresaInscricaoEstadual,
    this.empresaEnderecoCompleto,
    this.empresaTelefone,
    required this.numero,
    required this.serie,
    required this.chaveAcesso,
    required this.dataEmissao,
    this.dataAutorizacao,
    this.protocoloAutorizacao,
    required this.situacao,
    this.tipoEmissao,
    this.clienteNome,
    this.clienteCPF,
    required this.itens,
    required this.valorTotalProdutos,
    required this.valorTotalDesconto,
    required this.valorTotalAcrescimo,
    required this.valorTotalImpostos,
    required this.valorTotalNota,
    required this.pagamentos,
    this.qrCodeTexto,
    this.urlConsultaChave,
    this.informacoesAdicionais,
  });

  factory NfcePrintData.fromJson(Map<String, dynamic> json) {
    return NfcePrintData(
      empresaRazaoSocial: json['empresaRazaoSocial'] as String,
      empresaNomeFantasia: json['empresaNomeFantasia'] as String?,
      empresaCnpj: json['empresaCnpj'] as String,
      empresaInscricaoEstadual: json['empresaInscricaoEstadual'] as String,
      empresaEnderecoCompleto: json['empresaEnderecoCompleto'] as String?,
      empresaTelefone: json['empresaTelefone'] as String?,
      numero: json['numero'] as String,
      serie: json['serie'] as String,
      chaveAcesso: json['chaveAcesso'] as String,
      dataEmissao: DateTime.parse(json['dataEmissao'] as String),
      dataAutorizacao: json['dataAutorizacao'] != null 
          ? DateTime.parse(json['dataAutorizacao'] as String) 
          : null,
      protocoloAutorizacao: json['protocoloAutorizacao'] as String?,
      situacao: json['situacao'] as String,
      tipoEmissao: json['tipoEmissao'] as String?,
      clienteNome: json['clienteNome'] as String?,
      clienteCPF: json['clienteCPF'] as String?,
      itens: (json['itens'] as List<dynamic>?)
          ?.map((item) => NfceItemPrintData.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      valorTotalProdutos: (json['valorTotalProdutos'] as num).toDouble(),
      valorTotalDesconto: (json['valorTotalDesconto'] as num).toDouble(),
      valorTotalAcrescimo: (json['valorTotalAcrescimo'] as num).toDouble(),
      valorTotalImpostos: (json['valorTotalImpostos'] as num).toDouble(),
      valorTotalNota: (json['valorTotalNota'] as num).toDouble(),
      pagamentos: (json['pagamentos'] as List<dynamic>?)
          ?.map((pag) => NfcePagamentoPrintData.fromJson(pag as Map<String, dynamic>))
          .toList() ?? [],
      qrCodeTexto: json['qrCodeTexto'] as String?,
      urlConsultaChave: json['urlConsultaChave'] as String?,
      informacoesAdicionais: json['informacoesAdicionais'] as String?,
    );
  }
}

class NfceItemPrintData {
  final String codigo;
  final String descricao;
  final String? ncm;
  final String? cfop;
  final String unidade;
  final double quantidade;
  final double valorUnitario;
  final double valorTotal;

  NfceItemPrintData({
    required this.codigo,
    required this.descricao,
    this.ncm,
    this.cfop,
    required this.unidade,
    required this.quantidade,
    required this.valorUnitario,
    required this.valorTotal,
  });

  factory NfceItemPrintData.fromJson(Map<String, dynamic> json) {
    return NfceItemPrintData(
      codigo: json['codigo'] as String,
      descricao: json['descricao'] as String,
      ncm: json['ncm'] as String?,
      cfop: json['cfop'] as String?,
      unidade: json['unidade'] as String,
      quantidade: (json['quantidade'] as num).toDouble(),
      valorUnitario: (json['valorUnitario'] as num).toDouble(),
      valorTotal: (json['valorTotal'] as num).toDouble(),
    );
  }
}

class NfcePagamentoPrintData {
  final String formaPagamento;
  final double valor;
  final double? troco;

  NfcePagamentoPrintData({
    required this.formaPagamento,
    required this.valor,
    this.troco,
  });

  factory NfcePagamentoPrintData.fromJson(Map<String, dynamic> json) {
    return NfcePagamentoPrintData(
      formaPagamento: json['formaPagamento'] as String,
      valor: (json['valor'] as num).toDouble(),
      troco: json['troco'] != null ? (json['troco'] as num).toDouble() : null,
    );
  }
}

