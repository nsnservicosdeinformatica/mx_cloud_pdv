import 'payment_transaction_data.dart';
import 'payment_ui_notifier.dart';

/// Interface base para providers de pagamento
/// 
/// Esta interface define o contrato que todos os providers de pagamento
/// devem seguir, independente da implementação (Cash, Stone POS, PIX, etc.)
abstract class PaymentProvider {
  /// Nome do provider (ex: "Stone", "GetNet", "Cash")
  String get providerName;
  
  /// Tipo de pagamento (POS, TEF, Cash)
  PaymentType get paymentType;
  
  /// Se o provider está disponível
  bool get isAvailable;
  
  /// Se o provider requer interação do usuário durante o processamento
  /// 
  /// **Exemplos:**
  /// - `true`: Stone POS (usuário precisa inserir/passar cartão)
  /// - `false`: Cash (não requer interação durante processamento)
  /// 
  /// **Uso:**
  /// - PaymentService verifica esta propriedade para decidir se deve
  ///   notificar UI sobre dialogs necessários
  bool get requiresUserInteraction;
  
  /// Processa um pagamento
  /// 
  /// **Parâmetros:**
  /// - [amount] - Valor a ser pago
  /// - [vendaId] - ID da venda
  /// - [additionalData] - Dados adicionais específicos do provider
  /// - [uiNotifier] - Notificador opcional para comunicar com UI
  /// 
  /// **Sobre uiNotifier:**
  /// - É opcional (pode ser null)
  /// - Providers que requerem interação do usuário devem usar para
  ///   notificar UI sobre eventos (ex: mostrar/esconder dialogs)
  /// - Providers que não requerem interação podem ignorar
  /// 
  /// **Exemplo de uso no provider:**
  /// ```dart
  /// // Mostrar dialog antes de processar
  /// uiNotifier?.notify(PaymentUINotification.showWaitingCard());
  /// 
  /// // Processar pagamento
  /// final result = await _sdk.processPayment(...);
  /// 
  /// // Esconder dialog após processar
  /// uiNotifier?.notify(PaymentUINotification.hideWaitingCard());
  /// ```
  Future<PaymentResult> processPayment({
    required double amount,
    required String vendaId,
    Map<String, dynamic>? additionalData,
    PaymentUINotifier? uiNotifier, // 🆕 Novo parâmetro opcional
  });
  
  /// Inicializa o provider
  /// 
  /// Deve ser chamado antes de processar pagamentos.
  /// Pode ser chamado múltiplas vezes (deve ser idempotente).
  Future<void> initialize();
  
  /// Desconecta/limpa recursos
  /// 
  /// Deve liberar recursos alocados pelo provider.
  Future<void> disconnect();
}

/// Tipo de pagamento
enum PaymentType {
  cash,      // Dinheiro
  pos,       // Point of Sale (SDK direto)
  tef,       // Transferência Eletrônica de Fundos
}

/// Resultado de um pagamento
class PaymentResult {
  final bool success;
  final String? transactionId;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;
  
  /// Dados padronizados da transação de pagamento
  /// Cada provider deve mapear seus dados específicos para PaymentTransactionData
  final PaymentTransactionData? transactionData;
  
  PaymentResult({
    required this.success,
    this.transactionId,
    this.errorMessage,
    this.metadata,
    this.transactionData,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

