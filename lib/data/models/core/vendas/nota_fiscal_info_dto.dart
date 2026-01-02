/// DTO simplificado com informações essenciais da nota fiscal para exibição/impressão
class NotaFiscalInfoDto {
  final String id;
  final String? numero;
  final String? serie;
  final String? chaveAcesso;
  final String? protocoloAutorizacao;
  final String? urlDANFE;
  final int situacao; // SituacaoNotaFiscal enum
  final int? tipoEmissao; // TipoEmissao enum
  final String? erroIntegracao;
  final DateTime dataEmissao;
  final DateTime? dataAutorizacao;

  NotaFiscalInfoDto({
    required this.id,
    this.numero,
    this.serie,
    this.chaveAcesso,
    this.protocoloAutorizacao,
    this.urlDANFE,
    required this.situacao,
    this.tipoEmissao,
    this.erroIntegracao,
    required this.dataEmissao,
    this.dataAutorizacao,
  });

  factory NotaFiscalInfoDto.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final id = idValue is String ? idValue : idValue?.toString() ?? '';

    final dataEmissaoValue = json['dataEmissao'];
    final dataEmissao = dataEmissaoValue is String 
        ? DateTime.tryParse(dataEmissaoValue) ?? DateTime.now()
        : (dataEmissaoValue is DateTime ? dataEmissaoValue : DateTime.now());

    final dataAutorizacaoValue = json['dataAutorizacao'];
    final DateTime? dataAutorizacao = dataAutorizacaoValue != null
        ? (dataAutorizacaoValue is String 
            ? DateTime.tryParse(dataAutorizacaoValue)
            : (dataAutorizacaoValue is DateTime ? dataAutorizacaoValue : null))
        : null;

    final situacaoValue = json['situacao'];
    final situacao = situacaoValue is int ? situacaoValue : (situacaoValue != null ? int.tryParse(situacaoValue.toString()) ?? 0 : 0);

    final tipoEmissaoValue = json['tipoEmissao'];
    final int? tipoEmissao = tipoEmissaoValue != null
        ? (tipoEmissaoValue is int ? tipoEmissaoValue : int.tryParse(tipoEmissaoValue.toString()))
        : null;

    return NotaFiscalInfoDto(
      id: id,
      numero: json['numero'] as String?,
      serie: json['serie'] as String?,
      chaveAcesso: json['chaveAcesso'] as String?,
      protocoloAutorizacao: json['protocoloAutorizacao'] as String?,
      urlDANFE: json['urlDANFE'] as String?,
      situacao: situacao,
      tipoEmissao: tipoEmissao,
      erroIntegracao: json['erroIntegracao'] as String?,
      dataEmissao: dataEmissao,
      dataAutorizacao: dataAutorizacao,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numero': numero,
      'serie': serie,
      'chaveAcesso': chaveAcesso,
      'protocoloAutorizacao': protocoloAutorizacao,
      'urlDANFE': urlDANFE,
      'situacao': situacao,
      'tipoEmissao': tipoEmissao,
      'erroIntegracao': erroIntegracao,
      'dataEmissao': dataEmissao.toIso8601String(),
      'dataAutorizacao': dataAutorizacao?.toIso8601String(),
    };
  }

  /// Verifica se a nota fiscal foi autorizada (situacao = 2 = Emitida)
  bool get foiAutorizada => situacao == 2; // SituacaoNotaFiscal.Emitida = 2
}

