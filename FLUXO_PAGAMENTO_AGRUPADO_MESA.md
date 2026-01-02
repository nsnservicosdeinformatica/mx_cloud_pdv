# Fluxo de Pagamento Agrupado na Mesa

## 🎯 Objetivo

Permitir pagamento agrupado quando o usuário está na **visão geral da mesa** (sem comanda específica selecionada), consolidando valores e produtos de todas as comandas + sem comanda.

---

## 📊 Situação Atual

### **Como Funciona Hoje**

**Quando `_abaSelecionada == null` (visão geral da mesa):**
- `getVendaParaAcao()` → Retorna `_vendaAtual` (venda da mesa, se houver)
- `getProdutosParaAcao()` → Retorna `_getTodosProdutosMesa()` (já consolida produtos de todas as comandas + sem comanda)

**Problema:**
- Sistema **bloqueia pagamento** quando está na visão geral (linha 687-693)
- Exige seleção de comanda específica para pagar

---

## 🔄 Novo Fluxo: Pagamento Agrupado

### **Conceito**

Quando `_abaSelecionada == null` (visão geral) E há múltiplas comandas:
1. **Consolidar valores** de todas as comandas + sem comanda
2. **Consolidar produtos** (já existe via `_getTodosProdutosMesa()`)
3. **Criar "venda virtual" consolidada** (apenas para exibição)
4. **Abrir tela de pagamento** com valores consolidados
5. **Processar pagamento** na primeira venda (base)
6. **Na finalização**, usar fluxo agrupado

---

## 💡 Implementação

### **ETAPA 1: Detectar Múltiplas Comandas**

```dart
// detalhes_produtos_mesa_screen.dart
bool _precisaAgruparVendas() {
  if (widget.entidade.tipo != TipoEntidade.mesa) return false;
  if (_provider.abaSelecionada != null) return false; // Comanda específica selecionada
  
  // Conta comandas com vendas abertas
  final comandasComVenda = _provider.comandasDaMesa
      .where((c) => _provider.vendasPorComanda[c.id] != null)
      .toList();
  
  // Verifica se há venda sem comanda também
  final temVendaSemComanda = _provider.vendaSemComanda != null;
  
  // Precisa agrupar se há mais de uma comanda OU (uma comanda + sem comanda)
  return comandasComVenda.length > 1 || 
         (comandasComVenda.length == 1 && temVendaSemComanda);
}

int _contarComandasComVenda() {
  final comandasComVenda = _provider.comandasDaMesa
      .where((c) => _provider.vendasPorComanda[c.id] != null)
      .length;
  final temVendaSemComanda = _provider.vendaSemComanda != null ? 1 : 0;
  return comandasComVenda + temVendaSemComanda;
}
```

---

### **ETAPA 2: Consolidar Valores de Todas as Comandas + Sem Comanda**

```dart
// detalhes_produtos_mesa_screen.dart
VendaDto _consolidarVendasParaPagamento() {
  final todasVendas = <VendaDto>[];
  
  // 1. Buscar vendas de todas as comandas
  for (final comanda in _provider.comandasDaMesa) {
    final venda = _provider.vendasPorComanda[comanda.id];
    if (venda != null) {
      todasVendas.add(venda);
    }
  }
  
  // 2. Buscar venda sem comanda (se houver)
  final vendaSemComanda = _provider.vendaSemComanda;
  if (vendaSemComanda != null) {
    todasVendas.add(vendaSemComanda);
  }
  
  if (todasVendas.isEmpty) {
    throw StateError('Nenhuma venda encontrada para consolidar');
  }
  
  // 3. Consolidar valores (soma de todas)
  final valorTotal = todasVendas.fold<double>(
    0.0, 
    (sum, v) => sum + (v.valorTotal ?? 0.0)
  );
  
  final totalPago = todasVendas.fold<double>(
    0.0, 
    (sum, v) => sum + (v.totalPago ?? 0.0)
  );
  
  final saldoRestante = valorTotal - totalPago;
  
  final subtotal = todasVendas.fold<double>(
    0.0, 
    (sum, v) => sum + (v.subtotal ?? 0.0)
  );
  
  final descontoTotal = todasVendas.fold<double>(
    0.0, 
    (sum, v) => sum + (v.descontoTotal ?? 0.0)
  );
  
  final acrescimoTotal = todasVendas.fold<double>(
    0.0, 
    (sum, v) => sum + (v.acrescimoTotal ?? 0.0)
  );
  
  final impostosTotal = todasVendas.fold<double>(
    0.0, 
    (sum, v) => sum + (v.impostosTotal ?? 0.0)
  );
  
  final freteTotal = todasVendas.fold<double>(
    0.0, 
    (sum, v) => sum + (v.freteTotal ?? 0.0)
  );
  
  // 4. Criar "venda virtual" consolidada (apenas para exibição)
  // Usa a primeira venda como base para campos que não são somas
  final vendaBase = todasVendas.first;
  
  return VendaDto(
    id: 'virtual-${DateTime.now().millisecondsSinceEpoch}', // ID virtual
    empresaId: vendaBase.empresaId,
    mesaId: widget.entidade.id, // ID da mesa
    mesaNome: widget.entidade.numero,
    comandaId: null, // Agrupada não tem comanda específica
    clienteNome: vendaBase.clienteNome ?? 'Consumidor Final',
    clienteId: vendaBase.clienteId,
    status: 1, // StatusVenda.Aberta
    dataCriacao: vendaBase.dataCriacao,
    valorTotal: valorTotal,
    totalPago: totalPago,
    saldoRestante: saldoRestante,
    subtotal: subtotal,
    descontoTotal: descontoTotal,
    acrescimoTotal: acrescimoTotal,
    impostosTotal: impostosTotal,
    freteTotal: freteTotal,
    pagamentos: [], // Pagamentos consolidados (opcional, para exibição)
    // ... outros campos necessários
  );
}
```

---

### **ETAPA 3: Consolidar Produtos (Já Existe!)**

**Boa notícia:** O `MesaDetalhesProvider` já tem o método `_getTodosProdutosMesa()` que consolida produtos de todas as comandas + sem comanda!

```dart
// MesaDetalhesProvider já faz isso:
List<ProdutoAgrupado> getProdutosParaAcao() {
  // Se aba selecionada é null, retorna TODOS os produtos (venda integral)
  if (_abaSelecionada == null) {
    return _getTodosProdutosMesa(); // ✅ Já consolida tudo!
  }
  // ...
}
```

**Então:** Podemos usar `_getProdutosParaAcao()` diretamente quando `_abaSelecionada == null`!

---

### **ETAPA 4: Abrir Tela de Pagamento com Valores Consolidados**

```dart
// detalhes_produtos_mesa_screen.dart
Future<void> _abrirTelaPagamento() async {
  // Se está na visão geral E há múltiplas comandas
  if (_provider.abaSelecionada == null && _precisaAgruparVendas()) {
    // Consolidar valores
    final vendaConsolidada = _consolidarVendasParaPagamento();
    
    // Produtos já estão consolidados (via getProdutosParaAcao)
    final produtosConsolidados = _getProdutosParaAcao();
    
    if (produtosConsolidados.isEmpty) {
      AppToast.showError(context, 'Nenhum produto disponível para pagamento');
      return;
    }
    
    // Buscar todas as vendas originais (para processar pagamento na base)
    final vendasOriginais = _buscarTodasVendasAbertas();
    
    // Abrir tela de pagamento com valores consolidados
    final result = await PagamentoRestauranteScreen.show(
      context,
      venda: vendaConsolidada, // Venda virtual consolidada
      produtosAgrupados: produtosConsolidados, // Produtos consolidados
      isPagamentoAgrupado: true, // 🆕 Flag indicando pagamento agrupado
      vendasOriginais: vendasOriginais, // 🆕 Lista de vendas originais
    );
    
    return;
  }
  
  // Fluxo normal (comanda específica ou apenas uma comanda)
  var venda = _getVendaParaAcao();
  final produtos = _getProdutosParaAcao();
  
  if (venda == null) {
    debugPrint('⚠️ Venda não encontrada localmente, buscando venda aberta diretamente...');
    venda = await _buscarVendaAberta();
  }
  
  if (venda == null) {
    AppToast.showError(context, 'Nenhuma venda encontrada');
    return;
  }
  
  if (produtos.isEmpty) {
    AppToast.showError(context, 'Nenhum produto disponível para pagamento');
    return;
  }
  
  // 🆕 Remover validação que bloqueia pagamento na visão geral
  // (agora permitimos se há múltiplas comandas)
  
  final result = await PagamentoRestauranteScreen.show(
    context,
    venda: venda,
    produtosAgrupados: produtos,
    onPagamentoProcessado: () {},
    onVendaConcluida: () {},
  );
}

List<VendaDto> _buscarTodasVendasAbertas() {
  final vendas = <VendaDto>[];
  
  // Buscar vendas de todas as comandas
  for (final comanda in _provider.comandasDaMesa) {
    final venda = _provider.vendasPorComanda[comanda.id];
    if (venda != null) {
      vendas.add(venda);
    }
  }
  
  // Buscar venda sem comanda (se houver)
  final vendaSemComanda = _provider.vendaSemComanda;
  if (vendaSemComanda != null) {
    vendas.add(vendaSemComanda);
  }
  
  return vendas;
}
```

---

### **ETAPA 5: Processar Pagamento Agrupado**

**PagamentoRestauranteScreen precisa ser ajustado:**

```dart
// pagamento_restaurante_screen.dart
class PagamentoRestauranteScreen extends StatefulWidget {
  final VendaDto venda;
  final List<ProdutoAgrupado> produtosAgrupados;
  final bool isPagamentoAgrupado; // 🆕 Flag
  final List<VendaDto>? vendasOriginais; // 🆕 Lista de vendas originais
  
  // ...
}

// No processamento do pagamento:
Future<void> _processarPagamento() async {
  // ... validações ...
  
  if (widget.isPagamentoAgrupado && widget.vendasOriginais != null && widget.vendasOriginais!.isNotEmpty) {
    // 🆕 Pagamento agrupado: processar na primeira venda (base)
    final vendaBase = widget.vendasOriginais!.first;
    
    debugPrint('💳 [PagamentoRestauranteScreen] Processando pagamento agrupado na venda base: ${vendaBase.id}');
    
    await paymentFlowProvider.processPayment(
      providerKey: providerKey,
      amount: valor,
      vendaId: vendaBase.id, // Processa na venda base
      additionalData: additionalData,
    );
  } else {
    // Fluxo normal (comanda específica)
    await paymentFlowProvider.processPayment(
      providerKey: providerKey,
      amount: valor,
      vendaId: widget.venda.id,
      additionalData: additionalData,
    );
  }
  
  // ... resto do fluxo
}
```

---

### **ETAPA 6: Finalização Agrupada**

**Quando:** Usuário clica em "Concluir Venda" e há múltiplas comandas

```dart
// detalhes_produtos_mesa_screen.dart
Future<void> _finalizarVenda() async {
  // Se está na visão geral E há múltiplas comandas
  if (_provider.abaSelecionada == null && _precisaAgruparVendas()) {
    // Mostrar confirmação
    final confirmar = await AppDialog.showConfirm(
      context: context,
      title: 'Finalizar Todas as Comandas',
      message: 'Esta mesa possui ${_contarComandasComVenda()} comandas abertas.\n\n'
               'Deseja finalizar todas as comandas de uma vez?\n\n'
               'Será criada uma única nota fiscal para todas as comandas.',
      confirmText: 'Finalizar Todas',
      cancelText: 'Cancelar',
    );
    
    if (confirmar != true) return;
    
    // Finalizar todas as vendas com nota fiscal única
    await _finalizarVendasAgrupadas();
    return;
  }
  
  // Fluxo normal (comanda específica)
  var venda = _getVendaParaAcao();
  final produtos = _getProdutosParaAcao();
  
  // ... resto do fluxo normal
}

Future<void> _finalizarVendasAgrupadas() async {
  final vendasAbertas = _buscarTodasVendasAbertas();
  
  if (vendasAbertas.isEmpty) {
    AppToast.showError(context, 'Nenhuma venda encontrada');
    return;
  }
  
  LoadingHelper.show(context);
  
  try {
    // Chamar endpoint de finalização agrupada
    final response = await _servicesProvider.vendaService
        .finalizarVendasAgrupadasComNotaUnica(
      vendaIds: vendasAbertas.map((v) => v.id).toList(),
    );
    
    if (response.success) {
      AppToast.showSuccess(
        context, 
        '${response.vendasFinalizadas} vendas finalizadas com sucesso!'
      );
      
      // Recarregar dados
      await _provider.loadVendaAtual();
      await _provider.loadProdutos(refresh: true);
      
      // Voltar para tela anterior
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    } else {
      AppToast.showError(context, response.message ?? 'Erro ao finalizar vendas');
    }
  } catch (e) {
    AppToast.showError(context, 'Erro ao finalizar vendas: $e');
  } finally {
    LoadingHelper.hide(context);
  }
}
```

---

## 📊 Resumo do Fluxo Completo

### **Pagamento Agrupado (Visão Geral da Mesa)**

```
1. Usuário está na visão geral da mesa (abaSelecionada == null)
   ↓
2. Sistema detecta múltiplas comandas
   ↓
3. Usuário clica "Pagar"
   ↓
4. Sistema consolida:
   ├── Valores: soma de todas as comandas + sem comanda
   │   ├── Venda Comanda A: R$ 100
   │   ├── Venda Comanda B: R$ 200
   │   └── Venda Sem Comanda: R$ 50
   │   └── Total Consolidado: R$ 350
   ├── Produtos: já consolidados via _getTodosProdutosMesa()
   └── Cria "venda virtual" consolidada (apenas para exibição)
   ↓
5. Abre tela de pagamento com valores consolidados
   ├── Valor Total: R$ 350
   ├── Total Pago: R$ 0 (ou soma dos pagamentos de reserva)
   └── Saldo Restante: R$ 350
   ↓
6. Usuário paga (valor único, ex: R$ 350)
   ↓
7. Sistema processa pagamento na primeira venda (base)
   ├── Venda Comanda A recebe pagamento de R$ 350
   └── Pagamento registrado normalmente
   ↓
8. Saldo da venda base zera (ou fica negativo, se pagou mais)
   ↓
9. Usuário pode fazer mais pagamentos ou finalizar
```

### **Finalização Agrupada**

```
1. Usuário está na visão geral da mesa (abaSelecionada == null)
   ↓
2. Sistema detecta múltiplas comandas
   ↓
3. Usuário clica "Finalizar Venda"
   ↓
4. Sistema mostra confirmação: "Finalizar todas as comandas?"
   ↓
5. Usuário confirma
   ↓
6. Backend:
   ├── Consolida produtos de todas as vendas
   ├── Consolida pagamentos de reserva
   ├── Cria pagamento final (se houver saldo) na primeira venda
   ├── Cria nota fiscal única
   ├── Vincula todos os pagamentos (reserva + final) à nota
   ├── Finaliza todas as vendas
   └── Libera mesa e comandas
```

---

## ✅ Checklist de Implementação

### **Frontend**

- [ ] Implementar `_precisaAgruparVendas()` em `DetalhesProdutosMesaScreen`
- [ ] Implementar `_contarComandasComVenda()`
- [ ] Implementar `_consolidarVendasParaPagamento()`
- [ ] Implementar `_buscarTodasVendasAbertas()`
- [ ] Ajustar `_abrirTelaPagamento()` para detectar e consolidar
- [ ] Remover validação que bloqueia pagamento na visão geral (quando há múltiplas comandas)
- [ ] Ajustar `PagamentoRestauranteScreen` para receber `isPagamentoAgrupado` e `vendasOriginais`
- [ ] Ajustar `_processarPagamento()` para processar na venda base quando agrupado
- [ ] Ajustar `_finalizarVenda()` para detectar múltiplas comandas
- [ ] Implementar `_finalizarVendasAgrupadas()`

### **Backend**

- [ ] Implementar `FinalizarVendasAgrupadasComNotaUnicaAsync()`
- [ ] Criar endpoint `POST /api/vendas/finalizar-agrupadas`
- [ ] Criar DTOs necessários (`FinalizarVendasAgrupadasDto`, `FinalizarVendasAgrupadasResultDto`)

---

## 🎯 Pontos Importantes

1. **Venda Virtual:** Apenas para exibição na tela de pagamento. Não é salva no banco.
2. **Produtos:** Já consolidados via `_getTodosProdutosMesa()` quando `abaSelecionada == null`
3. **Valores:** Soma de todas as comandas + sem comanda
4. **Pagamento:** Processado na primeira venda (base) quando agrupado
5. **Finalização:** Usa endpoint específico que consolida tudo e cria nota única
