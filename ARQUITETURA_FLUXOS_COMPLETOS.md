# 🏗️ Arquitetura Completa: Pagamento, Conclusão e Emissão de Nota

## 📋 Visão Geral

Este documento explica como organizar os **3 fluxos principais**:
1. **Pagamento** - Processa pagamento (Cash, Stone POS, etc.)
2. **Conclusão de Venda** - Finaliza venda e prepara nota fiscal
3. **Emissão de Nota Fiscal** - Emite NFC-e na SEFAZ e imprime

---

## 🎯 Decisão Arquitetural: Separados ou Juntos?

### **Opção 1: Fluxos Separados (Recomendado) ✅**

Cada fluxo tem sua própria estrutura, mas compartilham componentes comuns.

**Vantagens:**
- ✅ Separação clara de responsabilidades
- ✅ Fácil testar cada fluxo isoladamente
- ✅ Fácil manter e evoluir
- ✅ Reutilização de componentes comuns

**Estrutura:**
```
lib/
├── core/
│   ├── payment/              # Fluxo de pagamento
│   ├── sale_completion/      # Fluxo de conclusão de venda
│   ├── invoice_emission/     # Fluxo de emissão de nota
│   └── sale_flow/            # 🆕 Orquestrador geral (coordena os 3)
```

### **Opção 2: Fluxo Único (Não Recomendado) ❌**

Tudo em um único fluxo gigante.

**Desvantagens:**
- ❌ Código muito grande e difícil de manter
- ❌ Difícil testar partes isoladas
- ❌ Violação de responsabilidade única

---

## 📐 Estrutura de Arquivos Proposta (Opção 1)

```
lib/
├── core/
│   ├── payment/                          # 🔵 FLUXO 1: PAGAMENTO
│   │   ├── payment_service.dart
│   │   ├── payment_provider.dart
│   │   ├── payment_ui_notifier.dart
│   │   └── models/
│   │       ├── payment_request.dart
│   │       └── payment_result.dart
│   │
│   ├── sale_completion/                  # 🟢 FLUXO 2: CONCLUSÃO DE VENDA
│   │   ├── sale_completion_service.dart
│   │   ├── sale_completion_provider.dart
│   │   ├── sale_completion_ui_notifier.dart
│   │   └── models/
│   │       ├── sale_completion_request.dart
│   │       └── sale_completion_result.dart
│   │
│   ├── invoice_emission/                 # 🟡 FLUXO 3: EMISSÃO DE NOTA
│   │   ├── invoice_emission_service.dart
│   │   ├── invoice_emission_provider.dart
│   │   ├── invoice_emission_ui_notifier.dart
│   │   └── models/
│   │       ├── invoice_emission_request.dart
│   │       └── invoice_emission_result.dart
│   │
│   └── sale_flow/                        # 🟣 ORQUESTRADOR GERAL
│       ├── sale_flow_service.dart        # Coordena os 3 fluxos
│       ├── sale_flow_provider.dart       # Provider unificado para UI
│       ├── sale_flow_state_machine.dart  # Máquina de estados
│       └── models/
│           ├── sale_flow_state.dart
│           └── sale_flow_result.dart
│
├── data/
│   └── adapters/
│       ├── payment/                      # Adapters de pagamento
│       │   └── providers/
│       │       ├── cash_payment_adapter.dart
│       │       └── stone_pos_adapter.dart
│       │
│       └── printing/                     # Adapters de impressão
│           └── providers/
│               └── stone_thermal_adapter.dart
│
└── presentation/
    ├── providers/
    │   ├── payment_flow_provider.dart     # Provider de pagamento
    │   ├── sale_completion_provider.dart  # Provider de conclusão
    │   ├── invoice_emission_provider.dart # Provider de emissão
    │   └── sale_flow_provider.dart        # 🆕 Provider unificado
    │
    └── screens/
        └── pagamento/
            └── pagamento_restaurante_screen.dart
```

---

## 🔄 Como os Fluxos Se Relacionam

### **Fluxo Completo: Pagamento → Conclusão → Emissão**

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUXO COMPLETO                           │
└─────────────────────────────────────────────────────────────┘

1. PAGAMENTO
   ↓
   [Usuário processa pagamento]
   ↓
   PaymentFlowProvider.processPayment()
   ↓
   PaymentService.processPayment()
   ↓
   StonePOSAdapter.processPayment() (SDK)
   ↓
   ✅ Pagamento processado
   ↓
   └─→ Event: pagamentoProcessado
   ↓
   └─→ Se saldo zerou → Próximo passo

2. CONCLUSÃO DE VENDA
   ↓
   [Usuário clica "Concluir Venda"]
   ↓
   SaleCompletionProvider.completeSale()
   ↓
   SaleCompletionService.completeSale()
   ↓
   VendaService.concluirVenda() (Backend)
   ↓
   ✅ Venda finalizada
   ↓
   └─→ Event: vendaFinalizada
   ↓
   └─→ Se nota fiscal criada → Próximo passo

3. EMISSÃO DE NOTA FISCAL
   ↓
   [Automático após conclusão]
   ↓
   InvoiceEmissionProvider.emitInvoice()
   ↓
   InvoiceEmissionService.emitInvoice()
   ↓
   NfceIntegrationService.EnviarNotaFiscalAsync() (Backend)
   ↓
   ✅ Nota autorizada na SEFAZ
   ↓
   └─→ Event: invoiceAuthorized
   ↓
   └─→ Próximo passo

4. IMPRESSÃO
   ↓
   [Automático após autorização]
   ↓
   PrintService.printNfce()
   ↓
   StoneThermalAdapter.print() (SDK)
   ↓
   ✅ Nota impressa
   ↓
   └─→ Event: invoicePrinted
   ↓
   └─→ Fluxo completo finalizado
```

---

## 🎨 SaleFlowService (Orquestrador Geral)

### **Responsabilidade:**
Coordena os 3 fluxos em sequência, gerenciando o estado geral.

```dart
// sale_flow_service.dart
class SaleFlowService {
  final PaymentService _paymentService;
  final SaleCompletionService _completionService;
  final InvoiceEmissionService _emissionService;
  final PrintService _printService;
  final SaleFlowStateMachine _stateMachine;
  
  /// Processa pagamento (Fluxo 1)
  Future<SaleFlowResult> processPayment(PaymentRequest request) async {
    await _stateMachine.transitionTo(SaleFlowState.processingPayment);
    
    final result = await _paymentService.processPayment(
      providerKey: request.providerKey,
      amount: request.amount,
      vendaId: request.vendaId,
      additionalData: request.additionalData,
      uiNotifier: _uiNotifier,
    );
    
    if (result.success) {
      await _stateMachine.transitionTo(SaleFlowState.paymentProcessed);
      
      // Verifica se saldo zerou
      final venda = await _vendaService.getVendaById(request.vendaId);
      if ((venda.saldoRestante ?? 0) <= 0.01) {
        await _stateMachine.transitionTo(SaleFlowState.readyToComplete);
      } else {
        await _stateMachine.transitionTo(SaleFlowState.idle);
      }
    } else {
      await _stateMachine.transitionTo(SaleFlowState.paymentFailed);
    }
    
    return SaleFlowResult.fromPaymentResult(result);
  }
  
  /// Conclui venda (Fluxo 2)
  Future<SaleFlowResult> completeSale({
    required String vendaId,
    String? clienteCPF,
  }) async {
    await _stateMachine.transitionTo(SaleFlowState.concludingSale);
    
    final result = await _completionService.completeSale(
      vendaId: vendaId,
      clienteCPF: clienteCPF,
      uiNotifier: _uiNotifier,
    );
    
    if (result.success) {
      await _stateMachine.transitionTo(SaleFlowState.saleCompleted);
      
      // Se nota fiscal foi criada, emite automaticamente
      if (result.data?['notaFiscalId'] != null) {
        final notaFiscalId = result.data!['notaFiscalId'] as String;
        return await emitInvoice(notaFiscalId);
      } else {
        await _stateMachine.transitionTo(SaleFlowState.completed);
        return SaleFlowResult.success(data: result.data);
      }
    } else {
      await _stateMachine.transitionTo(SaleFlowState.completionFailed);
      return SaleFlowResult.failure(error: result.error);
    }
  }
  
  /// Emite nota fiscal (Fluxo 3)
  Future<SaleFlowResult> emitInvoice(String notaFiscalId) async {
    await _stateMachine.transitionTo(SaleFlowState.emittingInvoice);
    
    final result = await _emissionService.emitInvoice(
      notaFiscalId: notaFiscalId,
      uiNotifier: _uiNotifier,
    );
    
    if (result.success) {
      await _stateMachine.transitionTo(SaleFlowState.invoiceAuthorized);
      
      // Se nota foi autorizada, imprime automaticamente
      if (result.data?['foiAutorizada'] == true) {
        return await printInvoice(notaFiscalId);
      } else {
        await _stateMachine.transitionTo(SaleFlowState.completed);
        return SaleFlowResult.success(data: result.data);
      }
    } else {
      await _stateMachine.transitionTo(SaleFlowState.emissionFailed);
      return SaleFlowResult.failure(error: result.error);
    }
  }
  
  /// Imprime nota fiscal
  Future<SaleFlowResult> printInvoice(String notaFiscalId) async {
    await _stateMachine.transitionTo(SaleFlowState.printingInvoice);
    
    final result = await _printService.printNfce(
      notaFiscalId: notaFiscalId,
      uiNotifier: _uiNotifier,
    );
    
    if (result.success) {
      await _stateMachine.transitionTo(SaleFlowState.completed);
    } else {
      await _stateMachine.transitionTo(SaleFlowState.printFailed);
    }
    
    return SaleFlowResult.fromPrintResult(result);
  }
  
  /// Stream de estados para UI reagir
  Stream<SaleFlowState> get stateStream => _stateMachine.stateStream;
}
```

---

## 🎯 SaleCompletionService (Fluxo 2)

### **Responsabilidade:**
Conclui a venda no backend e prepara nota fiscal.

```dart
// sale_completion_service.dart
class SaleCompletionService {
  final VendaService _vendaService;
  
  Future<SaleCompletionResult> completeSale({
    required String vendaId,
    String? clienteCPF,
    SaleCompletionUINotifier? uiNotifier,
  }) async {
    try {
      // 1. Notifica UI: "Concluindo venda..."
      uiNotifier?.notify(SaleCompletionUINotification.showProgress(
        message: 'Concluindo venda...',
      ));
      
      // 2. Chama backend para concluir venda
      final response = await _vendaService.concluirVenda(
        vendaId: vendaId,
        clienteCPF: clienteCPF,
      );
      
      if (!response.success || response.data == null) {
        return SaleCompletionResult.failure(
          error: response.message ?? 'Erro ao concluir venda',
        );
      }
      
      final vendaFinalizada = response.data!;
      
      // 3. Verifica se nota fiscal foi criada
      final notaFiscalId = vendaFinalizada.notaFiscal?.id;
      
      if (notaFiscalId != null) {
        // 4. Notifica UI: "Venda concluída. Emitindo nota fiscal..."
        uiNotifier?.notify(SaleCompletionUINotification.showProgress(
          message: 'Venda concluída. Emitindo nota fiscal...',
        ));
        
        return SaleCompletionResult.success(
          data: {
            'venda': vendaFinalizada,
            'notaFiscalId': notaFiscalId,
            'notaFiscal': vendaFinalizada.notaFiscal,
          },
        );
      } else {
        // Venda concluída sem nota fiscal
        uiNotifier?.notify(SaleCompletionUINotification.hideProgress());
        
        return SaleCompletionResult.success(
          data: {
            'venda': vendaFinalizada,
          },
        );
      }
      
    } catch (e, stackTrace) {
      uiNotifier?.notify(SaleCompletionUINotification.hideProgress());
      
      return SaleCompletionResult.failure(
        error: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }
}
```

---

## 🎯 InvoiceEmissionService (Fluxo 3)

### **Responsabilidade:**
Emite nota fiscal na SEFAZ (já é feito no backend, mas podemos monitorar).

```dart
// invoice_emission_service.dart
class InvoiceEmissionService {
  final VendaService _vendaService;
  
  Future<InvoiceEmissionResult> emitInvoice({
    required String notaFiscalId,
    InvoiceEmissionUINotifier? uiNotifier,
  }) async {
    try {
      // 1. Notifica UI: "Enviando para SEFAZ..."
      uiNotifier?.notify(InvoiceEmissionUINotification.showProgress(
        message: 'Enviando nota fiscal para SEFAZ...',
      ));
      
      // 2. A emissão já foi feita no backend durante concluirVenda
      // Aqui apenas verificamos o status
      final response = await _vendaService.getNotaFiscalById(notaFiscalId);
      
      if (!response.success || response.data == null) {
        return InvoiceEmissionResult.failure(
          error: response.message ?? 'Erro ao buscar nota fiscal',
        );
      }
      
      final notaFiscal = response.data!;
      
      // 3. Verifica se foi autorizada
      if (notaFiscal.foiAutorizada) {
        uiNotifier?.notify(InvoiceEmissionUINotification.showProgress(
          message: 'Nota fiscal autorizada!',
        ));
        
        return InvoiceEmissionResult.success(
          data: {
            'notaFiscal': notaFiscal,
            'foiAutorizada': true,
            'chaveAcesso': notaFiscal.chaveAcesso,
            'protocolo': notaFiscal.protocoloAutorizacao,
          },
        );
      } else {
        // Nota ainda não autorizada (pode estar em processamento)
        return InvoiceEmissionResult.failure(
          error: 'Nota fiscal ainda não foi autorizada',
          data: {
            'notaFiscal': notaFiscal,
            'situacao': notaFiscal.situacao,
          },
        );
      }
      
    } catch (e, stackTrace) {
      uiNotifier?.notify(InvoiceEmissionUINotification.hideProgress());
      
      return InvoiceEmissionResult.failure(
        error: e.toString(),
        stackTrace: stackTrace,
      );
    }
  }
}
```

---

## 🎨 SaleFlowProvider (Provider Unificado)

### **Responsabilidade:**
Gerencia estado geral e expõe métodos simples para UI.

```dart
// sale_flow_provider.dart
class SaleFlowProvider extends ChangeNotifier {
  final SaleFlowService _flowService;
  SaleFlowState _currentState = SaleFlowState.idle;
  String? _errorMessage;
  Map<String, dynamic>? _currentData;
  
  SaleFlowProvider(this._flowService) {
    // Escuta mudanças de estado
    _flowService.stateStream.listen((state) {
      _currentState = state;
      notifyListeners();
    });
  }
  
  // Getters
  SaleFlowState get currentState => _currentState;
  String? get errorMessage => _errorMessage;
  bool get isProcessing => _isProcessingStates.contains(_currentState);
  bool get canProcessPayment => _currentState == SaleFlowState.idle;
  bool get canCompleteSale => _currentState == SaleFlowState.readyToComplete;
  
  /// Processa pagamento (delega para Service)
  Future<bool> processPayment(PaymentRequest request) async {
    _errorMessage = null;
    notifyListeners();
    
    final result = await _flowService.processPayment(request);
    
    if (!result.success) {
      _errorMessage = result.error;
      notifyListeners();
      return false;
    }
    
    _currentData = result.data;
    return true;
  }
  
  /// Conclui venda (delega para Service)
  Future<bool> completeSale({
    required String vendaId,
    String? clienteCPF,
  }) async {
    _errorMessage = null;
    notifyListeners();
    
    final result = await _flowService.completeSale(
      vendaId: vendaId,
      clienteCPF: clienteCPF,
    );
    
    if (!result.success) {
      _errorMessage = result.error;
      notifyListeners();
      return false;
    }
    
    _currentData = result.data;
    return true;
  }
  
  static const _isProcessingStates = {
    SaleFlowState.processingPayment,
    SaleFlowState.concludingSale,
    SaleFlowState.emittingInvoice,
    SaleFlowState.printingInvoice,
  };
}
```

---

## 🔄 Fluxo Completo Integrado

### **Cenário: Pagamento → Conclusão → Emissão → Impressão**

```dart
// pagamento_restaurante_screen.dart
class PagamentoRestauranteScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SaleFlowProvider>(
      builder: (context, provider, child) {
        // UI reage ao estado atual
        switch (provider.currentState) {
          case SaleFlowState.idle:
            return _buildPaymentForm(context, provider);
          
          case SaleFlowState.processingPayment:
            return _buildLoading('Processando pagamento...');
          
          case SaleFlowState.paymentProcessed:
            if (provider.currentData?['saldoZerou'] == true) {
              return _buildCompleteSaleDialog(context, provider);
            }
            return _buildPaymentForm(context, provider);
          
          case SaleFlowState.concludingSale:
            return _buildLoading('Concluindo venda...');
          
          case SaleFlowState.emittingInvoice:
            return _buildLoading('Emitindo nota fiscal...');
          
          case SaleFlowState.printingInvoice:
            return _buildLoading('Imprimindo nota fiscal...');
          
          case SaleFlowState.completed:
            return _buildSuccess('Venda concluída com sucesso!');
          
          case SaleFlowState.paymentFailed:
          case SaleFlowState.completionFailed:
          case SaleFlowState.emissionFailed:
          case SaleFlowState.printFailed:
            return _buildError(provider.errorMessage ?? 'Erro desconhecido');
          
          default:
            return _buildPaymentForm(context, provider);
        }
      },
    );
  }
  
  Future<void> _handlePayment(BuildContext context, SaleFlowProvider provider) async {
    final request = PaymentRequest(...);
    await provider.processPayment(request);
  }
  
  Future<void> _handleCompleteSale(BuildContext context, SaleFlowProvider provider) async {
    await provider.completeSale(
      vendaId: widget.venda.id,
      clienteCPF: _clienteCPF,
    );
  }
}
```

---

## 📊 Máquina de Estados Completa

```dart
enum SaleFlowState {
  // Estados iniciais
  idle,                    // Aguardando ação
  
  // Estados de pagamento
  processingPayment,       // Processando pagamento
  paymentProcessed,        // Pagamento processado
  paymentFailed,           // Pagamento falhou
  readyToComplete,         // Pronto para concluir (saldo zerou)
  
  // Estados de conclusão
  concludingSale,          // Concluindo venda
  saleCompleted,           // Venda concluída
  completionFailed,        // Conclusão falhou
  
  // Estados de emissão
  emittingInvoice,         // Emitindo nota fiscal
  invoiceAuthorized,       // Nota autorizada
  emissionFailed,          // Emissão falhou
  
  // Estados de impressão
  printingInvoice,         // Imprimindo nota
  printSuccess,           // Impressão concluída
  printFailed,            // Impressão falhou
  
  // Estados finais
  completed,               // Fluxo completo
  cancelled,               // Fluxo cancelado
  error,                   // Erro genérico
}
```

**Transições:**
```
idle
  ↓ [processPayment]
processingPayment
  ↓ [sucesso]              ↓ [falha]
paymentProcessed          paymentFailed
  ↓ [saldo zerou?]
  ├─ SIM → readyToComplete
  └─ NÃO → idle

readyToComplete
  ↓ [completeSale]
concludingSale
  ↓ [sucesso]              ↓ [falha]
saleCompleted             completionFailed
  ↓ [tem nota fiscal?]
  ├─ SIM → emittingInvoice
  └─ NÃO → completed

emittingInvoice
  ↓ [sucesso]              ↓ [falha]
invoiceAuthorized         emissionFailed
  ↓ [foi autorizada?]
  ├─ SIM → printingInvoice
  └─ NÃO → completed

printingInvoice
  ↓ [sucesso]              ↓ [falha]
printSuccess              printFailed
  ↓
completed
```

---

## ✅ Vantagens desta Arquitetura

### **1. Separação Clara**
- Cada fluxo tem sua responsabilidade
- Fácil entender o que cada um faz
- Fácil encontrar código relacionado

### **2. Reutilização**
- Componentes comuns podem ser compartilhados
- Services podem ser usados independentemente
- Providers podem ser usados separadamente

### **3. Testabilidade**
- Cada fluxo pode ser testado isoladamente
- Fácil mockar dependências
- Fácil testar integração entre fluxos

### **4. Manutenibilidade**
- Mudanças em um fluxo não afetam outros
- Fácil adicionar novos fluxos
- Fácil evoluir cada fluxo independentemente

### **5. Flexibilidade**
- UI pode usar fluxos separadamente
- UI pode usar orquestrador geral
- Fácil adicionar novos tipos de pagamento/emissão

---

## 🎯 Resumo

**Estrutura:**
- ✅ **3 fluxos separados** (Payment, SaleCompletion, InvoiceEmission)
- ✅ **1 orquestrador geral** (SaleFlowService)
- ✅ **1 provider unificado** (SaleFlowProvider)

**Como funcionam:**
1. **Pagamento** → Processa pagamento via SDK
2. **Conclusão** → Finaliza venda e cria nota fiscal
3. **Emissão** → Emite nota na SEFAZ (backend)
4. **Impressão** → Imprime nota via SDK

**Orquestrador:**
- Coordena os 3 fluxos em sequência
- Gerencia estado geral
- Notifica UI sobre progresso

**UI:**
- Usa Provider unificado
- Reage a estados automaticamente
- Mostra loading/progresso em cada etapa

**Tudo desacoplado, testável e fácil de manter!** 🎉

