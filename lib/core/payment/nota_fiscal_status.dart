/// Status detalhado da nota fiscal durante o fluxo de pagamento
/// 
/// Armazena informações completas sobre o estado da nota fiscal,
/// incluindo chave de acesso, protocolo, status de autorização, etc.
class NotaFiscalStatus {
  /// ID da nota fiscal
  final String id;
  
  /// Chave de acesso da nota fiscal (44 caracteres)
  final String? chaveAcesso;
  
  /// Protocolo de autorização da SEFAZ
  final String? protocoloAutorizacao;
  
  /// Status atual da nota fiscal
  final NotaFiscalStatusType status;
  
  /// Se a nota foi autorizada pela SEFAZ
  final bool foiAutorizada;
  
  /// Motivo de rejeição (se houver)
  final String? motivoRejeicao;
  
  /// Data e hora de autorização (se autorizada)
  final DateTime? dataAutorizacao;
  
  /// Número de tentativas de emissão realizadas
  final int tentativas;
  
  /// Mensagem de erro (se houver)
  final String? erro;
  
  NotaFiscalStatus({
    required this.id,
    this.chaveAcesso,
    this.protocoloAutorizacao,
    required this.status,
    required this.foiAutorizada,
    this.motivoRejeicao,
    this.dataAutorizacao,
    this.tentativas = 0,
    this.erro,
  });
  
  /// Cria um status a partir de dados da venda
  factory NotaFiscalStatus.fromVendaNotaFiscal({
    required String notaFiscalId,
    String? chaveAcesso,
    String? protocoloAutorizacao,
    required bool foiAutorizada,
    String? motivoRejeicao,
    DateTime? dataAutorizacao,
    int tentativas = 0,
  }) {
    return NotaFiscalStatus(
      id: notaFiscalId,
      chaveAcesso: chaveAcesso,
      protocoloAutorizacao: protocoloAutorizacao,
      status: foiAutorizada
          ? NotaFiscalStatusType.autorizada
          : motivoRejeicao != null
              ? NotaFiscalStatusType.rejeitada
              : NotaFiscalStatusType.enviando,
      foiAutorizada: foiAutorizada,
      motivoRejeicao: motivoRejeicao,
      dataAutorizacao: dataAutorizacao,
      tentativas: tentativas,
    );
  }
  
  /// Cria um status de erro
  factory NotaFiscalStatus.error({
    required String notaFiscalId,
    required String erro,
    int tentativas = 0,
  }) {
    return NotaFiscalStatus(
      id: notaFiscalId,
      status: NotaFiscalStatusType.erro,
      foiAutorizada: false,
      tentativas: tentativas,
      erro: erro,
    );
  }
  
  /// Cria uma cópia com campos atualizados
  NotaFiscalStatus copyWith({
    String? id,
    String? chaveAcesso,
    String? protocoloAutorizacao,
    NotaFiscalStatusType? status,
    bool? foiAutorizada,
    String? motivoRejeicao,
    DateTime? dataAutorizacao,
    int? tentativas,
    String? erro,
  }) {
    return NotaFiscalStatus(
      id: id ?? this.id,
      chaveAcesso: chaveAcesso ?? this.chaveAcesso,
      protocoloAutorizacao: protocoloAutorizacao ?? this.protocoloAutorizacao,
      status: status ?? this.status,
      foiAutorizada: foiAutorizada ?? this.foiAutorizada,
      motivoRejeicao: motivoRejeicao ?? this.motivoRejeicao,
      dataAutorizacao: dataAutorizacao ?? this.dataAutorizacao,
      tentativas: tentativas ?? this.tentativas,
      erro: erro ?? this.erro,
    );
  }
  
  /// Descrição amigável do status
  String get statusDescription {
    switch (status) {
      case NotaFiscalStatusType.criada:
        return 'Nota fiscal criada';
      case NotaFiscalStatusType.enviando:
        return 'Enviando para SEFAZ...';
      case NotaFiscalStatusType.autorizada:
        return 'Nota fiscal autorizada';
      case NotaFiscalStatusType.rejeitada:
        return 'Nota fiscal rejeitada';
      case NotaFiscalStatusType.cancelada:
        return 'Nota fiscal cancelada';
      case NotaFiscalStatusType.erro:
        return 'Erro ao processar nota fiscal';
    }
  }
  
  /// Se está em processamento
  bool get isProcessing {
    return status == NotaFiscalStatusType.criada ||
           status == NotaFiscalStatusType.enviando;
  }
  
  /// Se foi bem-sucedida
  bool get isSuccess {
    return status == NotaFiscalStatusType.autorizada;
  }
  
  /// Se falhou
  bool get isError {
    return status == NotaFiscalStatusType.rejeitada ||
           status == NotaFiscalStatusType.erro;
  }
  
  @override
  String toString() {
    return 'NotaFiscalStatus(id: $id, status: $status, foiAutorizada: $foiAutorizada, tentativas: $tentativas)';
  }
}

/// Tipos de status da nota fiscal
enum NotaFiscalStatusType {
  /// Nota fiscal foi criada localmente
  criada,
  
  /// Nota fiscal está sendo enviada para SEFAZ
  enviando,
  
  /// Nota fiscal foi autorizada pela SEFAZ
  autorizada,
  
  /// Nota fiscal foi rejeitada pela SEFAZ
  rejeitada,
  
  /// Nota fiscal foi cancelada
  cancelada,
  
  /// Erro ao processar nota fiscal
  erro,
}

