# 🔍 Análise Completa: Fluxo de Pagamento com State Machine

## 📋 Resumo Executivo

Esta análise identifica **problemas críticos** no fluxo de pagamento e propõe soluções detalhadas para:
1. ✅ Feedback visual durante registro de pagamento no servidor
2. ✅ Tela completa de status durante conclusão de venda
3. ✅ Retentativas automáticas de emissão de nota fiscal
4. ✅ Status detalhado da nota fiscal (aprovada/rejeitada)

---

## 🔴 PROBLEMA 1: Falta de Feedback Durante Registro de Pagamento

### **Situação Atual:**

```dart
// pagamento_restaurante_screen.dart:300-430
final success = await paymentFlowProvider.processPayment(...);

// ❌ PROBLEMA: Entre processPayment() e registrarPagamento() não há estado de loading
// O provider transiciona para paymentProcessed, mas o registro no servidor
// acontece DEPOIS, sem feedback visual

if (result.success) {
  // ❌ AQUI: Registro no servidor acontece SEM estado de loading
  final response = await _vendaService.registrarPagamento(...);
  
  if (response.success) {
    // Só aqui mostra sucesso
  }
}
```

### **O que está acontecendo:**

1. ✅ `processPayment()` → Transiciona para `processingPayment` → Mostra loading
2. ✅ SDK processa → Transiciona para `paymentProcessed` → Esconde loading
3. ❌ **Registro no servidor** → **SEM estado de loading** → Usuário não sabe que está registrando
4. ✅ Sucesso → Mostra toast

### **Impacto:**
- ❌ Usuário não sabe que o pagamento está sendo registrado no servidor
- ❌ Se o registro falhar, parece que o pagamento foi processado mas não foi
- ❌ Experiência confusa: "Por que demora tanto depois do cartão ser aprovado?"

---

## 🔴 PROBLEMA 2: Tela de Conclusão Muito Simples

### **Situação Atual:**

```dart
// pagamento_restaurante_screen.dart:1307-1314
_buildActionButton(
  onPressed: _concluirVenda,
  text: _getButtonTextForState(paymentFlowProvider.currentState),
  // ❌ PROBLEMA: Só mostra texto no botão, não uma tela completa
  // ❌ Não mostra status da nota fiscal
  // ❌ Não mostra se foi aprovada ou rejeitada
  // ❌ Não mostra progresso detalhado
)
```

### **O que está faltando:**

1. ❌ **Tela de status completa** durante conclusão
2. ❌ **Status da nota fiscal** (aprovada/rejeitada/processando)
3. ❌ **Progresso visual** de cada etapa:
   - Concluindo venda...
   - Criando nota fiscal...
   - Enviando para SEFAZ...
   - Nota autorizada ✅ / Rejeitada ❌
   - Imprimindo nota...
4. ❌ **Informações da nota** (chave de acesso, protocolo, etc.)

### **Impacto:**
- ❌ Usuário não sabe o que está acontecendo durante conclusão
- ❌ Não sabe se a nota foi aprovada ou rejeitada
- ❌ Não tem informações da nota fiscal para consulta

---

## 🔴 PROBLEMA 3: Falta de Retentativas de Emissão de Nota

### **Situação Atual:**

```dart
// payment_flow_provider.dart:301-387
Future<bool> concludeSale(...) async {
  // ...
  if (vendaFinalizada.notaFiscal != null && vendaFinalizada.notaFiscal!.foiAutorizada) {
    // ✅ Nota autorizada
  } else {
    // ❌ PROBLEMA: Se nota falhar, não há retentativa automática
    // ❌ Não verifica se nota foi rejeitada
    // ❌ Não tenta reenviar
  }
}
```

### **O que está faltando:**

1. ❌ **Retentativa automática** se nota for rejeitada
2. ❌ **Verificação de status** da nota após envio
3. ❌ **Polling** para verificar se nota foi autorizada
4. ❌ **UI para retentativa manual** se automática falhar

### **Impacto:**
- ❌ Se nota for rejeitada, usuário precisa concluir venda novamente
- ❌ Não há feedback sobre por que a nota foi rejeitada
- ❌ Experiência ruim: "Por que a nota não foi emitida?"

---

## 🔴 PROBLEMA 4: Falta de Status Detalhado da Nota Fiscal

### **Situação Atual:**

```dart
// payment_flow_provider.dart:345-366
if (vendaFinalizada.notaFiscal != null && vendaFinalizada.notaFiscal!.foiAutorizada) {
  // ✅ Só verifica se foi autorizada
  // ❌ PROBLEMA: Não mostra:
  // - Status detalhado (autorizada/rejeitada/processando)
  // - Chave de acesso
  // - Protocolo de autorização
  // - Motivo de rejeição (se houver)
  // - Data/hora de autorização
}
```

### **O que está faltando:**

1. ❌ **Status detalhado** da nota (não só "foi autorizada")
2. ❌ **Informações da nota** (chave, protocolo, etc.)
3. ❌ **Motivo de rejeição** (se houver)
4. ❌ **Histórico de tentativas** de emissão

---

## 🎯 SOLUÇÕES PROPOSTAS

### **SOLUÇÃO 1: Adicionar Estado de Registro de Pagamento**

#### **1.1. Novo Estado na State Machine:**

```dart
// payment_flow_state.dart
enum PaymentFlowState {
  // ... estados existentes ...
  
  /// 🆕 Registrando pagamento no servidor (após processar via SDK)
  registeringPayment,
}
```

#### **1.2. Atualizar Transições:**

```dart
// payment_flow_state_machine.dart
case PaymentFlowState.paymentProcessed:
  return to == PaymentFlowState.registeringPayment || // 🆕 Novo estado
         to == PaymentFlowState.readyToComplete ||
         to == PaymentFlowState.idle;
         
case PaymentFlowState.registeringPayment:
  return to == PaymentFlowState.readyToComplete ||
         to == PaymentFlowState.idle ||
         to == PaymentFlowState.paymentFailed; // Se registro falhar
```

#### **1.3. Atualizar Provider:**

```dart
// payment_flow_provider.dart
Future<bool> processPayment(...) async {
  // ... código existente ...
  
  if (result.success) {
    // Transiciona para paymentProcessed
    _stateMachine.transitionTo(PaymentFlowState.paymentProcessed);
    notifyListeners();
    
    // 🆕 NOVO: Transiciona para registeringPayment
    _stateMachine.transitionTo(PaymentFlowState.registeringPayment);
    notifyListeners(); // UI mostra "Registrando pagamento..."
    
    // 🆕 NOVO: Registra no servidor (isso deve ser movido para o provider)
    // Por enquanto, a UI ainda faz isso, mas deveria ser no provider
    // TODO: Mover registrarPagamento para dentro do provider
    
    // Após registro bem-sucedido:
    if (saldoZerou) {
      _stateMachine.transitionTo(PaymentFlowState.readyToComplete);
    } else {
      _stateMachine.transitionTo(PaymentFlowState.idle);
    }
  }
}
```

#### **1.4. Atualizar UI:**

```dart
// pagamento_restaurante_screen.dart
String _getButtonTextForState(PaymentFlowState state) {
  switch (state) {
    case PaymentFlowState.registeringPayment: // 🆕 NOVO
      return 'Registrando Pagamento...';
    // ... outros estados ...
  }
}

Widget _buildEstadoAtual(...) {
  switch (state) {
    case PaymentFlowState.registeringPayment: // 🆕 NOVO
      return _buildStatusCard(
        icon: Icons.cloud_upload,
        message: 'Registrando pagamento no servidor...',
        color: AppTheme.primaryColor,
      );
    // ... outros estados ...
  }
}
```

---

### **SOLUÇÃO 2: Tela Completa de Status Durante Conclusão**

#### **2.1. Novo Widget: `ConclusaoVendaStatusScreen`**

```dart
// screens/pagamento/conclusao_venda_status_screen.dart
class ConclusaoVendaStatusScreen extends StatelessWidget {
  final PaymentFlowProvider provider;
  
  @override
  Widget build(BuildContext context) {
    return Consumer<PaymentFlowProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),
                
                // Status atual
                _buildStatusAtual(provider),
                
                // Progresso das etapas
                _buildProgressoEtapas(provider),
                
                // Informações da nota (se disponível)
                if (provider.notaFiscalData != null)
                  _buildInfoNotaFiscal(provider.notaFiscalData!),
                
                // Botões de ação
                _buildBotoesAcao(provider),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatusAtual(PaymentFlowProvider provider) {
    final state = provider.currentState;
    
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          // Ícone animado baseado no estado
          _buildIconeAnimado(state),
          
          SizedBox(height: 16),
          
          // Mensagem principal
          Text(
            provider.userMessage,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          
          SizedBox(height: 8),
          
          // Mensagem secundária
          Text(
            _getMensagemSecundaria(state),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressoEtapas(PaymentFlowProvider provider) {
    final etapas = [
      _Etapa(
        titulo: 'Concluindo Venda',
        estado: _getEstadoEtapa(
          provider,
          PaymentFlowState.concludingSale,
          PaymentFlowState.saleCompleted,
        ),
      ),
      _Etapa(
        titulo: 'Criando Nota Fiscal',
        estado: _getEstadoEtapa(
          provider,
          PaymentFlowState.creatingInvoice,
          PaymentFlowState.sendingToSefaz,
        ),
      ),
      _Etapa(
        titulo: 'Enviando para SEFAZ',
        estado: _getEstadoEtapa(
          provider,
          PaymentFlowState.sendingToSefaz,
          PaymentFlowState.invoiceAuthorized,
        ),
      ),
      _Etapa(
        titulo: 'Nota Autorizada',
        estado: _getEstadoEtapa(
          provider,
          PaymentFlowState.invoiceAuthorized,
          PaymentFlowState.invoiceAuthorized,
        ),
      ),
      _Etapa(
        titulo: 'Imprimindo Nota',
        estado: _getEstadoEtapa(
          provider,
          PaymentFlowState.printingInvoice,
          PaymentFlowState.printSuccess,
        ),
      ),
    ];
    
    return Column(
      children: etapas.map((etapa) => _buildEtapaItem(etapa)).toList(),
    );
  }
  
  Widget _buildInfoNotaFiscal(Map<String, dynamic> notaData) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informações da Nota Fiscal',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12),
          _buildInfoItem('Chave de Acesso', notaData['chaveAcesso']),
          _buildInfoItem('Protocolo', notaData['protocolo']),
          _buildInfoItem('Status', notaData['status']),
          if (notaData['motivoRejeicao'] != null)
            _buildInfoItem('Motivo de Rejeição', notaData['motivoRejeicao'], isError: true),
        ],
      ),
    );
  }
}
```

#### **2.2. Atualizar Provider para Expor Dados da Nota:**

```dart
// payment_flow_provider.dart
Map<String, dynamic>? _notaFiscalData;

Map<String, dynamic>? get notaFiscalData => _notaFiscalData;

Future<bool> concludeSale(...) async {
  // ... código existente ...
  
  if (vendaFinalizada.notaFiscal != null) {
    // 🆕 NOVO: Guarda dados da nota fiscal
    _notaFiscalData = {
      'id': vendaFinalizada.notaFiscal!.id,
      'chaveAcesso': vendaFinalizada.notaFiscal!.chaveAcesso,
      'protocolo': vendaFinalizada.notaFiscal!.protocoloAutorizacao,
      'status': vendaFinalizada.notaFiscal!.foiAutorizada ? 'Autorizada' : 'Rejeitada',
      'foiAutorizada': vendaFinalizada.notaFiscal!.foiAutorizada,
      'motivoRejeicao': vendaFinalizada.notaFiscal!.motivoRejeicao,
      'dataAutorizacao': vendaFinalizada.notaFiscal!.dataAutorizacao,
    };
    notifyListeners();
  }
}
```

---

### **SOLUÇÃO 3: Retentativas Automáticas de Emissão**

#### **3.1. Novo Método no Provider:**

```dart
// payment_flow_provider.dart
int _tentativasEmissao = 0;
static const int MAX_TENTATIVAS_EMISSAO = 3;

/// 🆕 Emite nota fiscal com retentativas automáticas
Future<bool> emitInvoiceWithRetry({
  required String notaFiscalId,
  required Future<ApiResponse<VendaDto>> Function(String) getVendaCallback,
}) async {
  _tentativasEmissao = 0;
  
  while (_tentativasEmissao < MAX_TENTATIVAS_EMISSAO) {
    _tentativasEmissao++;
    
    debugPrint('📄 [PaymentFlowProvider] Tentativa $tentativasEmissao/$MAX_TENTATIVAS_EMISSAO de emissão');
    
    // Transiciona para creatingInvoice
    if (_tentativasEmissao == 1) {
      _stateMachine.transitionTo(PaymentFlowState.creatingInvoice);
    } else {
      // Retentativa: volta para creatingInvoice
      _stateMachine.transitionTo(PaymentFlowState.creatingInvoice);
    }
    notifyListeners();
    
    // Busca venda atualizada para verificar status da nota
    final vendaResponse = await getVendaCallback(notaFiscalId);
    
    if (!vendaResponse.success || vendaResponse.data == null) {
      if (_tentativasEmissao >= MAX_TENTATIVAS_EMISSAO) {
        _stateMachine.transitionTo(PaymentFlowState.invoiceFailed);
        _errorMessage = 'Erro ao buscar status da nota fiscal';
        notifyListeners();
        return false;
      }
      // Aguarda antes de retentar
      await Future.delayed(Duration(seconds: 2));
      continue;
    }
    
    final venda = vendaResponse.data!;
    final notaFiscal = venda.notaFiscal;
    
    if (notaFiscal == null) {
      // Nota ainda não foi criada, aguarda e retenta
      if (_tentativasEmissao >= MAX_TENTATIVAS_EMISSAO) {
        _stateMachine.transitionTo(PaymentFlowState.invoiceFailed);
        _errorMessage = 'Nota fiscal não foi criada após múltiplas tentativas';
        notifyListeners();
        return false;
      }
      await Future.delayed(Duration(seconds: 2));
      continue;
    }
    
    // Transiciona para sendingToSefaz
    _stateMachine.transitionTo(PaymentFlowState.sendingToSefaz);
    notifyListeners();
    
    // Verifica se foi autorizada
    if (notaFiscal.foiAutorizada) {
      // ✅ Sucesso!
      _stateMachine.transitionTo(PaymentFlowState.invoiceAuthorized);
      _notaFiscalData = {
        'id': notaFiscal.id,
        'chaveAcesso': notaFiscal.chaveAcesso,
        'protocolo': notaFiscal.protocoloAutorizacao,
        'status': 'Autorizada',
        'foiAutorizada': true,
        'dataAutorizacao': notaFiscal.dataAutorizacao,
      };
      notifyListeners();
      return true;
    } else {
      // ❌ Rejeitada
      if (_tentativasEmissao >= MAX_TENTATIVAS_EMISSAO) {
        _stateMachine.transitionTo(PaymentFlowState.invoiceFailed);
        _notaFiscalData = {
          'id': notaFiscal.id,
          'status': 'Rejeitada',
          'foiAutorizada': false,
          'motivoRejeicao': notaFiscal.motivoRejeicao ?? 'Motivo não informado',
        };
        _errorMessage = 'Nota fiscal rejeitada: ${notaFiscal.motivoRejeicao ?? "Motivo não informado"}';
        notifyListeners();
        return false;
      }
      
      // Aguarda antes de retentar
      await Future.delayed(Duration(seconds: 3));
      continue;
    }
  }
  
  return false;
}
```

#### **3.2. Atualizar `concludeSale` para Usar Retentativas:**

```dart
// payment_flow_provider.dart
Future<bool> concludeSale(...) async {
  // ... código existente até saleCompleted ...
  
  if (vendaFinalizada.notaFiscal != null) {
    // 🆕 NOVO: Usa método com retentativas
    final notaFiscalId = vendaFinalizada.notaFiscal!.id;
    
    final success = await emitInvoiceWithRetry(
      notaFiscalId: notaFiscalId,
      getVendaCallback: (id) => _vendaService.getVendaById(id),
    );
    
    if (success) {
      // Nota autorizada, pode imprimir
      return true;
    } else {
      // Falhou após retentativas
      return false;
    }
  }
}
```

---

### **SOLUÇÃO 4: Status Detalhado da Nota Fiscal**

#### **4.1. Modelo de Dados da Nota:**

```dart
// core/payment/nota_fiscal_status.dart
class NotaFiscalStatus {
  final String id;
  final String? chaveAcesso;
  final String? protocoloAutorizacao;
  final NotaFiscalStatusType status;
  final bool foiAutorizada;
  final String? motivoRejeicao;
  final DateTime? dataAutorizacao;
  final int tentativas;
  
  NotaFiscalStatus({
    required this.id,
    this.chaveAcesso,
    this.protocoloAutorizacao,
    required this.status,
    required this.foiAutorizada,
    this.motivoRejeicao,
    this.dataAutorizacao,
    this.tentativas = 0,
  });
}

enum NotaFiscalStatusType {
  criada,
  enviando,
  autorizada,
  rejeitada,
  cancelada,
  erro,
}
```

#### **4.2. Atualizar Provider:**

```dart
// payment_flow_provider.dart
NotaFiscalStatus? _notaFiscalStatus;

NotaFiscalStatus? get notaFiscalStatus => _notaFiscalStatus;

// Atualizar em todos os lugares onde nota fiscal é processada
void _atualizarStatusNota(VendaDto venda) {
  if (venda.notaFiscal != null) {
    final nota = venda.notaFiscal!;
    _notaFiscalStatus = NotaFiscalStatus(
      id: nota.id,
      chaveAcesso: nota.chaveAcesso,
      protocoloAutorizacao: nota.protocoloAutorizacao,
      status: nota.foiAutorizada 
        ? NotaFiscalStatusType.autorizada
        : NotaFiscalStatusType.rejeitada,
      foiAutorizada: nota.foiAutorizada,
      motivoRejeicao: nota.motivoRejeicao,
      dataAutorizacao: nota.dataAutorizacao,
      tentativas: _tentativasEmissao,
    );
    notifyListeners();
  }
}
```

---

## 📊 Resumo das Mudanças Necessárias

### **1. State Machine:**
- ✅ Adicionar estado `registeringPayment`
- ✅ Atualizar transições

### **2. Provider:**
- ✅ Adicionar método `emitInvoiceWithRetry()`
- ✅ Adicionar propriedade `notaFiscalStatus`
- ✅ Atualizar `concludeSale()` para usar retentativas
- ✅ Mover `registrarPagamento()` para dentro do provider

### **3. UI:**
- ✅ Criar `ConclusaoVendaStatusScreen`
- ✅ Atualizar `_getButtonTextForState()` para incluir novos estados
- ✅ Atualizar `_buildEstadoAtual()` para mostrar status de registro

### **4. Modelos:**
- ✅ Criar `NotaFiscalStatus` e `NotaFiscalStatusType`

---

## 🎯 Próximos Passos

1. **Implementar estado `registeringPayment`**
2. **Criar tela de status completa**
3. **Implementar retentativas automáticas**
4. **Adicionar modelo de status da nota**
5. **Testar fluxo completo**

---

## 📝 Observações Importantes

### **Sobre o Registro de Pagamento:**

Atualmente, o registro no servidor acontece **na UI** (linha 390 de `pagamento_restaurante_screen.dart`). Isso deveria ser movido para o **Provider** para:
- ✅ Centralizar lógica
- ✅ Gerenciar estados corretamente
- ✅ Facilitar testes

### **Sobre Retentativas:**

As retentativas devem ser **configuráveis**:
- Número máximo de tentativas
- Intervalo entre tentativas
- Critérios para considerar falha definitiva

### **Sobre a Tela de Status:**

A tela deve ser **modal** durante conclusão e **não bloqueante**:
- Usuário pode cancelar (se permitido)
- Mostra progresso em tempo real
- Permite ver detalhes da nota

---

**Documento criado para análise detalhada do fluxo! 🚀**

