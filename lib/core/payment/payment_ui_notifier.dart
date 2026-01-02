/// Sistema de notificação de UI para fluxo de pagamento
/// 
/// Este sistema permite que providers (como StonePOSAdapter) notifiquem
/// a UI sobre eventos que requerem interação do usuário, como:
/// - Mostrar dialog "Aguardando cartão"
/// - Esconder dialog
/// - Mostrar mensagens de progresso
/// 
/// **Por que isso é necessário?**
/// - Providers não devem conhecer detalhes de UI
/// - UI precisa reagir a eventos do SDK (ex: quando cartão é inserido)
/// - Permite desacoplamento entre lógica de negócio e apresentação
/// 
/// **Como funciona:**
/// 1. Provider chama `uiNotifier?.notify(...)` quando precisa notificar UI
/// 2. PaymentFlowProvider implementa PaymentUINotifier e recebe notificação
/// 3. PaymentFlowProvider atualiza estado e chama `notifyListeners()`
/// 4. UI (Consumer) detecta mudança e atualiza automaticamente

/// Interface para notificar UI sobre eventos de pagamento
abstract class PaymentUINotifier {
  /// Notifica UI sobre um evento
  /// 
  /// [notification] - Informação sobre o evento que ocorreu
  void notify(PaymentUINotification notification);
}

/// Tipos de notificação que podem ser enviadas para UI
enum PaymentUINotificationType {
  /// Mostrar dialog "Aguardando cartão"
  /// Usado quando SDK está aguardando cartão ser inserido/passado
  showWaitingCard,
  
  /// Esconder dialog "Aguardando cartão"
  /// Usado quando processamento do cartão terminou
  hideWaitingCard,
  
  /// Mostrar mensagem genérica
  /// Pode ser usado para mostrar progresso ou informações
  showMessage,
  
  /// Mostrar erro
  /// Usado para notificar erros que requerem atenção do usuário
  showError,
}

/// Notificação enviada para UI
class PaymentUINotification {
  /// Tipo da notificação
  final PaymentUINotificationType type;
  
  /// Mensagem opcional para exibir
  final String? message;
  
  /// Dados adicionais opcionais
  final Map<String, dynamic>? data;
  
  PaymentUINotification({
    required this.type,
    this.message,
    this.data,
  });
  
  /// Factory para criar notificação de "Mostrar dialog aguardando cartão"
  /// 
  /// Exemplo de uso:
  /// ```dart
  /// uiNotifier?.notify(PaymentUINotification.showWaitingCard(
  ///   message: 'Aguardando cartão na máquina...',
  /// ));
  /// ```
  factory PaymentUINotification.showWaitingCard({String? message}) {
    return PaymentUINotification(
      type: PaymentUINotificationType.showWaitingCard,
      message: message ?? 'Aguardando cartão...',
    );
  }
  
  /// Factory para criar notificação de "Esconder dialog aguardando cartão"
  /// 
  /// Exemplo de uso:
  /// ```dart
  /// uiNotifier?.notify(PaymentUINotification.hideWaitingCard());
  /// ```
  factory PaymentUINotification.hideWaitingCard() {
    return PaymentUINotification(
      type: PaymentUINotificationType.hideWaitingCard,
    );
  }
  
  /// Factory para criar notificação de mensagem genérica
  /// 
  /// Exemplo de uso:
  /// ```dart
  /// uiNotifier?.notify(PaymentUINotification.showMessage(
  ///   'Processando pagamento...',
  /// ));
  /// ```
  factory PaymentUINotification.showMessage(String message) {
    return PaymentUINotification(
      type: PaymentUINotificationType.showMessage,
      message: message,
    );
  }
  
  /// Factory para criar notificação de erro
  /// 
  /// Exemplo de uso:
  /// ```dart
  /// uiNotifier?.notify(PaymentUINotification.showError(
  ///   'Erro ao processar pagamento',
  /// ));
  /// ```
  factory PaymentUINotification.showError(String error) {
    return PaymentUINotification(
      type: PaymentUINotificationType.showError,
      message: error,
    );
  }
  
  @override
  String toString() {
    return 'PaymentUINotification(type: $type, message: $message)';
  }
}

