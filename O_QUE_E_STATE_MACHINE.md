# 🤖 O que é State Machine (Máquina de Estados)?

## 📚 Conceito Básico

Uma **State Machine (Máquina de Estados)** é um padrão de design que gerencia o **estado atual** de um sistema e define **quais transições** são permitidas entre estados.

### **Analogia Simples:**

Imagine um semáforo:
- **Estados possíveis:** 🔴 Vermelho, 🟡 Amarelo, 🟢 Verde
- **Transições permitidas:**
  - Vermelho → Verde ✅
  - Verde → Amarelo ✅
  - Amarelo → Vermelho ✅
  - Verde → Vermelho ❌ (não pode pular o amarelo!)

---

## 🎯 Por que usar State Machine?

### **Problema Atual (sem State Machine):**

```dart
// ❌ Estado espalhado em várias variáveis booleanas
bool _isProcessing = false;
bool _paymentSuccess = false;
bool _invoiceCreated = false;
bool _printing = false;

// ❌ Lógica de transição espalhada no código
if (_isProcessing && _paymentSuccess && !_invoiceCreated) {
  // Pode criar nota?
  // Mas e se _printing for true? E se houver erro?
  // Fica difícil garantir que o estado está correto!
}
```

**Problemas:**
- ❌ Estados inconsistentes (ex: `_isProcessing = true` e `_paymentSuccess = true` ao mesmo tempo?)
- ❌ Transições inválidas (ex: tentar imprimir antes de processar pagamento)
- ❌ Difícil debugar (qual é o estado atual?)
- ❌ Difícil testar (como garantir todas as combinações?)

---

### **Solução com State Machine:**

```dart
// ✅ Estado único e claro
enum PaymentFlowState {
  idle,              // Aguardando
  processingPayment, // Processando pagamento
  paymentProcessed,  // Pagamento OK
  paymentFailed,     // Pagamento falhou
  creatingInvoice,   // Criando nota
  printingInvoice,   // Imprimindo
  completed,         // Tudo pronto
}

// ✅ Transições controladas
class PaymentFlowStateMachine {
  PaymentFlowState _currentState = PaymentFlowState.idle;
  
  void transitionTo(PaymentFlowState newState) {
    // ✅ Valida se a transição é permitida
    if (!_isValidTransition(_currentState, newState)) {
      throw StateMachineException('Transição inválida: $_currentState → $newState');
    }
    
    _currentState = newState;
    notifyListeners();
  }
  
  bool _isValidTransition(PaymentFlowState from, PaymentFlowState to) {
    // ✅ Define regras claras de transição
    switch (from) {
      case PaymentFlowState.idle:
        return to == PaymentFlowState.processingPayment;
      
      case PaymentFlowState.processingPayment:
        return to == PaymentFlowState.paymentProcessed ||
               to == PaymentFlowState.paymentFailed;
      
      case PaymentFlowState.paymentProcessed:
        return to == PaymentFlowState.creatingInvoice ||
               to == PaymentFlowState.idle; // Pagamento parcial
      
      // ... outras regras
      
      default:
        return false;
    }
  }
}
```

**Vantagens:**
- ✅ Estado sempre consistente (só pode estar em um estado por vez)
- ✅ Transições validadas (não pode pular etapas)
- ✅ Fácil debugar (sempre sabe qual é o estado atual)
- ✅ Fácil testar (testa cada transição individualmente)

---

## 📊 Exemplo Prático: Fluxo de Pagamento

### **Diagrama de Estados:**

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUXO DE PAGAMENTO                       │
└─────────────────────────────────────────────────────────────┘

    [IDLE] ── Aguardando ação do usuário
      │
      │ [usuário clica "Pagar"]
      ↓
[PROCESSING_PAYMENT] ── Processando pagamento (SDK/API)
      │
      ├─ [sucesso] ──→ [PAYMENT_PROCESSED]
      │                     │
      │                     ├─ [saldo zerou?]
      │                     │   ├─ SIM ──→ [READY_TO_COMPLETE]
      │                     │   └─ NÃO ──→ [IDLE] (aguarda próximo pagamento)
      │                     │
      │                     └─ [usuário conclui venda]
      │                         ↓
      │                 [CONCLUDING_SALE]
      │                         │
      │                         ├─ [sucesso] ──→ [CREATING_INVOICE]
      │                         └─ [falha] ──→ [COMPLETION_FAILED]
      │
      └─ [falha] ──→ [PAYMENT_FAILED]
                          │
                          └─ [retry] ──→ [PROCESSING_PAYMENT]
```

---

## 💻 Implementação Prática

### **1. Definir Estados:**

```dart
enum PaymentFlowState {
  // Estados iniciais
  idle,                    // Aguardando ação
  
  // Estados de pagamento
  processingPayment,       // Processando pagamento
  paymentProcessed,        // Pagamento OK
  paymentFailed,           // Pagamento falhou
  
  // Estados de conclusão
  readyToComplete,         // Saldo zerou, pronto para concluir
  concludingSale,          // Concluindo venda
  saleCompleted,           // Venda concluída
  completionFailed,        // Conclusão falhou
  
  // Estados de emissão
  creatingInvoice,         // Criando nota fiscal
  sendingToSefaz,          // Enviando para SEFAZ
  invoiceAuthorized,       // Nota autorizada
  invoiceFailed,           // Nota falhou
  
  // Estados de impressão
  printingInvoice,         // Imprimindo
  printSuccess,           // Impressão OK
  printFailed,            // Impressão falhou
  
  // Estados finais
  completed,               // Tudo pronto
  cancelled,               // Cancelado
  error,                   // Erro genérico
}
```

---

### **2. Criar State Machine:**

```dart
class PaymentFlowStateMachine {
  PaymentFlowState _currentState = PaymentFlowState.idle;
  final List<PaymentFlowState> _stateHistory = [];
  
  PaymentFlowState get currentState => _currentState;
  
  /// Tenta fazer transição para novo estado
  bool transitionTo(PaymentFlowState newState) {
    if (!_isValidTransition(_currentState, newState)) {
      debugPrint('❌ Transição inválida: $_currentState → $newState');
      return false;
    }
    
    debugPrint('✅ Transição: $_currentState → $newState');
    _stateHistory.add(_currentState);
    _currentState = newState;
    return true;
  }
  
  /// Valida se transição é permitida
  bool _isValidTransition(PaymentFlowState from, PaymentFlowState to) {
    // Define regras de transição
    switch (from) {
      case PaymentFlowState.idle:
        return to == PaymentFlowState.processingPayment;
      
      case PaymentFlowState.processingPayment:
        return to == PaymentFlowState.paymentProcessed ||
               to == PaymentFlowState.paymentFailed;
      
      case PaymentFlowState.paymentProcessed:
        return to == PaymentFlowState.readyToComplete ||
               to == PaymentFlowState.idle; // Pagamento parcial
      
      case PaymentFlowState.readyToComplete:
        return to == PaymentFlowState.concludingSale;
      
      case PaymentFlowState.concludingSale:
        return to == PaymentFlowState.saleCompleted ||
               to == PaymentFlowState.completionFailed;
      
      case PaymentFlowState.saleCompleted:
        return to == PaymentFlowState.creatingInvoice ||
               to == PaymentFlowState.completed; // Sem nota fiscal
      
      case PaymentFlowState.creatingInvoice:
        return to == PaymentFlowState.sendingToSefaz;
      
      case PaymentFlowState.sendingToSefaz:
        return to == PaymentFlowState.invoiceAuthorized ||
               to == PaymentFlowState.invoiceFailed;
      
      case PaymentFlowState.invoiceAuthorized:
        return to == PaymentFlowState.printingInvoice;
      
      case PaymentFlowState.printingInvoice:
        return to == PaymentFlowState.printSuccess ||
               to == PaymentFlowState.printFailed;
      
      case PaymentFlowState.printSuccess:
        return to == PaymentFlowState.completed;
      
      // Estados de erro podem voltar para estados anteriores (retry)
      case PaymentFlowState.paymentFailed:
        return to == PaymentFlowState.processingPayment || // Retry
               to == PaymentFlowState.idle; // Cancelar
      
      case PaymentFlowState.completionFailed:
        return to == PaymentFlowState.concludingSale || // Retry
               to == PaymentFlowState.idle; // Cancelar
      
      case PaymentFlowState.invoiceFailed:
        return to == PaymentFlowState.creatingInvoice || // Retry
               to == PaymentFlowState.completed; // Pular impressão
      
      case PaymentFlowState.printFailed:
        return to == PaymentFlowState.printingInvoice || // Retry
               to == PaymentFlowState.completed; // Pular impressão
      
      default:
        return false;
    }
  }
  
  /// Verifica se pode executar ação
  bool canProcessPayment() {
    return _currentState == PaymentFlowState.idle;
  }
  
  bool canConcludeSale() {
    return _currentState == PaymentFlowState.readyToComplete;
  }
  
  bool canRetry() {
    return _currentState == PaymentFlowState.paymentFailed ||
           _currentState == PaymentFlowState.completionFailed ||
           _currentState == PaymentFlowState.invoiceFailed ||
           _currentState == PaymentFlowState.printFailed;
  }
  
  /// Reseta para estado inicial
  void reset() {
    _currentState = PaymentFlowState.idle;
    _stateHistory.clear();
  }
}
```

---

### **3. Usar no Provider:**

```dart
class PaymentFlowProvider extends ChangeNotifier {
  final PaymentFlowStateMachine _stateMachine = PaymentFlowStateMachine();
  final PaymentService _paymentService;
  
  PaymentFlowState get currentState => _stateMachine.currentState;
  
  bool get canProcessPayment => _stateMachine.canProcessPayment();
  bool get canConcludeSale => _stateMachine.canConcludeSale();
  bool get canRetry => _stateMachine.canRetry();
  
  bool get isProcessing => _isProcessingState(currentState);
  
  bool _isProcessingState(PaymentFlowState state) {
    return state == PaymentFlowState.processingPayment ||
           state == PaymentFlowState.concludingSale ||
           state == PaymentFlowState.creatingInvoice ||
           state == PaymentFlowState.sendingToSefaz ||
           state == PaymentFlowState.printingInvoice;
  }
  
  /// Processa pagamento
  Future<bool> processPayment({
    required String providerKey,
    required double amount,
    required String vendaId,
  }) async {
    // ✅ Valida se pode processar
    if (!canProcessPayment) {
      debugPrint('❌ Não pode processar pagamento no estado: $currentState');
      return false;
    }
    
    // ✅ Transiciona para processando
    _stateMachine.transitionTo(PaymentFlowState.processingPayment);
    notifyListeners();
    
    try {
      // Processa pagamento
      final result = await _paymentService.processPayment(...);
      
      if (result.success) {
        // ✅ Transiciona para sucesso
        _stateMachine.transitionTo(PaymentFlowState.paymentProcessed);
        
        // Verifica se saldo zerou
        if (saldoZerou) {
          _stateMachine.transitionTo(PaymentFlowState.readyToComplete);
        } else {
          _stateMachine.transitionTo(PaymentFlowState.idle); // Aguarda próximo pagamento
        }
      } else {
        // ✅ Transiciona para falha
        _stateMachine.transitionTo(PaymentFlowState.paymentFailed);
      }
      
      notifyListeners();
      return result.success;
      
    } catch (e) {
      // ✅ Transiciona para erro
      _stateMachine.transitionTo(PaymentFlowState.paymentFailed);
      notifyListeners();
      return false;
    }
  }
  
  /// Conclui venda
  Future<bool> concludeSale({required String vendaId}) async {
    // ✅ Valida se pode concluir
    if (!canConcludeSale) {
      debugPrint('❌ Não pode concluir venda no estado: $currentState');
      return false;
    }
    
    // ✅ Transiciona para concluindo
    _stateMachine.transitionTo(PaymentFlowState.concludingSale);
    notifyListeners();
    
    try {
      // Conclui venda
      final result = await _vendaService.concluirVenda(vendaId);
      
      if (result.success) {
        _stateMachine.transitionTo(PaymentFlowState.saleCompleted);
        
        // Se tem nota fiscal, transiciona para criar
        if (temNotaFiscal) {
          _stateMachine.transitionTo(PaymentFlowState.creatingInvoice);
          // ... continua fluxo
        } else {
          _stateMachine.transitionTo(PaymentFlowState.completed);
        }
      } else {
        _stateMachine.transitionTo(PaymentFlowState.completionFailed);
      }
      
      notifyListeners();
      return result.success;
      
    } catch (e) {
      _stateMachine.transitionTo(PaymentFlowState.completionFailed);
      notifyListeners();
      return false;
    }
  }
}
```

---

### **4. Usar na UI:**

```dart
Consumer<PaymentFlowProvider>(
  builder: (context, provider, child) {
    final state = provider.currentState;
    
    // ✅ UI reage ao estado automaticamente
    switch (state) {
      case PaymentFlowState.idle:
        return PaymentForm(
          onPay: () => provider.processPayment(...),
          enabled: provider.canProcessPayment,
        );
      
      case PaymentFlowState.processingPayment:
        return LoadingWidget(message: 'Processando pagamento...');
      
      case PaymentFlowState.paymentProcessed:
        return SuccessWidget(
          message: 'Pagamento realizado!',
          onContinue: () {
            if (provider.canConcludeSale) {
              // Mostra botão "Concluir venda"
            } else {
              // Volta para formulário (pagamento parcial)
            }
          },
        );
      
      case PaymentFlowState.readyToComplete:
        return ConcludeSaleButton(
          onTap: () => provider.concludeSale(...),
          enabled: provider.canConcludeSale,
        );
      
      case PaymentFlowState.paymentFailed:
        return ErrorWidget(
          message: 'Pagamento falhou',
          onRetry: provider.canRetry ? () => provider.retry() : null,
        );
      
      // ... outros estados
      
      default:
        return SizedBox();
    }
  },
)
```

---

## 🆚 Comparação: Com vs Sem State Machine

### **Sem State Machine (Atual):**

```dart
// ❌ Estado espalhado
bool _isProcessing = false;
bool _paymentSuccess = false;
bool _invoiceCreated = false;

// ❌ Lógica complexa e propensa a erros
Future<void> _processarPagamento() async {
  if (_isProcessing) return; // Mas e se já processou?
  
  _isProcessing = true;
  
  try {
    final result = await _paymentService.processPayment(...);
    
    if (result.success) {
      _paymentSuccess = true; // Mas e se já tinha processado antes?
      _isProcessing = false; // Mas e se ainda está criando nota?
      
      if (saldoZerou) {
        // Pode concluir? Mas e se já concluiu?
        await _concluirVenda();
      }
    }
  } catch (e) {
    _isProcessing = false; // Mas e se estava em outro estado?
    _paymentSuccess = false; // Mas e se já tinha sucesso antes?
  }
}
```

**Problemas:**
- ❌ Estados podem ficar inconsistentes
- ❌ Difícil saber qual é o estado atual
- ❌ Pode tentar ações inválidas (ex: concluir antes de pagar)
- ❌ Difícil debugar quando algo dá errado

---

### **Com State Machine:**

```dart
// ✅ Estado único e claro
PaymentFlowState _currentState = PaymentFlowState.idle;

// ✅ Lógica simples e segura
Future<void> processPayment() async {
  // ✅ Valida se pode processar
  if (!_stateMachine.canProcessPayment()) {
    return; // Estado inválido, não faz nada
  }
  
  // ✅ Transiciona para processando
  _stateMachine.transitionTo(PaymentFlowState.processingPayment);
  notifyListeners(); // UI atualiza automaticamente
  
  try {
    final result = await _paymentService.processPayment(...);
    
    if (result.success) {
      // ✅ Transiciona para sucesso
      _stateMachine.transitionTo(PaymentFlowState.paymentProcessed);
      
      if (saldoZerou) {
        _stateMachine.transitionTo(PaymentFlowState.readyToComplete);
      } else {
        _stateMachine.transitionTo(PaymentFlowState.idle);
      }
    } else {
      // ✅ Transiciona para falha
      _stateMachine.transitionTo(PaymentFlowState.paymentFailed);
    }
    
    notifyListeners(); // UI atualiza automaticamente
    
  } catch (e) {
    // ✅ Transiciona para erro
    _stateMachine.transitionTo(PaymentFlowState.paymentFailed);
    notifyListeners();
  }
}
```

**Vantagens:**
- ✅ Estado sempre consistente
- ✅ Sempre sabe qual é o estado atual
- ✅ Não pode fazer ações inválidas (validação automática)
- ✅ Fácil debugar (log de transições)
- ✅ UI reage automaticamente ao estado

---

## 🎯 Quando Usar State Machine?

### **✅ Use quando:**

1. **Fluxo complexo com múltiplos estados:**
   - Pagamento → Conclusão → Emissão → Impressão
   - Cada etapa tem estados de sucesso/falha

2. **Precisa garantir transições válidas:**
   - Não pode concluir antes de pagar
   - Não pode imprimir antes de autorizar

3. **Precisa rastrear histórico:**
   - Saber qual foi o último estado
   - Poder fazer "undo" ou "retry"

4. **UI precisa reagir a mudanças de estado:**
   - Mostrar/esconder botões baseado no estado
   - Mostrar mensagens diferentes para cada estado

---

### **❌ Não precisa quando:**

1. **Fluxo simples (1-2 estados):**
   - Ex: Loading → Success
   - Boolean simples já resolve

2. **Estados independentes:**
   - Ex: Modo escuro/claro (não tem transições)

3. **Lógica muito simples:**
   - Ex: Contador (incrementa/decrementa)

---

## 📝 Resumo

**State Machine é útil quando:**
- ✅ Você tem um fluxo complexo com múltiplas etapas
- ✅ Precisa garantir que transições sejam válidas
- ✅ UI precisa reagir a diferentes estados
- ✅ Quer código mais seguro e fácil de debugar

**No nosso caso (fluxo de pagamento):**
- ✅ Temos múltiplas etapas: Pagamento → Conclusão → Emissão → Impressão
- ✅ Cada etapa pode ter sucesso ou falha
- ✅ UI precisa mostrar diferentes telas/mensagens para cada estado
- ✅ Precisamos garantir que não pule etapas (ex: imprimir antes de pagar)

**Conclusão:** State Machine seria muito útil para o nosso fluxo de pagamento! 🎯

