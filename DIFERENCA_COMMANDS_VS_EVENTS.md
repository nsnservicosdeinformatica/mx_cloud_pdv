# 🔄 Diferença entre Commands e Events

## 📋 Resumo Executivo

**Commands** e **Events** são conceitos diferentes que se complementam:

- **Command (Comando)**: "**Faça isso**" - Ação a ser executada (imperativo, futuro)
- **Event (Evento)**: "**Isso aconteceu**" - Notificação de algo que já ocorreu (declarativo, passado)

---

## 🎯 Commands (Comandos) - Padrão Command Pattern

### **O que são:**
Commands encapsulam **ações a serem executadas**. Eles representam uma **intenção** de fazer algo.

### **Características:**
- ✅ **Síncronos** - Executam e retornam resultado imediatamente
- ✅ **Encapsulam lógica** - Contêm toda a lógica de execução
- ✅ **Podem ser desfeitos** - Suportam undo/redo (opcional)
- ✅ **Podem ser enfileirados** - Podem ser salvos e executados depois
- ✅ **Retornam resultado** - Informam sucesso/falha

### **Exemplo no nosso sistema:**

```dart
// Command: "Processe este pagamento"
class ProcessPaymentCommand {
  final PaymentRequest request;
  
  Future<SaleFlowResult> execute() async {
    // 1. Valida request
    // 2. Processa via provider (SDK)
    // 3. Registra no servidor
    // 4. Retorna resultado
    return result;
  }
}

// Uso:
final command = ProcessPaymentCommand(request);
final result = await command.execute(); // ✅ Executa e retorna resultado
```

### **Quando usar Commands:**
- Quando você quer **executar uma ação** e obter resultado
- Quando precisa **encapsular lógica complexa**
- Quando quer **testar ações isoladamente**
- Quando precisa **desfazer ações** (undo)

---

## 📢 Events (Eventos) - Padrão Event-Driven

### **O que são:**
Events notificam que **algo aconteceu**. Eles representam um **fato** que já ocorreu.

### **Características:**
- ✅ **Assíncronos** - Disparados e esquecidos (fire-and-forget)
- ✅ **Notificam mudanças** - Informam outros componentes
- ✅ **Não retornam valor** - Apenas notificam
- ✅ **Não podem ser desfeitos** - Representam fatos consumados
- ✅ **Múltiplos listeners** - Vários componentes podem escutar

### **Exemplo no nosso sistema (já existe):**

```dart
// Event: "Pagamento foi processado"
AppEventBus.instance.dispararPagamentoProcessado(
  vendaId: vendaId,
  valor: valor,
  mesaId: mesaId,
);

// Outros componentes escutam:
AppEventBus.instance.on(TipoEvento.pagamentoProcessado).listen((evento) {
  // Reage ao evento
  atualizarUI();
});
```

### **Quando usar Events:**
- Quando você quer **notificar outros componentes** sobre mudanças
- Quando precisa **desacoplar componentes**
- Quando quer **reagir a mudanças** de forma assíncrona
- Quando precisa **sincronizar estado** entre múltiplos componentes

---

## 🔄 Como Eles Se Complementam

### **Fluxo Completo:**

```
1. UI chama Command
   ↓
2. Command executa ação
   ↓
3. Command retorna resultado
   ↓
4. Se sucesso → dispara Event
   ↓
5. Outros componentes reagem ao Event
```

### **Exemplo Prático:**

```dart
class SaleFlowService {
  /// 1. UI chama Command (via Service)
  Future<SaleFlowResult> processPayment(PaymentRequest request) async {
    // 2. Command executa ação
    final command = ProcessPaymentCommand(request);
    final result = await command.execute();
    
    // 3. Command retorna resultado
    if (result.success) {
      // 4. Se sucesso → dispara Event
      AppEventBus.instance.dispararPagamentoProcessado(
        vendaId: request.vendaId,
        valor: request.amount,
        mesaId: request.mesaId,
      );
    }
    
    return result; // Retorna para UI
  }
}
```

### **Outros componentes reagem ao Event:**

```dart
// VendaProvider escuta o evento
AppEventBus.instance.on(TipoEvento.pagamentoProcessado).listen((evento) {
  // Atualiza estado local sem precisar ir no servidor
  atualizarVendaLocal(evento.vendaId);
});

// MesaDetalhesProvider também escuta
AppEventBus.instance.on(TipoEvento.pagamentoProcessado).listen((evento) {
  // Atualiza UI da mesa
  atualizarMesa(evento.mesaId);
});
```

---

## 📊 Comparação Direta

| Aspecto | Command | Event |
|---------|---------|-------|
| **Tipo** | Ação a executar | Notificação de fato |
| **Tempo** | Futuro ("Faça") | Passado ("Aconteceu") |
| **Sincronização** | Síncrono | Assíncrono |
| **Retorno** | Retorna resultado | Não retorna |
| **Execução** | Executa lógica | Apenas notifica |
| **Desfazer** | Pode ter undo | Não pode desfazer |
| **Listeners** | Não tem | Múltiplos listeners |
| **Uso** | Encapsular ação | Desacoplar componentes |

---

## 🎨 Arquitetura Proposta: Commands + Events

### **Estrutura:**

```
┌─────────────┐
│     UI      │
└──────┬──────┘
       │ 1. Chama Command
       ↓
┌─────────────────────┐
│  SaleFlowService    │
│  (Orquestrador)      │
└──────┬──────────────┘
       │ 2. Executa Command
       ↓
┌─────────────────────┐
│  ProcessPaymentCmd   │ ← Command (executa ação)
│  - Valida            │
│  - Processa          │
│  - Registra          │
│  - Retorna resultado│
└──────┬──────────────┘
       │ 3. Retorna resultado
       ↓
┌─────────────────────┐
│  SaleFlowService     │
│  (continua)          │
└──────┬──────────────┘
       │ 4. Se sucesso → dispara Event
       ↓
┌─────────────────────┐
│   AppEventBus        │ ← Event (notifica)
│   - disparar...()    │
└──────┬──────────────┘
       │ 5. Event é propagado
       ↓
┌─────────────────────┐  ┌─────────────────────┐
│  VendaProvider      │  │ MesaDetalhesProvider│
│  (escuta evento)    │  │ (escuta evento)     │
└─────────────────────┘  └─────────────────────┘
```

---

## 💡 Exemplo Completo no Nosso Sistema

### **Cenário: Processar Pagamento**

#### **1. UI chama Command (via Service):**

```dart
// pagamento_restaurante_screen.dart
final result = await saleFlowProvider.processPayment(request);

if (result.success) {
  // UI reage ao resultado do Command
  mostrarSucesso();
} else {
  // UI reage ao erro do Command
  mostrarErro(result.error);
}
```

#### **2. Service executa Command:**

```dart
// sale_flow_service.dart
Future<SaleFlowResult> processPayment(PaymentRequest request) async {
  // Cria e executa Command
  final command = ProcessPaymentCommand(request);
  final result = await command.execute(context);
  
  // Command retornou resultado
  if (result.success) {
    // Dispara Event para notificar outros componentes
    AppEventBus.instance.dispararPagamentoProcessado(
      vendaId: request.vendaId,
      valor: request.amount,
      mesaId: request.mesaId,
    );
  }
  
  return result; // Retorna para UI
}
```

#### **3. Command executa ação:**

```dart
// process_payment_command.dart
class ProcessPaymentCommand extends SaleFlowCommand {
  @override
  Future<SaleFlowResult> execute(SaleFlowContext context) async {
    // 1. Valida
    await _validateRequest(request);
    
    // 2. Processa via provider
    final paymentResult = await context.paymentService.processPayment(...);
    
    // 3. Registra no servidor
    final registroResult = await context.vendaService.registrarPagamento(...);
    
    // 4. Retorna resultado
    return SaleFlowResult.success(...);
  }
}
```

#### **4. Outros componentes reagem ao Event:**

```dart
// venda_provider.dart
AppEventBus.instance.on(TipoEvento.pagamentoProcessado).listen((evento) {
  // Reage ao evento (não precisa ir no servidor)
  _atualizarVendaLocal(evento.vendaId);
  notifyListeners();
});

// mesa_detalhes_provider.dart
AppEventBus.instance.on(TipoEvento.pagamentoProcessado).listen((evento) {
  // Reage ao evento
  _atualizarMesa(evento.mesaId);
  notifyListeners();
});
```

---

## ✅ Vantagens de Usar Commands + Events

### **1. Separação de Responsabilidades**
- **Commands**: Executam ações
- **Events**: Notificam mudanças
- Cada um tem seu papel claro

### **2. Testabilidade**
- Commands podem ser testados isoladamente
- Events podem ser testados isoladamente
- Fácil mockar cada parte

### **3. Desacoplamento**
- UI não conhece detalhes de implementação
- Componentes se comunicam via Events
- Fácil adicionar novos listeners

### **4. Rastreabilidade**
- Commands podem ser logados antes de executar
- Events podem ser logados quando disparados
- Fácil debugar fluxo completo

### **5. Flexibilidade**
- Commands podem ser enfileirados
- Commands podem ser desfeitos (undo)
- Events podem ter múltiplos listeners

---

## 🔄 Resumo: Commands vs Events no Nosso Sistema

### **Commands (NOVO - Proposto):**
- `ProcessPaymentCommand` - Executa pagamento
- `ConcludeSaleCommand` - Conclui venda
- `PrintInvoiceCommand` - Imprime nota

**Uso:** Encapsular lógica de execução

### **Events (JÁ EXISTE):**
- `pagamentoProcessado` - Notifica que pagamento foi processado
- `vendaFinalizada` - Notifica que venda foi finalizada
- `pedidoCriado` - Notifica que pedido foi criado

**Uso:** Notificar outros componentes sobre mudanças

---

## ❓ Perguntas Frequentes

### **1. Por que não usar apenas Events?**

**Problema:** Events não retornam resultado. Se você precisa saber se uma ação foi bem-sucedida, precisa de um Command.

**Solução:** Use Command para executar e obter resultado, depois dispare Event para notificar outros componentes.

### **2. Por que não usar apenas Commands?**

**Problema:** Commands são síncronos. Se você precisa notificar múltiplos componentes de forma assíncrona, precisa de Events.

**Solução:** Use Command para executar ação, depois dispare Event para notificar outros componentes.

### **3. Quando usar cada um?**

- **Use Command quando:**
  - Precisa executar uma ação e obter resultado
  - Precisa encapsular lógica complexa
  - Precisa testar ação isoladamente

- **Use Event quando:**
  - Precisa notificar outros componentes
  - Precisa desacoplar componentes
  - Precisa reagir a mudanças de forma assíncrona

### **4. Eles se substituem?**

**Não!** Eles se complementam:
- Command executa ação e retorna resultado
- Event notifica que ação foi executada
- Use ambos no fluxo completo

---

## 🎯 Conclusão

**Commands** e **Events** são conceitos diferentes que se complementam:

- **Command**: "Faça isso" → Executa ação e retorna resultado
- **Event**: "Isso aconteceu" → Notifica outros componentes

No nosso sistema:
- **Commands** (novo) → Encapsulam lógica de execução
- **Events** (já existe) → Notificam mudanças

**Use ambos** para ter uma arquitetura robusta e desacoplada!

