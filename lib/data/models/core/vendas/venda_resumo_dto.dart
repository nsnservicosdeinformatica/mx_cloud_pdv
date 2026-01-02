/// DTO resumido de venda para seleção de agrupamento (apenas informações essenciais)
class VendaResumoDto {
  final String id;
  
  // Informações da comanda (se houver)
  final String? comandaId;
  final String? comandaCodigo;
  final String? comandaDescricao;
  
  // Totais
  final double valorTotal;
  final double totalPago;
  final double saldoRestante;
  
  // Quantidade de pedidos
  final int quantidadePedidos;
  
  // Data de criação
  final DateTime dataCriacao;
  
  // Indica se é venda sem comanda (vinculada diretamente à mesa)
  bool get isVendaSemComanda => comandaId == null;
  
  VendaResumoDto({
    required this.id,
    this.comandaId,
    this.comandaCodigo,
    this.comandaDescricao,
    required this.valorTotal,
    required this.totalPago,
    required this.saldoRestante,
    required this.quantidadePedidos,
    required this.dataCriacao,
  });
  
  factory VendaResumoDto.fromJson(Map<String, dynamic> json) {
    return VendaResumoDto(
      id: json['id'] as String,
      comandaId: json['comandaId'] as String?,
      comandaCodigo: json['comandaCodigo'] as String?,
      comandaDescricao: json['comandaDescricao'] as String?,
      valorTotal: (json['valorTotal'] as num).toDouble(),
      totalPago: (json['totalPago'] as num).toDouble(),
      saldoRestante: (json['saldoRestante'] as num).toDouble(),
      quantidadePedidos: json['quantidadePedidos'] as int,
      dataCriacao: DateTime.parse(json['dataCriacao'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'comandaId': comandaId,
      'comandaCodigo': comandaCodigo,
      'comandaDescricao': comandaDescricao,
      'valorTotal': valorTotal,
      'totalPago': totalPago,
      'saldoRestante': saldoRestante,
      'quantidadePedidos': quantidadePedidos,
      'dataCriacao': dataCriacao.toIso8601String(),
    };
  }
}

