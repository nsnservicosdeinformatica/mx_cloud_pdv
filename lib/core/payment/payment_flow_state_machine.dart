import 'package:flutter/foundation.dart';
import 'payment_flow_state.dart';

/// Exceção lançada quando uma transição de estado é inválida
class StateMachineException implements Exception {
  final String message;
  final PaymentFlowState fromState;
  final PaymentFlowState toState;
  
  StateMachineException({
    required this.message,
    required this.fromState,
    required this.toState,
  });
  
  @override
  String toString() {
    return 'StateMachineException: $message (${fromState.description} → ${toState.description})';
  }
}

/// Máquina de Estados para o fluxo de pagamento
/// 
/// Gerencia os estados e valida transições entre estados.
/// Garante que o fluxo siga uma sequência válida.
/// 
/// **Exemplo de uso:**
/// ```dart
/// final stateMachine = PaymentFlowStateMachine();
/// 
/// // Tenta fazer transição
/// if (stateMachine.transitionTo(PaymentFlowState.processingPayment)) {
///   // Transição válida, estado atualizado
/// } else {
///   // Transição inválida, estado não mudou
/// }
/// ```
class PaymentFlowStateMachine {
  PaymentFlowState _currentState = PaymentFlowState.idle;
  final List<PaymentFlowState> _stateHistory = [];
  
  /// Construtor - inicializa o histórico com o estado inicial
  PaymentFlowStateMachine() {
    _stateHistory.add(_currentState);
    debugPrint('🔄 [StateMachine] Inicializado com estado: ${_currentState.description}');
  }
  
  /// Estado atual
  PaymentFlowState get currentState => _currentState;
  
  /// Histórico de estados (útil para debug)
  List<PaymentFlowState> get stateHistory => List.unmodifiable(_stateHistory);
  
  /// Tenta fazer transição para novo estado
  /// 
  /// **Retorna:**
  /// - `true` se transição foi bem-sucedida
  /// - `false` se transição é inválida (estado não muda)
  /// 
  /// **Lança:**
  /// - `StateMachineException` se `throwOnInvalid` for `true` e transição for inválida
  bool transitionTo(
    PaymentFlowState newState, {
    bool throwOnInvalid = false,
  }) {
    if (!_isValidTransition(_currentState, newState)) {
      final exception = StateMachineException(
        message: 'Transição inválida',
        fromState: _currentState,
        toState: newState,
      );
      
      debugPrint('❌ [StateMachine] $exception');
      
      if (throwOnInvalid) {
        throw exception;
      }
      
      return false;
    }
    
    debugPrint('✅ [StateMachine] Transição: ${_currentState.description} → ${newState.description}');
    
    _stateHistory.add(_currentState);
    _currentState = newState;
    
    return true;
  }
  
  /// Valida se uma transição é permitida
  /// 
  /// Define as regras de transição entre estados.
  /// Cada estado só pode transicionar para estados válidos.
  bool _isValidTransition(PaymentFlowState from, PaymentFlowState to) {
    // Se já está no estado destino, permite (idempotência)
    if (from == to) {
      return true;
    }
    
    // Estados finais não podem transicionar (exceto reset)
    if (from.isFinal && to != PaymentFlowState.idle) {
      return false;
    }
    
    // Define regras de transição baseado no estado atual
    switch (from) {
      // ========== ESTADOS INICIAIS ==========
      
      case PaymentFlowState.idle:
        return to == PaymentFlowState.initializing ||
               to == PaymentFlowState.paymentMethodSelected ||
               to == PaymentFlowState.processingPayment ||
               to == PaymentFlowState.readyToComplete || // 🆕 Permite ir direto para readyToComplete se saldo já zerou
               to == PaymentFlowState.cancelled;
      
      case PaymentFlowState.initializing:
        return to == PaymentFlowState.idle ||
               to == PaymentFlowState.paymentMethodSelected ||
               to == PaymentFlowState.error;
      
      // ========== ESTADOS DE PAGAMENTO ==========
      
      case PaymentFlowState.paymentMethodSelected:
        return to == PaymentFlowState.processingPayment ||
               to == PaymentFlowState.idle ||
               to == PaymentFlowState.cancelled;
      
      case PaymentFlowState.processingPayment:
        return to == PaymentFlowState.paymentProcessed ||
               to == PaymentFlowState.paymentFailed ||
               to == PaymentFlowState.cancelled ||
               to == PaymentFlowState.error;
      
      case PaymentFlowState.paymentProcessed:
        return to == PaymentFlowState.registeringPayment || // 🆕 Novo estado
               to == PaymentFlowState.readyToComplete ||
               to == PaymentFlowState.idle || // Pagamento parcial (volta para permitir mais pagamentos)
               to == PaymentFlowState.completed || // Pagamento único, sem nota
               to == PaymentFlowState.error;
      
      case PaymentFlowState.registeringPayment:
        return to == PaymentFlowState.readyToComplete ||
               to == PaymentFlowState.idle || // Pagamento parcial (volta para permitir mais pagamentos)
               to == PaymentFlowState.paymentFailed || // Se registro falhar
               to == PaymentFlowState.error;
      
      case PaymentFlowState.paymentFailed:
        return to == PaymentFlowState.processingPayment || // Retry
               to == PaymentFlowState.idle || // Cancelar
               to == PaymentFlowState.error;
      
      // ========== ESTADOS DE CONCLUSÃO ==========
      
      case PaymentFlowState.readyToComplete:
        return to == PaymentFlowState.concludingSale ||
               to == PaymentFlowState.idle || // Cancelar
               to == PaymentFlowState.cancelled;
      
      case PaymentFlowState.concludingSale:
        return to == PaymentFlowState.saleCompleted ||
               to == PaymentFlowState.completionFailed ||
               to == PaymentFlowState.error;
      
      case PaymentFlowState.saleCompleted:
        return to == PaymentFlowState.creatingInvoice ||
               to == PaymentFlowState.invoiceAuthorized || // 🆕 Nota já autorizada (foi criada durante conclusão)
               to == PaymentFlowState.completed || // Sem nota fiscal
               to == PaymentFlowState.error;
      
      case PaymentFlowState.completionFailed:
        return to == PaymentFlowState.concludingSale || // Retry
               to == PaymentFlowState.idle || // Cancelar
               to == PaymentFlowState.error;
      
      // ========== ESTADOS DE EMISSÃO ==========
      
      case PaymentFlowState.creatingInvoice:
        return to == PaymentFlowState.sendingToSefaz ||
               to == PaymentFlowState.invoiceFailed ||
               to == PaymentFlowState.error;
      
      case PaymentFlowState.sendingToSefaz:
        return to == PaymentFlowState.invoiceAuthorized ||
               to == PaymentFlowState.invoiceFailed ||
               to == PaymentFlowState.error;
      
      case PaymentFlowState.invoiceAuthorized:
        return to == PaymentFlowState.printingInvoice ||
               to == PaymentFlowState.completed || // Pular impressão
               to == PaymentFlowState.error;
      
      case PaymentFlowState.invoiceFailed:
        return to == PaymentFlowState.creatingInvoice || // Retry
               to == PaymentFlowState.completed || // Pular emissão
               to == PaymentFlowState.error;
      
      // ========== ESTADOS DE IMPRESSÃO ==========
      
      case PaymentFlowState.printingInvoice:
        return to == PaymentFlowState.printSuccess ||
               to == PaymentFlowState.printFailed ||
               to == PaymentFlowState.error;
      
      case PaymentFlowState.printSuccess:
        return to == PaymentFlowState.completed ||
               to == PaymentFlowState.error;
      
      case PaymentFlowState.printFailed:
        return to == PaymentFlowState.printingInvoice || // Retry
               to == PaymentFlowState.completed || // Pular impressão
               to == PaymentFlowState.error;
      
      // ========== ESTADOS FINAIS ==========
      
      case PaymentFlowState.completed:
        return to == PaymentFlowState.idle; // Reset para novo fluxo
      
      case PaymentFlowState.cancelled:
        return to == PaymentFlowState.idle; // Reset para novo fluxo
      
      case PaymentFlowState.error:
        return to == PaymentFlowState.idle || // Reset
               to == PaymentFlowState.cancelled;
    }
  }
  
  // ========== MÉTODOS DE VALIDAÇÃO ==========
  
  /// Verifica se pode processar pagamento
  bool canProcessPayment() {
    return _currentState == PaymentFlowState.idle ||
           _currentState == PaymentFlowState.paymentMethodSelected;
  }
  
  /// Verifica se pode concluir venda
  bool canConcludeSale() {
    return _currentState == PaymentFlowState.readyToComplete;
  }
  
  /// Verifica se pode fazer retry
  bool canRetry() {
    return _currentState.canRetry;
  }
  
  /// Verifica se está em um estado de processamento
  bool get isProcessing => _currentState.isProcessing;
  
  /// Verifica se está em um estado de sucesso
  bool get isSuccess => _currentState.isSuccess;
  
  /// Verifica se está em um estado de erro
  bool get isError => _currentState.isError;
  
  /// Verifica se está em um estado final
  bool get isFinal => _currentState.isFinal;
  
  // ========== MÉTODOS DE CONTROLE ==========
  
  /// Reseta para estado inicial
  /// 
  /// Limpa o histórico e volta para o estado idle, permitindo iniciar um novo fluxo.
  void reset() {
    debugPrint('🔄 [StateMachine] Resetando para estado inicial');
    debugPrint('🔄 Estado antes: ${_currentState.description}');
    debugPrint('🔄 Histórico antes: ${_stateHistory.length} estados');
    
    _stateHistory.clear();
    _currentState = PaymentFlowState.idle;
    _stateHistory.add(_currentState); // Adiciona idle ao histórico
    
    debugPrint('🔄 Estado após: ${_currentState.description}');
    debugPrint('🔄 canProcessPayment: ${canProcessPayment()}');
  }
  
  /// Cancela o fluxo atual
  bool cancel() {
    return transitionTo(PaymentFlowState.cancelled);
  }
  
  /// Marca como erro genérico
  bool markAsError() {
    return transitionTo(PaymentFlowState.error);
  }
  
  /// Retorna para estado anterior (útil para undo)
  bool goBack() {
    if (_stateHistory.isEmpty) {
      return false;
    }
    
    final previousState = _stateHistory.last;
    _stateHistory.removeLast();
    
    debugPrint('⏪ [StateMachine] Voltando para: ${previousState.description}');
    _currentState = previousState;
    
    return true;
  }
}

