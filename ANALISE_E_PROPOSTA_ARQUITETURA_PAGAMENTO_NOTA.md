# 🏗️ Análise e Proposta de Arquitetura: Fluxo de Pagamento e Emissão de Nota

## 📋 Problemas Identificados no Código Atual

### 1. **Código Sequencial Misturado com UI**
- Lógica de negócio dentro de `StatefulWidget` (pagamento_restaurante_screen.dart)
- Métodos longos com múltiplas responsabilidades
- Difícil testar e reutilizar

### 2. **Falta de Separação de Responsabilidades**
- Pagamento, emissão de nota e conclusão de venda estão todos no mesmo lugar
- Não há camada de serviço dedicada para o fluxo completo
- UI conhece detalhes de implementação

### 3. **Falta de Máquina de Estados**
- Não há visão clara dos estados do fluxo
- Transições de estado não são explícitas
- Difícil rastrear o que está acontecendo

### 4. **Tratamento de Erros Inconsistente**
- Erros tratados de forma diferente em cada lugar
- Não há estratégia unificada de retry/fallback
- Feedback ao usuário não é padronizado

### 5. **Falta de Feedback ao Usuário**
- Loading states não são consistentes
- Não há indicação clara de progresso em operações longas
- Mensagens de erro não são padronizadas

### 6. **Eventos Não Estruturados**
- Eventos existem mas não há máquina de estados clara
- Difícil rastrear o fluxo completo
- Não há garantia de que todos os listeners foram notificados

### 7. **Código Duplicado**
- Lógica similar em `pagamento_restaurante_screen.dart` e `detalhes_produtos_mesa_screen.dart`
- Validações repetidas em vários lugares
- Lógica de impressão NFC-e duplicada

---

## 🎯 Proposta de Arquitetura

### **Arquitetura Baseada em:**
1. **State Machine** - Gerencia estados do fluxo
2. **Command Pattern** - Encapsula ações
3. **Event-Driven** - Comunicação assíncrona
4. **Service Layer** - Lógica de negócio isolada
5. **Repository Pattern** - Acesso a dados

---

## 📐 Estrutura Proposta

```
lib/
├── core/
│   ├── sale_flow/                    # 🆕 NOVO: Fluxo de venda completo
│   │   ├── sale_flow_state_machine.dart
│   │   ├── sale_flow_commands.dart
│   │   ├── sale_flow_events.dart
│   │   └── sale_flow_service.dart
│   │
│   ├── payment/                      # ✅ EXISTE (melhorar)
│   │   ├── payment_service.dart
│   │   └── payment_provider.dart
│   │
│   └── printing/                     # ✅ EXISTE (melhorar)
│       ├── print_service.dart
│       └── print_provider.dart
│
├── data/
│   ├── services/
│   │   └── venda_service.dart        # ✅ EXISTE (usar como repository)
│   │
│   └── models/
│       └── sale_flow/                # 🆕 NOVO: Modelos do fluxo
│           ├── sale_state.dart
│           ├── payment_request.dart
│           └── sale_result.dart
│
└── presentation/
    ├── screens/
    │   └── pagamento/                 # ✅ EXISTE (simplificar)
    │       └── pagamento_restaurante_screen.dart
    │
    └── providers/
        └── sale_flow_provider.dart    # 🆕 NOVO: Provider do fluxo
```

---

## 🔄 Máquina de Estados do Fluxo

### **Estados Possíveis:**

```dart
enum SaleFlowState {
  // Estados iniciais
  idle,                    // Aguardando ação do usuário
  initializing,            // Inicializando fluxo
  
  // Estados de pagamento
  paymentMethodSelected,   // Método de pagamento selecionado
  processingPayment,       // Processando pagamento (SDK/API)
  paymentProcessed,        // Pagamento processado com sucesso
  paymentFailed,           // Pagamento falhou
  
  // Estados de conclusão
  concludingSale,          // Concluindo venda
  creatingInvoice,         // Criando nota fiscal
  sendingToSefaz,          // Enviando para SEFAZ
  invoiceAuthorized,       // Nota autorizada
  invoiceFailed,           // Nota falhou
  
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

### **Transições de Estado:**

```
idle
  ↓ [usuário seleciona método]
paymentMethodSelected
  ↓ [usuário confirma pagamento]
processingPayment
  ↓ [sucesso]              ↓ [falha]
paymentProcessed          paymentFailed
  ↓ [saldo zerou?]          ↓ [retry/cancel]
  ├─ SIM → concludingSale
  └─ NÃO → idle (aguarda próximo pagamento)

concludingSale
  ↓
creatingInvoice
  ↓
sendingToSefaz
  ↓ [sucesso]              ↓ [falha]
invoiceAuthorized         invoiceFailed
  ↓                         ↓ [retry/cancel]
printingInvoice
  ↓ [sucesso]              ↓ [falha]
printSuccess              printFailed
  ↓                         ↓ [retry/cancel]
completed
```

---

## 🎨 Componentes da Arquitetura

### **1. SaleFlowStateMachine**

Gerencia os estados e transições do fluxo.

```dart
class SaleFlowStateMachine {
  SaleFlowState _currentState = SaleFlowState.idle;
  final StreamController<SaleFlowState> _stateController = StreamController.broadcast();
  
  Stream<SaleFlowState> get stateStream => _stateController.stream;
  SaleFlowState get currentState => _currentState;
  
  bool canTransitionTo(SaleFlowState newState) {
    // Valida se a transição é permitida
    return _allowedTransitions[_currentState]?.contains(newState) ?? false;
  }
  
  Future<void> transitionTo(SaleFlowState newState, {Map<String, dynamic>? data}) async {
    if (!canTransitionTo(newState)) {
      throw InvalidStateTransitionException(
        'Cannot transition from $_currentState to $newState'
      );
    }
    
    _currentState = newState;
    _stateController.add(newState);
    
    // Dispara evento de mudança de estado
    AppEventBus.instance.dispararEstadoFluxoVenda(
      estadoAnterior: _previousState,
      estadoNovo: newState,
      dados: data,
    );
  }
}
```

### **2. SaleFlowCommands**

Encapsula ações do fluxo.

```dart
abstract class SaleFlowCommand {
  Future<SaleFlowResult> execute(SaleFlowContext context);
}

class ProcessPaymentCommand extends SaleFlowCommand {
  final PaymentRequest request;
  
  ProcessPaymentCommand(this.request);
  
  @override
  Future<SaleFlowResult> execute(SaleFlowContext context) async {
    try {
      // 1. Valida request
      await _validateRequest(request);
      
      // 2. Processa pagamento via provider
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
      
      // 3. Registra pagamento no servidor
      final registroResult = await context.vendaService.registrarPagamento(
        vendaId: request.vendaId,
        valor: request.amount,
        formaPagamento: request.formaPagamento,
        // ... outros campos
      );
      
      if (!registroResult.success) {
        return SaleFlowResult.failure(
          error: registroResult.message ?? 'Erro ao registrar pagamento',
          state: SaleFlowState.paymentFailed,
        );
      }
      
      // 4. Verifica se saldo zerou
      final vendaAtualizada = await context.vendaService.getVendaById(request.vendaId);
      final saldoZerou = (vendaAtualizada.data?.saldoRestante ?? 0) <= 0.01;
      
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
      return SaleFlowResult.failure(
        error: e.toString(),
        state: SaleFlowState.paymentFailed,
        stackTrace: stackTrace,
      );
    }
  }
}

class ConcludeSaleCommand extends SaleFlowCommand {
  final String vendaId;
  final String? clienteCPF;
  
  ConcludeSaleCommand({
    required this.vendaId,
    this.clienteCPF,
  });
  
  @override
  Future<SaleFlowResult> execute(SaleFlowContext context) async {
    try {
      // 1. Conclui venda no servidor
      final concluirResult = await context.vendaService.concluirVenda(
        vendaId: vendaId,
        clienteCPF: clienteCPF,
      );
      
      if (!concluirResult.success) {
        return SaleFlowResult.failure(
          error: concluirResult.message ?? 'Erro ao concluir venda',
          state: SaleFlowState.invoiceFailed,
        );
      }
      
      final vendaFinalizada = concluirResult.data!;
      
      // 2. Verifica se nota foi autorizada
      final notaAutorizada = vendaFinalizada.notaFiscal?.foiAutorizada ?? false;
      
      if (notaAutorizada) {
        return SaleFlowResult.success(
          data: {
            'venda': vendaFinalizada,
            'notaFiscal': vendaFinalizada.notaFiscal,
          },
          nextState: SaleFlowState.invoiceAuthorized,
        );
      }
      
      return SaleFlowResult.success(
        data: {
          'venda': vendaFinalizada,
        },
        nextState: SaleFlowState.completed,
      );
      
    } catch (e, stackTrace) {
      return SaleFlowResult.failure(
        error: e.toString(),
        state: SaleFlowState.invoiceFailed,
        stackTrace: stackTrace,
      );
    }
  }
}

class PrintInvoiceCommand extends SaleFlowCommand {
  final String notaFiscalId;
  
  PrintInvoiceCommand(this.notaFiscalId);
  
  @override
  Future<SaleFlowResult> execute(SaleFlowContext context) async {
    try {
      // 1. Busca dados para impressão
      final dadosImpressao = await context.vendaService.getDadosImpressaoNfce(notaFiscalId);
      
      if (!dadosImpressao.success || dadosImpressao.data == null) {
        return SaleFlowResult.failure(
          error: dadosImpressao.message ?? 'Erro ao buscar dados para impressão',
          state: SaleFlowState.printFailed,
        );
      }
      
      // 2. Imprime via print service
      final printResult = await context.printService.printNfce(
        dadosImpressao.data!,
      );
      
      if (!printResult.success) {
        return SaleFlowResult.failure(
          error: printResult.errorMessage ?? 'Erro ao imprimir',
          state: SaleFlowState.printFailed,
        );
      }
      
      return SaleFlowResult.success(
        data: {
          'notaFiscalId': notaFiscalId,
        },
        nextState: SaleFlowState.printSuccess,
      );
      
    } catch (e, stackTrace) {
      return SaleFlowResult.failure(
        error: e.toString(),
        state: SaleFlowState.printFailed,
        stackTrace: stackTrace,
      );
    }
  }
}
```

### **3. SaleFlowService**

Orquestra o fluxo completo.

```dart
class SaleFlowService {
  final SaleFlowStateMachine _stateMachine;
  final PaymentService _paymentService;
  final VendaService _vendaService;
  final PrintService _printService;
  
  SaleFlowService({
    required SaleFlowStateMachine stateMachine,
    required PaymentService paymentService,
    required VendaService vendaService,
    required PrintService printService,
  }) : _stateMachine = stateMachine,
       _paymentService = paymentService,
       _vendaService = vendaService,
       _printService = printService;
  
  /// Processa um pagamento
  Future<SaleFlowResult> processPayment(PaymentRequest request) async {
    // Cria contexto
    final context = SaleFlowContext(
      paymentService: _paymentService,
      vendaService: _vendaService,
      printService: _printService,
    );
    
    // Executa comando
    final command = ProcessPaymentCommand(request);
    final result = await command.execute(context);
    
    // Atualiza estado
    if (result.success) {
      await _stateMachine.transitionTo(
        result.nextState ?? SaleFlowState.paymentProcessed,
        data: result.data,
      );
    } else {
      await _stateMachine.transitionTo(
        result.state ?? SaleFlowState.paymentFailed,
        data: {'error': result.error},
      );
    }
    
    return result;
  }
  
  /// Conclui a venda e emite nota fiscal
  Future<SaleFlowResult> concludeSale({
    required String vendaId,
    String? clienteCPF,
  }) async {
    final context = SaleFlowContext(
      paymentService: _paymentService,
      vendaService: _vendaService,
      printService: _printService,
    );
    
    final command = ConcludeSaleCommand(
      vendaId: vendaId,
      clienteCPF: clienteCPF,
    );
    
    final result = await command.execute(context);
    
    if (result.success) {
      await _stateMachine.transitionTo(
        result.nextState ?? SaleFlowState.invoiceAuthorized,
        data: result.data,
      );
      
      // Se nota foi autorizada, imprime automaticamente
      if (result.nextState == SaleFlowState.invoiceAuthorized) {
        final notaFiscal = result.data?['notaFiscal'] as NotaFiscalInfoDto?;
        if (notaFiscal != null) {
          await printInvoice(notaFiscal.id);
        }
      }
    } else {
      await _stateMachine.transitionTo(
        result.state ?? SaleFlowState.invoiceFailed,
        data: {'error': result.error},
      );
    }
    
    return result;
  }
  
  /// Imprime nota fiscal
  Future<SaleFlowResult> printInvoice(String notaFiscalId) async {
    final context = SaleFlowContext(
      paymentService: _paymentService,
      vendaService: _vendaService,
      printService: _printService,
    );
    
    final command = PrintInvoiceCommand(notaFiscalId);
    final result = await command.execute(context);
    
    if (result.success) {
      await _stateMachine.transitionTo(
        SaleFlowState.completed,
        data: result.data,
      );
    } else {
      await _stateMachine.transitionTo(
        SaleFlowState.printFailed,
        data: {'error': result.error},
      );
    }
    
    return result;
  }
  
  /// Stream de estados para UI reagir
  Stream<SaleFlowState> get stateStream => _stateMachine.stateStream;
}
```

### **4. SaleFlowProvider (ChangeNotifier)**

Provider para a UI consumir.

```dart
class SaleFlowProvider extends ChangeNotifier {
  final SaleFlowService _flowService;
  SaleFlowState _currentState = SaleFlowState.idle;
  String? _errorMessage;
  Map<String, dynamic>? _currentData;
  bool _isProcessing = false;
  
  SaleFlowProvider(this._flowService) {
    // Escuta mudanças de estado
    _flowService.stateStream.listen((state) {
      _currentState = state;
      _isProcessing = _isProcessingStates.contains(state);
      notifyListeners();
    });
  }
  
  SaleFlowState get currentState => _currentState;
  String? get errorMessage => _errorMessage;
  bool get isProcessing => _isProcessing;
  Map<String, dynamic>? get currentData => _currentData;
  
  bool get canProcessPayment => _currentState == SaleFlowState.idle || 
                                _currentState == SaleFlowState.paymentMethodSelected;
  
  bool get canConcludeSale => _currentState == SaleFlowState.paymentProcessed;
  
  bool get canRetry => _currentState == SaleFlowState.paymentFailed ||
                      _currentState == SaleFlowState.invoiceFailed ||
                      _currentState == SaleFlowState.printFailed;
  
  /// Processa pagamento
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
  
  /// Conclui venda
  Future<bool> concludeSale({
    required String vendaId,
    String? clienteCPF,
  }) async {
    _errorMessage = null;
    notifyListeners();
    
    final result = await _flowService.concludeSale(
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
  
  /// Retry da última operação
  Future<bool> retry() async {
    switch (_currentState) {
      case SaleFlowState.paymentFailed:
        // Retry do último pagamento
        if (_currentData?['lastPaymentRequest'] != null) {
          final request = PaymentRequest.fromJson(_currentData!['lastPaymentRequest']);
          return await processPayment(request);
        }
        break;
      case SaleFlowState.invoiceFailed:
        // Retry da conclusão
        if (_currentData?['vendaId'] != null) {
          return await concludeSale(
            vendaId: _currentData!['vendaId'],
            clienteCPF: _currentData?['clienteCPF'],
          );
        }
        break;
      case SaleFlowState.printFailed:
        // Retry da impressão
        if (_currentData?['notaFiscalId'] != null) {
          return await _flowService.printInvoice(_currentData!['notaFiscalId']);
        }
        break;
      default:
        return false;
    }
    return false;
  }
  
  /// Cancela fluxo
  void cancel() {
    _flowService.cancel();
    _currentState = SaleFlowState.cancelled;
    notifyListeners();
  }
  
  static const _isProcessingStates = {
    SaleFlowState.processingPayment,
    SaleFlowState.concludingSale,
    SaleFlowState.creatingInvoice,
    SaleFlowState.sendingToSefaz,
    SaleFlowState.printingInvoice,
  };
}
```

### **5. UI Simplificada**

A tela de pagamento fica muito mais simples:

```dart
class PagamentoRestauranteScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SaleFlowProvider>(
      builder: (context, flowProvider, child) {
        // Reage aos estados
        switch (flowProvider.currentState) {
          case SaleFlowState.idle:
            return _buildPaymentForm(context, flowProvider);
          
          case SaleFlowState.processingPayment:
            return _buildLoading('Processando pagamento...');
          
          case SaleFlowState.paymentProcessed:
            if (flowProvider.currentData?['saldoZerou'] == true) {
              return _buildConcludeSaleDialog(context, flowProvider);
            }
            return _buildPaymentForm(context, flowProvider);
          
          case SaleFlowState.paymentFailed:
            return _buildError(
              context,
              flowProvider.errorMessage ?? 'Erro ao processar pagamento',
              onRetry: () => flowProvider.retry(),
            );
          
          case SaleFlowState.concludingSale:
            return _buildLoading('Concluindo venda...');
          
          case SaleFlowState.invoiceAuthorized:
            return _buildLoading('Nota autorizada. Imprimindo...');
          
          case SaleFlowState.completed:
            return _buildSuccess(context);
          
          default:
            return _buildPaymentForm(context, flowProvider);
        }
      },
    );
  }
  
  Widget _buildPaymentForm(BuildContext context, SaleFlowProvider provider) {
    return Column(
      children: [
        // Formulário de pagamento
        PaymentMethodSelector(...),
        PaymentAmountInput(...),
        
        ElevatedButton(
          onPressed: provider.canProcessPayment && !provider.isProcessing
            ? () => _handlePayment(context, provider)
            : null,
          child: Text('Processar Pagamento'),
        ),
      ],
    );
  }
  
  Future<void> _handlePayment(BuildContext context, SaleFlowProvider provider) async {
    final request = PaymentRequest(
      vendaId: widget.venda.id,
      providerKey: _selectedMethod.providerKey,
      amount: _valorDigitado,
      // ... outros campos
    );
    
    final success = await provider.processPayment(request);
    
    if (!success && provider.errorMessage != null) {
      AppToast.showError(context, provider.errorMessage!);
    }
  }
}
```

---

## ✅ Vantagens da Nova Arquitetura

### **1. Separação de Responsabilidades**
- UI apenas renderiza e reage a estados
- Lógica de negócio isolada em serviços
- Comandos encapsulam ações

### **2. Testabilidade**
- Cada componente pode ser testado isoladamente
- Comandos são fáceis de testar
- State machine pode ser testada independentemente

### **3. Rastreabilidade**
- Estados explícitos facilitam debug
- Eventos estruturados permitem rastreamento
- Logs podem ser gerados automaticamente

### **4. Manutenibilidade**
- Código organizado e fácil de entender
- Mudanças isoladas em componentes específicos
- Fácil adicionar novos comandos/estados

### **5. Experiência do Usuário**
- Feedback claro em cada etapa
- Estados de loading consistentes
- Tratamento de erros padronizado
- Retry automático quando possível

### **6. Extensibilidade**
- Fácil adicionar novos métodos de pagamento
- Fácil adicionar novos estados
- Fácil adicionar novos comandos

---

## 🚀 Plano de Implementação

### **Fase 1: Fundação (1-2 dias)**
1. Criar `SaleFlowStateMachine`
2. Criar modelos (`SaleState`, `PaymentRequest`, `SaleResult`)
3. Criar eventos do fluxo

### **Fase 2: Comandos (2-3 dias)**
1. Implementar `ProcessPaymentCommand`
2. Implementar `ConcludeSaleCommand`
3. Implementar `PrintInvoiceCommand`

### **Fase 3: Serviço (1-2 dias)**
1. Implementar `SaleFlowService`
2. Integrar com serviços existentes
3. Testes unitários

### **Fase 4: Provider (1 dia)**
1. Implementar `SaleFlowProvider`
2. Integrar com UI

### **Fase 5: Migração UI (2-3 dias)**
1. Refatorar `PagamentoRestauranteScreen`
2. Remover lógica de negócio da UI
3. Testes de integração

### **Fase 6: Melhorias (1-2 dias)**
1. Adicionar retry automático
2. Melhorar feedback ao usuário
3. Adicionar logs estruturados

**Total estimado: 8-13 dias**

---

## 📝 Próximos Passos

1. **Revisar proposta** com a equipe
2. **Aprovar arquitetura** ou sugerir ajustes
3. **Criar issues** no GitHub para cada fase
4. **Começar implementação** pela Fase 1

---

## ❓ Perguntas para Discussão

1. A máquina de estados proposta atende todos os casos de uso?
2. Os comandos estão no nível certo de granularidade?
3. Como queremos tratar retry automático?
4. Precisamos de persistência de estado (salvar estado em caso de crash)?
5. Como integrar com o sistema de eventos existente (`AppEventBus`)?

