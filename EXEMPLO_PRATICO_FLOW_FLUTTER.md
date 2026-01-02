# 🎯 Exemplo Prático: Como Funciona o Flow no Flutter

## 📋 Visão Geral

Vou mostrar **passo a passo** como o fluxo funciona na prática, desde o clique do usuário até a atualização da UI.

---

## 🎬 Cenário: Usuário Processa um Pagamento

### **Situação:**
- Usuário está na tela de pagamento
- Selecionou "Cartão Crédito" e digitou R$ 50,00
- Clicou em "Processar Pagamento"

---

## 📐 Estrutura de Arquivos

```
lib/
├── core/
│   └── sale_flow/
│       ├── sale_flow_service.dart          # Orquestrador principal
│       ├── commands/
│       │   └── process_payment_command.dart # Command de pagamento
│       └── models/
│           ├── payment_request.dart
│           └── sale_flow_result.dart
│
├── presentation/
│   ├── providers/
│   │   └── sale_flow_provider.dart         # Provider para UI
│   └── screens/
│       └── pagamento/
│           └── pagamento_restaurante_screen.dart
```

---

## 🔄 Fluxo Completo Passo a Passo

### **PASSO 1: Usuário clica no botão**

```dart
// pagamento_restaurante_screen.dart
ElevatedButton(
  onPressed: () async {
    // Usuário clicou em "Processar Pagamento"
    await _processarPagamento();
  },
  child: Text('Processar Pagamento'),
)
```

---

### **PASSO 2: UI prepara request e chama Provider**

```dart
// pagamento_restaurante_screen.dart
Future<void> _processarPagamento() async {
  // 1. Prepara dados do pagamento
  final request = PaymentRequest(
    vendaId: widget.venda.id,
    providerKey: 'stone_pos', // Cartão crédito
    amount: 50.00,
    formaPagamento: 'Cartão Crédito',
    additionalData: {
      'tipoTransacao': 'credit',
      'parcelas': 1,
    },
  );
  
  // 2. Obtém o Provider (via Provider/Consumer)
  final flowProvider = Provider.of<SaleFlowProvider>(context, listen: false);
  
  // 3. Chama método do Provider
  final success = await flowProvider.processPayment(request);
  
  // 4. UI reage ao resultado
  if (success) {
    AppToast.showSuccess(context, 'Pagamento realizado!');
  } else {
    AppToast.showError(context, flowProvider.errorMessage ?? 'Erro ao processar');
  }
}
```

**O que acontece aqui:**
- UI apenas prepara dados e chama Provider
- UI não conhece detalhes de implementação
- UI apenas reage ao resultado (sucesso/erro)

---

### **PASSO 3: Provider chama Service**

```dart
// sale_flow_provider.dart
class SaleFlowProvider extends ChangeNotifier {
  final SaleFlowService _flowService;
  SaleFlowState _currentState = SaleFlowState.idle;
  String? _errorMessage;
  
  SaleFlowProvider(this._flowService);
  
  Future<bool> processPayment(PaymentRequest request) async {
    // 1. Limpa erro anterior
    _errorMessage = null;
    notifyListeners(); // Notifica UI que está processando
    
    // 2. Chama Service (que vai executar o Command)
    final result = await _flowService.processPayment(request);
    
    // 3. Atualiza estado interno
    if (!result.success) {
      _errorMessage = result.error;
      notifyListeners(); // Notifica UI do erro
      return false;
    }
    
    // 4. Sucesso!
    notifyListeners(); // Notifica UI do sucesso
    return true;
  }
  
  // Getters para UI consumir
  SaleFlowState get currentState => _currentState;
  String? get errorMessage => _errorMessage;
  bool get isProcessing => _currentState == SaleFlowState.processingPayment;
}
```

**O que acontece aqui:**
- Provider é um intermediário entre UI e Service
- Provider gerencia estado local (para UI reagir)
- Provider notifica UI via `notifyListeners()`

---

### **PASSO 4: Service cria e executa Command**

```dart
// sale_flow_service.dart
class SaleFlowService {
  final PaymentService _paymentService;
  final VendaService _vendaService;
  
  Future<SaleFlowResult> processPayment(PaymentRequest request) async {
    // 1. Cria contexto (dependências que o Command precisa)
    final context = SaleFlowContext(
      paymentService: _paymentService,
      vendaService: _vendaService,
    );
    
    // 2. Cria Command
    final command = ProcessPaymentCommand(request);
    
    // 3. Executa Command (aqui acontece a mágica!)
    final result = await command.execute(context);
    
    // 4. Se sucesso, dispara Event para notificar outros componentes
    if (result.success) {
      AppEventBus.instance.dispararPagamentoProcessado(
        vendaId: request.vendaId,
        valor: request.amount,
        mesaId: request.mesaId,
      );
    }
    
    // 5. Retorna resultado para Provider
    return result;
  }
}
```

**O que acontece aqui:**
- Service orquestra o fluxo
- Service cria Command e passa contexto
- Service dispara Event se sucesso
- Service retorna resultado

---

### **PASSO 5: Command executa a lógica**

```dart
// process_payment_command.dart
class ProcessPaymentCommand {
  final PaymentRequest request;
  
  ProcessPaymentCommand(this.request);
  
  Future<SaleFlowResult> execute(SaleFlowContext context) async {
    try {
      // ========== ETAPA 1: Validação ==========
      if (request.amount <= 0) {
        return SaleFlowResult.failure(
          error: 'Valor inválido',
          state: SaleFlowState.paymentFailed,
        );
      }
      
      // ========== ETAPA 2: Processa via Provider (SDK) ==========
      debugPrint('💳 Processando pagamento via ${request.providerKey}...');
      
      final paymentResult = await context.paymentService.processPayment(
        providerKey: request.providerKey,
        amount: request.amount,
        vendaId: request.vendaId,
        additionalData: request.additionalData,
      );
      
      if (!paymentResult.success) {
        return SaleFlowResult.failure(
          error: paymentResult.errorMessage ?? 'Erro ao processar pagamento',
          state: SaleFlowState.paymentFailed,
        );
      }
      
      debugPrint('✅ Pagamento processado via SDK. TransactionId: ${paymentResult.transactionId}');
      
      // ========== ETAPA 3: Registra no servidor ==========
      debugPrint('💾 Registrando pagamento no servidor...');
      
      final registroResult = await context.vendaService.registrarPagamento(
        vendaId: request.vendaId,
        valor: request.amount,
        formaPagamento: request.formaPagamento,
        tipoFormaPagamento: 2, // Cartão
        identificadorTransacao: paymentResult.transactionId,
        bandeiraCartao: paymentResult.transactionData?.cardBrand,
      );
      
      if (!registroResult.success) {
        return SaleFlowResult.failure(
          error: registroResult.message ?? 'Erro ao registrar pagamento',
          state: SaleFlowState.paymentFailed,
        );
      }
      
      debugPrint('✅ Pagamento registrado no servidor');
      
      // ========== ETAPA 4: Verifica se saldo zerou ==========
      final vendaAtualizada = await context.vendaService.getVendaById(request.vendaId);
      final saldoZerou = (vendaAtualizada.data?.saldoRestante ?? 0) <= 0.01;
      
      debugPrint('💰 Saldo restante: R\$ ${vendaAtualizada.data?.saldoRestante ?? 0}');
      debugPrint('💰 Saldo zerou: $saldoZerou');
      
      // ========== ETAPA 5: Retorna resultado ==========
      return SaleFlowResult.success(
        data: {
          'paymentResult': paymentResult,
          'venda': vendaAtualizada.data,
          'saldoZerou': saldoZerou,
        },
        nextState: saldoZerou 
          ? SaleFlowState.paymentProcessed 
          : SaleFlowState.idle,
      );
      
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao processar pagamento: $e');
      return SaleFlowResult.failure(
        error: e.toString(),
        state: SaleFlowState.paymentFailed,
        stackTrace: stackTrace,
      );
    }
  }
}
```

**O que acontece aqui:**
- Command encapsula TODA a lógica de processamento
- Command valida, processa, registra e verifica
- Command retorna resultado estruturado
- Command pode ser testado isoladamente

---

### **PASSO 6: Event é disparado (se sucesso)**

```dart
// sale_flow_service.dart (continuação do PASSO 4)
if (result.success) {
  // Dispara Event para notificar outros componentes
  AppEventBus.instance.dispararPagamentoProcessado(
    vendaId: request.vendaId,
    valor: request.amount,
    mesaId: request.mesaId,
  );
}
```

**O que acontece aqui:**
- Event é disparado de forma assíncrona
- Não bloqueia o fluxo principal
- Múltiplos componentes podem escutar

---

### **PASSO 7: Outros componentes reagem ao Event**

```dart
// venda_provider.dart
class VendaProvider extends ChangeNotifier {
  VendaProvider() {
    // Escuta eventos de pagamento
    AppEventBus.instance.on(TipoEvento.pagamentoProcessado).listen((evento) {
      debugPrint('📢 [VendaProvider] Pagamento processado: ${evento.vendaId}');
      
      // Atualiza estado local (sem ir no servidor)
      _atualizarVendaLocal(evento.vendaId);
      notifyListeners(); // Notifica UI
    });
  }
  
  void _atualizarVendaLocal(String vendaId) {
    // Atualiza saldo localmente
    // Não precisa buscar do servidor (já sabemos que pagamento foi processado)
  }
}
```

```dart
// mesa_detalhes_provider.dart
class MesaDetalhesProvider extends ChangeNotifier {
  MesaDetalhesProvider() {
    // Também escuta eventos de pagamento
    AppEventBus.instance.on(TipoEvento.pagamentoProcessado).listen((evento) {
      debugPrint('📢 [MesaDetalhesProvider] Pagamento processado na mesa: ${evento.mesaId}');
      
      // Atualiza UI da mesa
      _atualizarMesa(evento.mesaId);
      notifyListeners();
    });
  }
}
```

**O que acontece aqui:**
- Múltiplos componentes escutam o mesmo Event
- Cada componente reage de forma independente
- Desacoplamento total entre componentes

---

## 🎨 Como a UI Reage (Flutter Widget)

### **Opção 1: Consumer (reage a mudanças do Provider)**

```dart
// pagamento_restaurante_screen.dart
class PagamentoRestauranteScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SaleFlowProvider>(
      builder: (context, flowProvider, child) {
        // UI reage automaticamente quando Provider muda
        if (flowProvider.isProcessing) {
          return CircularProgressIndicator(); // Mostra loading
        }
        
        if (flowProvider.errorMessage != null) {
          return Text('Erro: ${flowProvider.errorMessage}'); // Mostra erro
        }
        
        return PaymentForm(
          onPaymentRequested: (request) {
            // Chama Provider quando usuário clica
            flowProvider.processPayment(request);
          },
        );
      },
    );
  }
}
```

**Como funciona:**
- `Consumer` escuta mudanças do Provider
- Quando Provider chama `notifyListeners()`, `Consumer` reconstrói o widget
- UI atualiza automaticamente

---

### **Opção 2: StreamBuilder (reage a mudanças de estado)**

```dart
// pagamento_restaurante_screen.dart
class PagamentoRestauranteScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final flowProvider = Provider.of<SaleFlowProvider>(context);
    
    return StreamBuilder<SaleFlowState>(
      stream: flowProvider.stateStream, // Stream de estados
      initialData: SaleFlowState.idle,
      builder: (context, snapshot) {
        final state = snapshot.data ?? SaleFlowState.idle;
        
        // UI reage ao estado atual
        switch (state) {
          case SaleFlowState.idle:
            return _buildPaymentForm(context, flowProvider);
          
          case SaleFlowState.processingPayment:
            return _buildLoading('Processando pagamento...');
          
          case SaleFlowState.paymentProcessed:
            return _buildSuccess('Pagamento realizado!');
          
          case SaleFlowState.paymentFailed:
            return _buildError(flowProvider.errorMessage ?? 'Erro desconhecido');
          
          default:
            return _buildPaymentForm(context, flowProvider);
        }
      },
    );
  }
}
```

**Como funciona:**
- `StreamBuilder` escuta um Stream de estados
- Quando estado muda, `StreamBuilder` reconstrói o widget
- UI mostra conteúdo diferente baseado no estado

---

## 📊 Diagrama Completo do Fluxo

```
┌─────────────────────────────────────────────────────────────┐
│                    USUÁRIO CLICA NO BOTÃO                    │
└───────────────────────────┬───────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  pagamento_restaurante_screen.dart                          │
│  - Prepara PaymentRequest                                   │
│  - Chama flowProvider.processPayment(request)               │
└───────────────────────────┬───────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  sale_flow_provider.dart (ChangeNotifier)                  │
│  - Limpa erro anterior                                     │
│  - Chama _flowService.processPayment(request)              │
│  - notifyListeners() → UI atualiza                          │
└───────────────────────────┬───────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  sale_flow_service.dart                                     │
│  - Cria SaleFlowContext                                     │
│  - Cria ProcessPaymentCommand                               │
│  - Executa command.execute(context)                         │
└───────────────────────────┬───────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  process_payment_command.dart                               │
│  1. Valida request                                          │
│  2. Processa via paymentService (SDK)                       │
│  3. Registra via vendaService (servidor)                    │
│  4. Verifica se saldo zerou                                 │
│  5. Retorna SaleFlowResult                                  │
└───────────────────────────┬───────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  sale_flow_service.dart (continuação)                      │
│  - Se sucesso → dispara Event                               │
│  - Retorna resultado para Provider                          │
└───────────────────────────┬───────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  AppEventBus.dispararPagamentoProcessado()                 │
│  - Event é propagado para todos os listeners                │
└───────────┬───────────────────────────────┬─────────────────┘
            │                               │
            ↓                               ↓
┌───────────────────────┐   ┌──────────────────────────────┐
│  venda_provider.dart  │   │ mesa_detalhes_provider.dart │
│  - Escuta evento      │   │ - Escuta evento             │
│  - Atualiza estado    │   │ - Atualiza UI da mesa       │
│  - notifyListeners()  │   │ - notifyListeners()         │
└───────────────────────┘   └──────────────────────────────┘
            │                               │
            └───────────────┬───────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  sale_flow_provider.dart (continuação)                     │
│  - Recebe resultado do Service                              │
│  - Atualiza estado interno                                  │
│  - notifyListeners() → UI atualiza                          │
└───────────────────────────┬───────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  pagamento_restaurante_screen.dart                          │
│  - Consumer detecta mudança                                 │
│  - Reconstrói widget                                       │
│  - Mostra sucesso/erro                                     │
└─────────────────────────────────────────────────────────────┘
```

---

## 💡 Exemplo de Código Completo e Funcional

### **1. Modelos**

```dart
// payment_request.dart
class PaymentRequest {
  final String vendaId;
  final String providerKey;
  final double amount;
  final String formaPagamento;
  final Map<String, dynamic>? additionalData;
  
  PaymentRequest({
    required this.vendaId,
    required this.providerKey,
    required this.amount,
    required this.formaPagamento,
    this.additionalData,
  });
}

// sale_flow_result.dart
class SaleFlowResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? data;
  final SaleFlowState? nextState;
  
  SaleFlowResult.success({
    this.data,
    this.nextState,
  }) : success = true, error = null;
  
  SaleFlowResult.failure({
    required this.error,
    this.state,
  }) : success = false, data = null, nextState = state;
}
```

### **2. Context (dependências)**

```dart
// sale_flow_context.dart
class SaleFlowContext {
  final PaymentService paymentService;
  final VendaService vendaService;
  final PrintService printService;
  
  SaleFlowContext({
    required this.paymentService,
    required this.vendaService,
    required this.printService,
  });
}
```

### **3. Command**

```dart
// process_payment_command.dart
class ProcessPaymentCommand {
  final PaymentRequest request;
  
  ProcessPaymentCommand(this.request);
  
  Future<SaleFlowResult> execute(SaleFlowContext context) async {
    // Lógica completa aqui (já mostrada acima)
    // ...
  }
}
```

### **4. Service**

```dart
// sale_flow_service.dart
class SaleFlowService {
  final PaymentService _paymentService;
  final VendaService _vendaService;
  final PrintService _printService;
  
  Future<SaleFlowResult> processPayment(PaymentRequest request) async {
    final context = SaleFlowContext(
      paymentService: _paymentService,
      vendaService: _vendaService,
      printService: _printService,
    );
    
    final command = ProcessPaymentCommand(request);
    final result = await command.execute(context);
    
    if (result.success) {
      AppEventBus.instance.dispararPagamentoProcessado(
        vendaId: request.vendaId,
        valor: request.amount,
      );
    }
    
    return result;
  }
}
```

### **5. Provider**

```dart
// sale_flow_provider.dart
class SaleFlowProvider extends ChangeNotifier {
  final SaleFlowService _flowService;
  String? _errorMessage;
  bool _isProcessing = false;
  
  SaleFlowProvider(this._flowService);
  
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  
  Future<bool> processPayment(PaymentRequest request) async {
    _errorMessage = null;
    _isProcessing = true;
    notifyListeners();
    
    final result = await _flowService.processPayment(request);
    
    _isProcessing = false;
    
    if (!result.success) {
      _errorMessage = result.error;
      notifyListeners();
      return false;
    }
    
    notifyListeners();
    return true;
  }
}
```

### **6. UI**

```dart
// pagamento_restaurante_screen.dart
class PagamentoRestauranteScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SaleFlowProvider>(
      builder: (context, provider, child) {
        if (provider.isProcessing) {
          return CircularProgressIndicator();
        }
        
        return ElevatedButton(
          onPressed: () async {
            final request = PaymentRequest(
              vendaId: widget.venda.id,
              providerKey: 'stone_pos',
              amount: 50.00,
              formaPagamento: 'Cartão Crédito',
            );
            
            final success = await provider.processPayment(request);
            
            if (success) {
              AppToast.showSuccess(context, 'Pagamento realizado!');
            } else {
              AppToast.showError(context, provider.errorMessage ?? 'Erro');
            }
          },
          child: Text('Processar Pagamento'),
        );
      },
    );
  }
}
```

---

## ✅ Vantagens Práticas no Flutter

### **1. UI Reativa**
- `Consumer` ou `StreamBuilder` atualizam automaticamente
- Não precisa chamar `setState()` manualmente
- UI sempre sincronizada com estado

### **2. Testabilidade**
- Command pode ser testado isoladamente
- Provider pode ser testado isoladamente
- Service pode ser testado isoladamente

### **3. Manutenibilidade**
- Cada componente tem responsabilidade clara
- Fácil encontrar onde está a lógica
- Fácil adicionar novos comandos

### **4. Desacoplamento**
- UI não conhece detalhes de implementação
- Componentes se comunicam via Events
- Fácil trocar implementação

---

## 🎯 Resumo

1. **UI** → Chama Provider
2. **Provider** → Chama Service
3. **Service** → Cria e executa Command
4. **Command** → Executa lógica completa
5. **Service** → Dispara Event (se sucesso)
6. **Outros componentes** → Reagem ao Event
7. **Provider** → Atualiza estado e notifica UI
8. **UI** → Reconstrói automaticamente

**Tudo isso acontece de forma reativa e desacoplada!**

