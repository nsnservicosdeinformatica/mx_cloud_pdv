# 🏗️ Arquitetura Detalhada: Fluxo de Pagamento

## 📋 Visão Geral

Este documento explica como organizar o fluxo de pagamento considerando:
- ✅ Diferentes tipos de pagamento (Cash, Stone POS SDK, PIX)
- ✅ Comunicação com SDKs externos
- ✅ Notificação da UI para exibir dialogs
- ✅ Separação de responsabilidades

---

## 📐 Estrutura de Arquivos Proposta

```
lib/
├── core/
│   └── payment/
│       ├── payment_service.dart              # Serviço principal (orquestrador)
│       ├── payment_provider.dart             # Interface base
│       ├── payment_method_option.dart         # Modelo de método de pagamento
│       ├── payment_transaction_data.dart     # Dados padronizados
│       └── payment_ui_notifier.dart          # 🆕 Notifica UI sobre dialogs
│
├── data/
│   └── adapters/
│       └── payment/
│           ├── payment_provider_registry.dart # Registro de providers
│           └── providers/
│               ├── cash_payment_adapter.dart  # Provider de dinheiro
│               ├── stone_pos_adapter.dart     # Provider Stone POS SDK
│               └── pix_deeplink_adapter.dart  # Provider PIX (se houver)
│
├── presentation/
│   ├── providers/
│   │   └── payment_flow_provider.dart        # 🆕 Provider para UI
│   └── screens/
│       └── pagamento/
│           └── pagamento_restaurante_screen.dart # UI (simplificada)
```

---

## 🎯 Responsabilidades de Cada Camada

### **1. UI (Tela de Pagamento)**
**Responsabilidade:** Apenas renderizar e reagir a mudanças

```dart
// pagamento_restaurante_screen.dart
class PagamentoRestauranteScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<PaymentFlowProvider>(
      builder: (context, provider, child) {
        // UI reage automaticamente aos estados
        if (provider.showWaitingCardDialog) {
          return _buildWaitingCardDialog(context, provider);
        }
        
        if (provider.isProcessing) {
          return CircularProgressIndicator();
        }
        
        return PaymentForm(
          onPaymentRequested: (request) {
            provider.processPayment(request);
          },
        );
      },
    );
  }
}
```

**O que faz:**
- ✅ Renderiza UI baseada no estado do Provider
- ✅ Chama Provider quando usuário interage
- ✅ Reage automaticamente a mudanças (via Consumer)
- ❌ **NÃO** conhece detalhes de SDK
- ❌ **NÃO** gerencia estado complexo

---

### **2. PaymentFlowProvider (Provider para UI)**
**Responsabilidade:** Gerencia estado para UI reagir

```dart
// payment_flow_provider.dart
class PaymentFlowProvider extends ChangeNotifier {
  final PaymentService _paymentService;
  
  // Estados para UI reagir
  bool _isProcessing = false;
  bool _showWaitingCardDialog = false;
  String? _errorMessage;
  PaymentResult? _lastResult;
  
  // Getters para UI
  bool get isProcessing => _isProcessing;
  bool get showWaitingCardDialog => _showWaitingCardDialog;
  String? get errorMessage => _errorMessage;
  PaymentResult? get lastResult => _lastResult;
  
  Future<bool> processPayment(PaymentRequest request) async {
    _isProcessing = true;
    _showWaitingCardDialog = false;
    _errorMessage = null;
    notifyListeners(); // UI atualiza (mostra loading)
    
    try {
      // Chama Service (que vai notificar sobre dialogs)
      final result = await _paymentService.processPayment(
        providerKey: request.providerKey,
        amount: request.amount,
        vendaId: request.vendaId,
        additionalData: request.additionalData,
        uiNotifier: _uiNotifier, // ← Passa notificador para UI
      );
      
      _lastResult = result;
      _isProcessing = false;
      _showWaitingCardDialog = false;
      notifyListeners(); // UI atualiza (esconde loading)
      
      return result.success;
      
    } catch (e) {
      _errorMessage = e.toString();
      _isProcessing = false;
      _showWaitingCardDialog = false;
      notifyListeners();
      return false;
    }
  }
  
  // Callback que será chamado pelo Service quando precisar mostrar dialog
  void _uiNotifier(PaymentUINotification notification) {
    switch (notification.type) {
      case PaymentUINotificationType.showWaitingCard:
        _showWaitingCardDialog = true;
        notifyListeners(); // UI mostra dialog
        break;
        
      case PaymentUINotificationType.hideWaitingCard:
        _showWaitingCardDialog = false;
        notifyListeners(); // UI esconde dialog
        break;
        
      case PaymentUINotificationType.showMessage:
        // Pode mostrar toast, snackbar, etc.
        break;
    }
  }
}
```

**O que faz:**
- ✅ Gerencia estado para UI
- ✅ Notifica UI via `notifyListeners()`
- ✅ Recebe notificações do Service sobre dialogs
- ❌ **NÃO** conhece detalhes de SDK
- ❌ **NÃO** executa lógica de pagamento

---

### **3. PaymentService (Orquestrador)**
**Responsabilidade:** Orquestra o fluxo e notifica UI

```dart
// payment_service.dart
class PaymentService {
  final PaymentProviderRegistry _registry;
  
  Future<PaymentResult> processPayment({
    required String providerKey,
    required double amount,
    required String vendaId,
    Map<String, dynamic>? additionalData,
    PaymentUINotifier? uiNotifier, // ← Notificador para UI
  }) async {
    // 1. Obtém provider
    final provider = await _registry.getProvider(providerKey);
    
    if (provider == null) {
      return PaymentResult(
        success: false,
        errorMessage: 'Provider $providerKey não disponível',
      );
    }
    
    // 2. Inicializa provider
    try {
      await provider.initialize();
    } catch (e) {
      return PaymentResult(
        success: false,
        errorMessage: 'Erro ao inicializar provider: ${e.toString()}',
      );
    }
    
    // 3. Notifica UI se necessário (ex: mostrar dialog de aguardando cartão)
    if (provider.requiresUserInteraction) {
      uiNotifier?.notify(PaymentUINotification.showWaitingCard());
    }
    
    try {
      // 4. Processa pagamento (provider pode notificar UI durante o processo)
      final result = await provider.processPayment(
        amount: amount,
        vendaId: vendaId,
        additionalData: additionalData,
        uiNotifier: uiNotifier, // ← Passa notificador para provider
      );
      
      // 5. Esconde dialog se estava mostrando
      if (provider.requiresUserInteraction) {
        uiNotifier?.notify(PaymentUINotification.hideWaitingCard());
      }
      
      return result;
      
    } catch (e) {
      // Esconde dialog em caso de erro
      if (provider.requiresUserInteraction) {
        uiNotifier?.notify(PaymentUINotification.hideWaitingCard());
      }
      
      return PaymentResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
}
```

**O que faz:**
- ✅ Orquestra o fluxo de pagamento
- ✅ Gerencia providers
- ✅ Notifica UI sobre dialogs necessários
- ❌ **NÃO** conhece detalhes de cada SDK
- ❌ **NÃO** executa lógica específica de cada provider

---

### **4. PaymentProvider (Interface Base)**
**Responsabilidade:** Define contrato para todos os providers

```dart
// payment_provider.dart
abstract class PaymentProvider {
  String get providerName;
  PaymentType get paymentType;
  bool get isAvailable;
  
  /// Se o provider requer interação do usuário (ex: inserir cartão)
  bool get requiresUserInteraction;
  
  /// Inicializa o provider
  Future<void> initialize();
  
  /// Processa um pagamento
  /// uiNotifier pode ser usado para notificar UI durante o processo
  Future<PaymentResult> processPayment({
    required double amount,
    required String vendaId,
    Map<String, dynamic>? additionalData,
    PaymentUINotifier? uiNotifier, // ← Notificador opcional
  });
  
  /// Desconecta/limpa recursos
  Future<void> disconnect();
}
```

**O que faz:**
- ✅ Define contrato comum para todos os providers
- ✅ Permite notificação de UI durante processamento
- ❌ **NÃO** implementa lógica específica

---

### **5. StonePOSAdapter (Provider Stone SDK)**
**Responsabilidade:** Comunicação direta com SDK Stone

```dart
// stone_pos_adapter.dart
class StonePOSAdapter implements PaymentProvider {
  final StonePayments _stonePayments;
  bool _initialized = false;
  bool _activated = false;
  
  @override
  bool get requiresUserInteraction => true; // ← Requer interação (inserir cartão)
  
  @override
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Ativa Stone
      await _stonePayments.activateStone(stoneCode: _stoneCode);
      _activated = true;
      _initialized = true;
      
      debugPrint('✅ Stone POS SDK inicializado');
    } catch (e) {
      debugPrint('❌ Erro ao inicializar Stone: $e');
      rethrow;
    }
  }
  
  @override
  Future<PaymentResult> processPayment({
    required double amount,
    required String vendaId,
    Map<String, dynamic>? additionalData,
    PaymentUINotifier? uiNotifier, // ← Notificador para UI
  }) async {
    if (!_initialized) {
      await initialize();
    }
    
    try {
      // 1. Determina tipo de transação
      final tipoTransacao = additionalData?['tipoTransacao'] as String? ?? 'credit';
      final transactionType = _mapTransactionType(tipoTransacao);
      
      // 2. Notifica UI que está aguardando cartão
      uiNotifier?.notify(PaymentUINotification.showWaitingCard(
        message: 'Aguardando cartão...',
      ));
      
      // 3. Chama SDK Stone (bloqueia até cartão ser processado)
      debugPrint('💳 Iniciando transação Stone: R\$ ${amount.toStringAsFixed(2)}');
      
      final transaction = await _stonePayments.transaction(
        amount: amount,
        typeTransaction: transactionType,
        installments: additionalData?['parcelas'] as int? ?? 1,
      );
      
      // 4. Verifica resultado
      if (transaction.status == TransactionStatus.APPROVED ||
          transaction.status == TransactionStatus.AUTHORIZED) {
        
        // 5. Esconde dialog
        uiNotifier?.notify(PaymentUINotification.hideWaitingCard());
        
        // 6. Mapeia resultado para formato padronizado
        final transactionData = StoneTransactionMapper.toPaymentTransactionData(transaction);
        
        return PaymentResult(
          success: true,
          transactionId: transaction.initiatorTransactionKey,
          transactionData: transactionData,
          metadata: {
            'authorizationCode': transaction.authorizationCode,
            'acquirer': transaction.acquirer,
            'cardBrand': transaction.cardBrand,
          },
        );
      } else {
        // Transação negada
        uiNotifier?.notify(PaymentUINotification.hideWaitingCard());
        
        return PaymentResult(
          success: false,
          errorMessage: transaction.message ?? 'Transação negada',
          metadata: {
            'status': transaction.status.toString(),
          },
        );
      }
      
    } catch (e, stackTrace) {
      // Erro durante processamento
      uiNotifier?.notify(PaymentUINotification.hideWaitingCard());
      
      debugPrint('❌ Erro ao processar pagamento Stone: $e');
      return PaymentResult(
        success: false,
        errorMessage: 'Erro ao processar pagamento: ${e.toString()}',
      );
    }
  }
  
  TypeTransactionEnum _mapTransactionType(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'debit':
      case 'debito':
        return TypeTransactionEnum.debit;
      case 'pix':
        return TypeTransactionEnum.pix;
      default:
        return TypeTransactionEnum.credit;
    }
  }
}
```

**O que faz:**
- ✅ Comunica diretamente com SDK Stone
- ✅ Notifica UI quando precisa mostrar/esconder dialogs
- ✅ Mapeia resultado do SDK para formato padronizado
- ❌ **NÃO** conhece detalhes de UI
- ❌ **NÃO** gerencia estado da UI

---

### **6. CashPaymentAdapter (Provider Dinheiro)**
**Responsabilidade:** Processa pagamento em dinheiro

```dart
// cash_payment_adapter.dart
class CashPaymentAdapter implements PaymentProvider {
  @override
  bool get requiresUserInteraction => false; // ← Não requer interação
  
  @override
  Future<PaymentResult> processPayment({
    required double amount,
    required String vendaId,
    Map<String, dynamic>? additionalData,
    PaymentUINotifier? uiNotifier, // ← Não usado para cash
  }) async {
    // 1. Valida valor recebido
    final valorRecebido = additionalData?['valorRecebido'] as double?;
    
    if (valorRecebido == null || valorRecebido < amount) {
      return PaymentResult(
        success: false,
        errorMessage: 'Valor recebido insuficiente',
      );
    }
    
    // 2. Calcula troco
    final troco = valorRecebido - amount;
    
    // 3. Retorna sucesso
    return PaymentResult(
      success: true,
      transactionId: 'CASH_${DateTime.now().millisecondsSinceEpoch}',
      metadata: {
        'valorRecebido': valorRecebido,
        'troco': troco,
      },
    );
  }
  
  @override
  Future<void> initialize() async {
    // Cash não precisa inicialização
  }
  
  @override
  Future<void> disconnect() async {
    // Cash não precisa desconexão
  }
}
```

**O que faz:**
- ✅ Processa pagamento em dinheiro
- ✅ Valida valor recebido
- ✅ Calcula troco
- ❌ **NÃO** requer interação do usuário
- ❌ **NÃO** usa SDK externo

---

## 🔔 Sistema de Notificação de UI

### **PaymentUINotifier (Interface)**

```dart
// payment_ui_notifier.dart
abstract class PaymentUINotifier {
  void notify(PaymentUINotification notification);
}

class PaymentUINotification {
  final PaymentUINotificationType type;
  final String? message;
  final Map<String, dynamic>? data;
  
  PaymentUINotification({
    required this.type,
    this.message,
    this.data,
  });
  
  factory PaymentUINotification.showWaitingCard({String? message}) {
    return PaymentUINotification(
      type: PaymentUINotificationType.showWaitingCard,
      message: message ?? 'Aguardando cartão...',
    );
  }
  
  factory PaymentUINotification.hideWaitingCard() {
    return PaymentUINotification(
      type: PaymentUINotificationType.hideWaitingCard,
    );
  }
  
  factory PaymentUINotification.showMessage(String message) {
    return PaymentUINotification(
      type: PaymentUINotificationType.showMessage,
      message: message,
    );
  }
}

enum PaymentUINotificationType {
  showWaitingCard,
  hideWaitingCard,
  showMessage,
  showError,
}
```

**Como funciona:**
- Provider chama `uiNotifier?.notify(...)` quando precisa notificar UI
- Provider não conhece detalhes de UI
- UI reage via Provider que escuta notificações

---

## 🔄 Fluxo Completo: Pagamento com Stone POS SDK

```
┌─────────────────────────────────────────────────────────────┐
│ 1. USUÁRIO CLICA "PROCESSAR PAGAMENTO"                      │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. UI (pagamento_restaurante_screen.dart)                   │
│    - Prepara PaymentRequest                                 │
│    - Chama provider.processPayment(request)                 │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. PaymentFlowProvider                                      │
│    - _isProcessing = true                                   │
│    - notifyListeners() → UI mostra loading                  │
│    - Chama _paymentService.processPayment(...)              │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. PaymentService                                           │
│    - Obtém StonePOSAdapter do registry                      │
│    - Verifica requiresUserInteraction = true                │
│    - uiNotifier.notify(showWaitingCard())                   │
│    - Chama adapter.processPayment(...)                       │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. PaymentFlowProvider (recebe notificação)                 │
│    - _showWaitingCardDialog = true                          │
│    - notifyListeners() → UI mostra dialog                    │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. UI (Consumer detecta mudança)                            │
│    - Reconstrói widget                                      │
│    - Mostra dialog "Aguardando cartão..."                    │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. StonePOSAdapter                                          │
│    - Chama _stonePayments.transaction(...)                  │
│    - SDK Stone:                                              │
│      * Mostra valor no display da máquina                   │
│      * Aguarda cartão ser inserido/passado                  │
│      * Processa transação                                   │
│      * Retorna Transaction                                  │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 8. StonePOSAdapter (continuação)                            │
│    - Verifica status (APPROVED/AUTHORIZED)                  │
│    - uiNotifier.notify(hideWaitingCard())                   │
│    - Retorna PaymentResult.success                          │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 9. PaymentFlowProvider (recebe notificação)                 │
│    - _showWaitingCardDialog = false                         │
│    - notifyListeners() → UI esconde dialog                    │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 10. PaymentService                                          │
│     - Recebe PaymentResult.success                          │
│     - Retorna para Provider                                 │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 11. PaymentFlowProvider (continuação)                      │
│     - _isProcessing = false                                 │
│     - _lastResult = result                                  │
│     - notifyListeners() → UI atualiza                       │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 12. UI (Consumer detecta mudança)                           │
│     - Reconstrói widget                                     │
│     - Esconde loading                                       │
│     - Mostra sucesso                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 📝 Exemplo de Código Completo

### **1. PaymentUINotifier (Interface)**

```dart
// payment_ui_notifier.dart
abstract class PaymentUINotifier {
  void notify(PaymentUINotification notification);
}

class PaymentUINotification {
  final PaymentUINotificationType type;
  final String? message;
  
  PaymentUINotification({
    required this.type,
    this.message,
  });
  
  factory PaymentUINotification.showWaitingCard({String? message}) {
    return PaymentUINotification(
      type: PaymentUINotificationType.showWaitingCard,
      message: message ?? 'Aguardando cartão...',
    );
  }
  
  factory PaymentUINotification.hideWaitingCard() {
    return PaymentUINotification(
      type: PaymentUINotificationType.hideWaitingCard,
    );
  }
}

enum PaymentUINotificationType {
  showWaitingCard,
  hideWaitingCard,
  showMessage,
}
```

### **2. PaymentFlowProvider**

```dart
// payment_flow_provider.dart
class PaymentFlowProvider extends ChangeNotifier implements PaymentUINotifier {
  final PaymentService _paymentService;
  
  bool _isProcessing = false;
  bool _showWaitingCardDialog = false;
  String? _waitingCardMessage = 'Aguardando cartão...';
  String? _errorMessage;
  PaymentResult? _lastResult;
  
  bool get isProcessing => _isProcessing;
  bool get showWaitingCardDialog => _showWaitingCardDialog;
  String? get waitingCardMessage => _waitingCardMessage;
  String? get errorMessage => _errorMessage;
  PaymentResult? get lastResult => _lastResult;
  
  Future<bool> processPayment(PaymentRequest request) async {
    _isProcessing = true;
    _showWaitingCardDialog = false;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final result = await _paymentService.processPayment(
        providerKey: request.providerKey,
        amount: request.amount,
        vendaId: request.vendaId,
        additionalData: request.additionalData,
        uiNotifier: this, // ← Passa this como notificador
      );
      
      _lastResult = result;
      _isProcessing = false;
      notifyListeners();
      
      return result.success;
      
    } catch (e) {
      _errorMessage = e.toString();
      _isProcessing = false;
      _showWaitingCardDialog = false;
      notifyListeners();
      return false;
    }
  }
  
  // Implementa PaymentUINotifier
  @override
  void notify(PaymentUINotification notification) {
    switch (notification.type) {
      case PaymentUINotificationType.showWaitingCard:
        _showWaitingCardDialog = true;
        _waitingCardMessage = notification.message ?? 'Aguardando cartão...';
        notifyListeners(); // UI atualiza
        break;
        
      case PaymentUINotificationType.hideWaitingCard:
        _showWaitingCardDialog = false;
        notifyListeners(); // UI atualiza
        break;
        
      case PaymentUINotificationType.showMessage:
        // Pode mostrar toast, snackbar, etc.
        break;
    }
  }
}
```

### **3. PaymentService**

```dart
// payment_service.dart
class PaymentService {
  Future<PaymentResult> processPayment({
    required String providerKey,
    required double amount,
    required String vendaId,
    Map<String, dynamic>? additionalData,
    PaymentUINotifier? uiNotifier,
  }) async {
    final provider = await _registry.getProvider(providerKey);
    
    if (provider == null) {
      return PaymentResult(success: false, errorMessage: 'Provider não disponível');
    }
    
    await provider.initialize();
    
    // Notifica UI se provider requer interação
    if (provider.requiresUserInteraction) {
      uiNotifier?.notify(PaymentUINotification.showWaitingCard());
    }
    
    try {
      final result = await provider.processPayment(
        amount: amount,
        vendaId: vendaId,
        additionalData: additionalData,
        uiNotifier: uiNotifier, // ← Passa para provider
      );
      
      if (provider.requiresUserInteraction) {
        uiNotifier?.notify(PaymentUINotification.hideWaitingCard());
      }
      
      return result;
      
    } catch (e) {
      if (provider.requiresUserInteraction) {
        uiNotifier?.notify(PaymentUINotification.hideWaitingCard());
      }
      rethrow;
    }
  }
}
```

### **4. StonePOSAdapter**

```dart
// stone_pos_adapter.dart
class StonePOSAdapter implements PaymentProvider {
  @override
  bool get requiresUserInteraction => true;
  
  @override
  Future<PaymentResult> processPayment({
    required double amount,
    required String vendaId,
    Map<String, dynamic>? additionalData,
    PaymentUINotifier? uiNotifier,
  }) async {
    // Notifica UI
    uiNotifier?.notify(PaymentUINotification.showWaitingCard(
      message: 'Aguardando cartão na máquina...',
    ));
    
    try {
      // Chama SDK (bloqueia até cartão ser processado)
      final transaction = await _stonePayments.transaction(
        amount: amount,
        typeTransaction: _mapTransactionType(additionalData?['tipoTransacao']),
      );
      
      // Esconde dialog
      uiNotifier?.notify(PaymentUINotification.hideWaitingCard());
      
      if (transaction.status == TransactionStatus.APPROVED) {
        return PaymentResult(
          success: true,
          transactionId: transaction.initiatorTransactionKey,
          transactionData: StoneTransactionMapper.toPaymentTransactionData(transaction),
        );
      } else {
        return PaymentResult(
          success: false,
          errorMessage: transaction.message ?? 'Transação negada',
        );
      }
      
    } catch (e) {
      uiNotifier?.notify(PaymentUINotification.hideWaitingCard());
      rethrow;
    }
  }
}
```

### **5. UI (Tela de Pagamento)**

```dart
// pagamento_restaurante_screen.dart
class PagamentoRestauranteScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<PaymentFlowProvider>(
      builder: (context, provider, child) {
        // Mostra dialog de aguardando cartão se necessário
        if (provider.showWaitingCardDialog) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showWaitingCardDialog(context, provider.waitingCardMessage);
          });
        }
        
        if (provider.isProcessing) {
          return CircularProgressIndicator();
        }
        
        return ElevatedButton(
          onPressed: () async {
            final request = PaymentRequest(...);
            await provider.processPayment(request);
          },
          child: Text('Processar Pagamento'),
        );
      },
    );
  }
  
  void _showWaitingCardDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Aguardando Cartão'),
        content: Text(message),
        // Dialog será fechado quando provider.showWaitingCardDialog = false
      ),
    );
  }
}
```

---

## ✅ Vantagens desta Arquitetura

### **1. Separação de Responsabilidades**
- **UI**: Apenas renderiza
- **Provider**: Gerencia estado
- **Service**: Orquestra fluxo
- **Adapter**: Comunica com SDK

### **2. Desacoplamento**
- Provider não conhece detalhes de SDK
- Adapter não conhece detalhes de UI
- Comunicação via notificações

### **3. Testabilidade**
- Cada camada pode ser testada isoladamente
- Fácil mockar notificações
- Fácil mockar SDK

### **4. Extensibilidade**
- Fácil adicionar novos providers
- Fácil adicionar novos tipos de notificação
- Fácil mudar implementação de UI

### **5. Manutenibilidade**
- Código organizado e fácil de entender
- Responsabilidades claras
- Fácil encontrar onde está cada lógica

---

## 🎯 Resumo

**Quem é responsável por quê:**

| Componente | Responsabilidade |
|------------|------------------|
| **UI** | Renderizar e reagir a mudanças |
| **PaymentFlowProvider** | Gerencia estado para UI |
| **PaymentService** | Orquestra fluxo e notifica UI |
| **PaymentProvider (interface)** | Define contrato comum |
| **StonePOSAdapter** | Comunica com SDK Stone |
| **PaymentUINotifier** | Notifica UI sobre dialogs |

**Como UI é notificada:**

1. Adapter chama `uiNotifier?.notify(...)`
2. Provider recebe notificação e atualiza estado
3. Provider chama `notifyListeners()`
4. UI (Consumer) detecta mudança e reconstrói
5. UI mostra/esconde dialog automaticamente

**Tudo desacoplado e reativo!** 🎉

