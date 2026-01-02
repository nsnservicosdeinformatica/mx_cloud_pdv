import 'pagamento_venda_dto.dart';
import 'nota_fiscal_info_dto.dart';

/// DTO para venda completa (incluindo pagamentos)
class VendaDto {
  final String id;
  final String empresaId;
  
  // Contexto
  final String? mesaId;
  final String? comandaId;
  final String? veiculoId;
  final String? mesaNome;
  final String? comandaCodigo;
  final String? veiculoPlaca;
  final String? contextoNome;
  final String? contextoDescricao;
  
  // Cliente
  final String? clienteId;
  final String clienteNome;
  final String? clienteCPF;
  final String? clienteCNPJ;
  
  // Status
  final int status; // StatusVenda enum
  
  // Datas
  final DateTime dataCriacao;
  final DateTime? dataFechamento;
  final DateTime? dataPagamento;
  final DateTime? dataCancelamento;
  
  // Totais
  final double subtotal;
  final double descontoTotal;
  final double acrescimoTotal;
  final double impostosTotal;
  final double freteTotal;
  final double valorTotal;
  
    // Pagamentos
    final List<PagamentoVendaDto> pagamentos;
    
    // Nota Fiscal emitida (a mais recente da venda)
    final NotaFiscalInfoDto? notaFiscal;
  
  VendaDto({
    required this.id,
    required this.empresaId,
    this.mesaId,
    this.comandaId,
    this.veiculoId,
    this.mesaNome,
    this.comandaCodigo,
    this.veiculoPlaca,
    this.contextoNome,
    this.contextoDescricao,
    this.clienteId,
    required this.clienteNome,
    this.clienteCPF,
    this.clienteCNPJ,
    required this.status,
    required this.dataCriacao,
    this.dataFechamento,
    this.dataPagamento,
    this.dataCancelamento,
    required this.subtotal,
    required this.descontoTotal,
    required this.acrescimoTotal,
    required this.impostosTotal,
    required this.freteTotal,
    required this.valorTotal,
    required this.pagamentos,
    this.notaFiscal,
  });

  factory VendaDto.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final id = idValue is String ? idValue : idValue?.toString() ?? '';

    final empresaIdValue = json['empresaId'];
    final empresaId = empresaIdValue is String ? empresaIdValue : empresaIdValue?.toString() ?? '';

    final mesaIdValue = json['mesaId'];
    final mesaId = mesaIdValue?.toString();

    final comandaIdValue = json['comandaId'];
    final comandaId = comandaIdValue?.toString();

    final veiculoIdValue = json['veiculoId'];
    final veiculoId = veiculoIdValue?.toString();

    final clienteIdValue = json['clienteId'];
    final clienteId = clienteIdValue?.toString();

    final statusValue = json['status'];
    final status = statusValue is int ? statusValue : (statusValue != null ? int.tryParse(statusValue.toString()) ?? 0 : 0);

    final dataCriacaoValue = json['dataCriacao'];
    final dataCriacao = dataCriacaoValue is String 
        ? DateTime.tryParse(dataCriacaoValue) ?? DateTime.now()
        : (dataCriacaoValue is DateTime ? dataCriacaoValue : DateTime.now());

    final dataFechamentoValue = json['dataFechamento'];
    final DateTime? dataFechamento = dataFechamentoValue != null
        ? (dataFechamentoValue is String 
            ? DateTime.tryParse(dataFechamentoValue)
            : (dataFechamentoValue is DateTime ? dataFechamentoValue : null))
        : null;

    final dataPagamentoValue = json['dataPagamento'];
    final DateTime? dataPagamento = dataPagamentoValue != null
        ? (dataPagamentoValue is String 
            ? DateTime.tryParse(dataPagamentoValue)
            : (dataPagamentoValue is DateTime ? dataPagamentoValue : null))
        : null;

    final dataCancelamentoValue = json['dataCancelamento'];
    final DateTime? dataCancelamento = dataCancelamentoValue != null
        ? (dataCancelamentoValue is String 
            ? DateTime.tryParse(dataCancelamentoValue)
            : (dataCancelamentoValue is DateTime ? dataCancelamentoValue : null))
        : null;

    final subtotal = (json['subtotal'] as num?)?.toDouble() ?? 0.0;
    final descontoTotal = (json['descontoTotal'] as num?)?.toDouble() ?? 0.0;
    final acrescimoTotal = (json['acrescimoTotal'] as num?)?.toDouble() ?? 0.0;
    final impostosTotal = (json['impostosTotal'] as num?)?.toDouble() ?? 0.0;
    final freteTotal = (json['freteTotal'] as num?)?.toDouble() ?? 0.0;
    final valorTotal = (json['valorTotal'] as num?)?.toDouble() ?? 0.0;

    final pagamentosJson = json['pagamentos'] as List<dynamic>? ?? [];
    final pagamentos = pagamentosJson.map((p) => PagamentoVendaDto.fromJson(p as Map<String, dynamic>)).toList();

    final notaFiscalJson = json['notaFiscal'] as Map<String, dynamic>?;
    final NotaFiscalInfoDto? notaFiscal = notaFiscalJson != null
        ? NotaFiscalInfoDto.fromJson(notaFiscalJson)
        : null;

    return VendaDto(
      id: id,
      empresaId: empresaId,
      mesaId: mesaId,
      comandaId: comandaId,
      veiculoId: veiculoId,
      mesaNome: json['mesaNome'] as String?,
      comandaCodigo: json['comandaCodigo'] as String?,
      veiculoPlaca: json['veiculoPlaca'] as String?,
      contextoNome: json['contextoNome'] as String?,
      contextoDescricao: json['contextoDescricao'] as String?,
      clienteId: clienteId,
      clienteNome: json['clienteNome'] as String? ?? '',
      clienteCPF: json['clienteCPF'] as String?,
      clienteCNPJ: json['clienteCNPJ'] as String?,
      status: status,
      dataCriacao: dataCriacao,
      dataFechamento: dataFechamento,
      dataPagamento: dataPagamento,
      dataCancelamento: dataCancelamento,
      subtotal: subtotal,
      descontoTotal: descontoTotal,
      acrescimoTotal: acrescimoTotal,
      impostosTotal: impostosTotal,
      freteTotal: freteTotal,
      valorTotal: valorTotal,
      pagamentos: pagamentos,
      notaFiscal: notaFiscal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'empresaId': empresaId,
      'mesaId': mesaId,
      'comandaId': comandaId,
      'veiculoId': veiculoId,
      'mesaNome': mesaNome,
      'comandaCodigo': comandaCodigo,
      'veiculoPlaca': veiculoPlaca,
      'contextoNome': contextoNome,
      'contextoDescricao': contextoDescricao,
      'clienteId': clienteId,
      'clienteNome': clienteNome,
      'clienteCPF': clienteCPF,
      'clienteCNPJ': clienteCNPJ,
      'status': status,
      'dataCriacao': dataCriacao.toIso8601String(),
      'dataFechamento': dataFechamento?.toIso8601String(),
      'dataPagamento': dataPagamento?.toIso8601String(),
      'dataCancelamento': dataCancelamento?.toIso8601String(),
      'subtotal': subtotal,
      'descontoTotal': descontoTotal,
      'acrescimoTotal': acrescimoTotal,
      'impostosTotal': impostosTotal,
      'freteTotal': freteTotal,
      'valorTotal': valorTotal,
      'pagamentos': pagamentos.map((p) => p.toJson()).toList(),
      'notaFiscal': notaFiscal?.toJson(),
    };
  }

  /// Total pago (soma dos pagamentos confirmados)
  double get totalPago {
    return pagamentos
        .where((p) => p.status == 2 && !p.isCancelado) // StatusPagamento.Confirmado = 2
        .fold(0.0, (sum, p) => sum + p.valor);
  }

  /// Saldo restante
  double get saldoRestante {
    return valorTotal - totalPago;
  }
}
