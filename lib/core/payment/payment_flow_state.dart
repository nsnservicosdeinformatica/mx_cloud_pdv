/// Estados possíveis do fluxo de pagamento
/// 
/// Define todos os estados que o fluxo de pagamento pode estar,
/// desde o início (idle) até a conclusão (completed).
enum PaymentFlowState {
  // ========== ESTADOS INICIAIS ==========
  
  /// Aguardando ação do usuário
  idle,
  
  /// Inicializando fluxo (carregando dados)
  initializing,
  
  // ========== ESTADOS DE PAGAMENTO ==========
  
  /// Método de pagamento selecionado (usuário escolheu como pagar)
  paymentMethodSelected,
  
  /// Processando pagamento (chamando SDK/API)
  processingPayment,
  
  /// Pagamento processado com sucesso
  paymentProcessed,
  
  /// Registrando pagamento no servidor (após processar via SDK)
  registeringPayment,
  
  /// Pagamento falhou
  paymentFailed,
  
  // ========== ESTADOS DE CONCLUSÃO ==========
  
  /// Saldo zerou, pronto para concluir venda
  readyToComplete,
  
  /// Concluindo venda no servidor
  concludingSale,
  
  /// Venda concluída com sucesso
  saleCompleted,
  
  /// Falha ao concluir venda
  completionFailed,
  
  // ========== ESTADOS DE EMISSÃO ==========
  
  /// Criando nota fiscal
  creatingInvoice,
  
  /// Enviando nota fiscal para SEFAZ
  sendingToSefaz,
  
  /// Nota fiscal autorizada pela SEFAZ
  invoiceAuthorized,
  
  /// Falha na emissão da nota fiscal
  invoiceFailed,
  
  // ========== ESTADOS DE IMPRESSÃO ==========
  
  /// Imprimindo nota fiscal
  printingInvoice,
  
  /// Impressão concluída com sucesso
  printSuccess,
  
  /// Falha na impressão
  printFailed,
  
  // ========== ESTADOS FINAIS ==========
  
  /// Fluxo completo com sucesso
  completed,
  
  /// Fluxo cancelado pelo usuário
  cancelled,
  
  /// Erro genérico
  error,
}

/// Extensões úteis para PaymentFlowState
extension PaymentFlowStateExtension on PaymentFlowState {
  /// Verifica se é um estado de processamento (mostra loading)
  bool get isProcessing {
    return this == PaymentFlowState.initializing ||
           this == PaymentFlowState.processingPayment ||
           this == PaymentFlowState.registeringPayment ||
           this == PaymentFlowState.concludingSale ||
           this == PaymentFlowState.creatingInvoice ||
           this == PaymentFlowState.sendingToSefaz ||
           this == PaymentFlowState.printingInvoice;
  }
  
  /// Verifica se é um estado de sucesso
  bool get isSuccess {
    return this == PaymentFlowState.paymentProcessed ||
           this == PaymentFlowState.saleCompleted ||
           this == PaymentFlowState.invoiceAuthorized ||
           this == PaymentFlowState.printSuccess ||
           this == PaymentFlowState.completed;
  }
  
  /// Verifica se é um estado de erro
  bool get isError {
    return this == PaymentFlowState.paymentFailed ||
           this == PaymentFlowState.completionFailed ||
           this == PaymentFlowState.invoiceFailed ||
           this == PaymentFlowState.printFailed ||
           this == PaymentFlowState.error;
  }
  
  /// Verifica se é um estado final (não pode mais fazer transições)
  bool get isFinal {
    return this == PaymentFlowState.completed ||
           this == PaymentFlowState.cancelled ||
           this == PaymentFlowState.error;
  }
  
  /// Verifica se pode fazer retry (estados de erro que permitem retry)
  bool get canRetry {
    return this == PaymentFlowState.paymentFailed ||
           this == PaymentFlowState.completionFailed ||
           this == PaymentFlowState.invoiceFailed ||
           this == PaymentFlowState.printFailed;
  }
  
  /// Descrição amigável do estado (para logs/UI)
  String get description {
    switch (this) {
      case PaymentFlowState.idle:
        return 'Aguardando ação';
      case PaymentFlowState.initializing:
        return 'Inicializando...';
      case PaymentFlowState.paymentMethodSelected:
        return 'Método selecionado';
      case PaymentFlowState.processingPayment:
        return 'Processando pagamento...';
      case PaymentFlowState.paymentProcessed:
        return 'Pagamento realizado';
      case PaymentFlowState.registeringPayment:
        return 'Registrando pagamento...';
      case PaymentFlowState.paymentFailed:
        return 'Pagamento falhou';
      case PaymentFlowState.readyToComplete:
        return 'Pronto para concluir';
      case PaymentFlowState.concludingSale:
        return 'Concluindo venda...';
      case PaymentFlowState.saleCompleted:
        return 'Venda concluída';
      case PaymentFlowState.completionFailed:
        return 'Falha ao concluir';
      case PaymentFlowState.creatingInvoice:
        return 'Criando nota fiscal...';
      case PaymentFlowState.sendingToSefaz:
        return 'Enviando para SEFAZ...';
      case PaymentFlowState.invoiceAuthorized:
        return 'Nota autorizada';
      case PaymentFlowState.invoiceFailed:
        return 'Falha na emissão';
      case PaymentFlowState.printingInvoice:
        return 'Imprimindo nota...';
      case PaymentFlowState.printSuccess:
        return 'Impressão concluída';
      case PaymentFlowState.printFailed:
        return 'Falha na impressão';
      case PaymentFlowState.completed:
        return 'Concluído';
      case PaymentFlowState.cancelled:
        return 'Cancelado';
      case PaymentFlowState.error:
        return 'Erro';
    }
  }
}

