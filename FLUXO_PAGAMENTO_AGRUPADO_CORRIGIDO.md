# Fluxo de Pagamento Agrupado - Corrigido

## 🎯 Correção

**Problema identificado:** Pagamento agrupado não deve ser processado apenas na primeira venda, mas sim **distribuído entre todas as vendas**.

---

## 💡 Abordagem Corrigida

### **Pagamento Agrupado**

Quando o usuário paga na visão geral da mesa (múltiplas comandas):

1. **Consolidar valores** de todas as comandas + sem comanda
2. **Usuário paga** (valor único, ex: R$ 350)
3. **Sistema distribui o pagamento** proporcionalmente entre todas as vendas
4. **Cada venda recebe sua parte** do pagamento

**Exemplo:**
```
Venda A: Saldo R$ 100 → Recebe pagamento de R$ 100
Venda B: Saldo R$ 200 → Recebe pagamento de R$ 200
Venda C: Saldo R$ 50 → Recebe pagamento de R$ 50
Total: R$ 350 (soma dos pagamentos)
```

---

## 🔄 Implementação

### **Backend - Novo método: ProcessarPagamentoAgrupadoAsync**

```csharp
public async Task<PagamentoAgrupadoResultDto> ProcessarPagamentoAgrupadoAsync(
    ProcessarPagamentoAgrupadoDto dto)
{
    // dto contém:
    // - Lista de VendaIds
    // - Valor total do pagamento
    // - Forma de pagamento
    // - Produtos selecionados (se emitir nota parcial)
    // - EmitirNotaFiscal (bool)
    
    await _unitOfWork.BeginTransactionAsync();
    
    try
    {
        // 1. Buscar todas as vendas
        var vendas = new List<Venda>();
        foreach (var vendaId in dto.VendaIds)
        {
            var venda = await _unitOfWork.VendaRepository.GetByIdComPagamentosAsync(vendaId);
            if (venda == null || venda.Status != StatusVenda.Aberta)
            {
                throw new InvalidOperationException($"Venda {vendaId} não encontrada ou não está aberta.");
            }
            vendas.Add(venda);
        }
        
        // 2. Validar que valor do pagamento não excede saldo total
        var saldoTotal = vendas.Sum(v => v.SaldoRestante);
        if (dto.Valor > saldoTotal)
        {
            throw new InvalidOperationException(
                $"Valor do pagamento (R$ {dto.Valor:F2}) excede o saldo total (R$ {saldoTotal:F2}).");
        }
        
        // 3. Distribuir pagamento proporcionalmente entre as vendas
        var distribuicao = DistribuirPagamentoProporcionalmente(vendas, dto.Valor);
        
        // 4. Processar pagamento em cada venda
        var pagamentosCriados = new List<PagamentoVenda>();
        
        foreach (var (venda, valorDistribuido) in distribuicao)
        {
            // Se emitir nota parcial, precisa determinar quais produtos de cada venda
            List<ProdutoNotaFiscalDto>? produtosVenda = null;
            
            if (dto.EmitirNotaFiscal && dto.Produtos != null && dto.Produtos.Any())
            {
                // Filtrar produtos que pertencem a esta venda
                produtosVenda = await FiltrarProdutosPorVendaAsync(venda.Id, dto.Produtos);
            }
            
            // Criar pagamento na venda
            var pagamentoDto = new CreatePagamentoVendaDto
            {
                Valor = valorDistribuido,
                FormaPagamento = dto.FormaPagamento,
                TipoFormaPagamento = dto.TipoFormaPagamento,
                NumeroParcelas = dto.NumeroParcelas,
                Produtos = produtosVenda, // Produtos desta venda específica
                ClienteCPF = dto.ClienteCPF,
                // ... outros campos
            };
            
            var vendaAtualizada = await AdicionarPagamentoAsync(venda.Id, pagamentoDto);
            pagamentosCriados.Add(vendaAtualizada.Pagamentos.Last()); // Último pagamento criado
        }
        
        await _unitOfWork.SaveChangesAsync();
        await _unitOfWork.CommitTransactionAsync();
        
        return new PagamentoAgrupadoResultDto
        {
            Sucesso = true,
            PagamentosCriados = pagamentosCriados.Count,
            VendasProcessadas = vendas.Count,
        };
    }
    catch
    {
        await _unitOfWork.RollbackTransactionAsync();
        throw;
    }
}

// Distribuir pagamento proporcionalmente
private Dictionary<Venda, decimal> DistribuirPagamentoProporcionalmente(
    List<Venda> vendas, 
    decimal valorTotal)
{
    var saldoTotal = vendas.Sum(v => v.SaldoRestante);
    var distribuicao = new Dictionary<Venda, decimal>();
    
    // Distribuir proporcionalmente
    decimal distribuido = 0;
    for (int i = 0; i < vendas.Count; i++)
    {
        var venda = vendas[i];
        var proporcao = venda.SaldoRestante / saldoTotal;
        var valorVenda = i == vendas.Count - 1 
            ? valorTotal - distribuido // Última venda recebe o restante
            : Math.Round(valorTotal * proporcao, 2);
        
        // Garantir que não excede o saldo da venda
        valorVenda = Math.Min(valorVenda, venda.SaldoRestante);
        
        distribuicao[venda] = valorVenda;
        distribuido += valorVenda;
    }
    
    return distribuicao;
}

// Filtrar produtos que pertencem a uma venda específica
private async Task<List<ProdutoNotaFiscalDto>> FiltrarProdutosPorVendaAsync(
    Guid vendaId, 
    List<ProdutoNotaFiscalDto> produtos)
{
    var pedidos = await _unitOfWork.PedidoRepository.GetByVendaIdAsync(vendaId);
    var produtosVenda = pedidos
        .SelectMany(p => p.Itens)
        .Select(i => i.ProdutoId)
        .Distinct()
        .ToList();
    
    return produtos
        .Where(p => produtosVenda.Contains(p.ProdutoId))
        .ToList();
}
```

---

### **Frontend - Ajustar Processamento de Pagamento**

```dart
// pagamento_restaurante_screen.dart
Future<void> _processarPagamento() async {
  // ... validações ...
  
  if (widget.isPagamentoAgrupado && widget.vendasOriginais != null && widget.vendasOriginais!.isNotEmpty) {
    // 🆕 Pagamento agrupado: distribuir entre todas as vendas
    final valor = _valorDigitado ?? _calcularValorProdutosSelecionados();
    
    // Preparar produtos para nota (se emitir nota parcial)
    List<Map<String, dynamic>>? produtosParaNota;
    if (_emitirNotaParcial && _temProdutosSelecionados) {
      produtosParaNota = _produtosSelecionados.entries
          .where((e) => e.value > 0)
          .map((e) => ProdutoNotaFiscalDto(
                produtoId: e.key,
                quantidade: e.value,
              ).toJson())
          .toList();
    }
    
    // Chamar endpoint de pagamento agrupado
    LoadingHelper.show(context);
    try {
      final response = await _vendaService.processarPagamentoAgrupado(
        vendaIds: widget.vendasOriginais!.map((v) => v.id).toList(),
        valor: valor,
        formaPagamento: _selectedMethod!.label,
        tipoFormaPagamento: _selectedMethod!.tipoFormaPagamento,
        numeroParcelas: 1,
        emitirNotaFiscal: _emitirNotaParcial && _temProdutosSelecionados,
        produtos: produtosParaNota,
      );
      
      if (response.success) {
        // Atualizar venda atualizada (recarregar)
        final vendaAtualizada = await _vendaService.getVendaById(widget.vendasOriginais!.first.id);
        if (vendaAtualizada.success && vendaAtualizada.data != null) {
          setState(() {
            _vendaAtualizada = vendaAtualizada.data;
          });
        }
        
        // Verificar se saldo zerou
        final saldoZerou = _saldoRestante <= 0.01;
        if (saldoZerou) {
          // Oferecer conclusão
          // ...
        }
      } else {
        AppToast.showError(context, response.message ?? 'Erro ao processar pagamento');
      }
    } catch (e) {
      AppToast.showError(context, 'Erro ao processar pagamento: $e');
    } finally {
      LoadingHelper.hide(context);
    }
  } else {
    // Fluxo normal (comanda específica)
    await paymentFlowProvider.processPayment(
      providerKey: providerKey,
      amount: valor,
      vendaId: widget.venda.id,
      additionalData: additionalData,
    );
  }
}
```

---

## 📊 Exemplo Prático

**Cenário:**
- Venda A: Saldo R$ 100,00
- Venda B: Saldo R$ 200,00
- Venda C: Saldo R$ 50,00
- Saldo total: R$ 350,00

**Usuário paga R$ 350,00:**

**Distribuição:**
- Venda A: R$ 100,00 (proporção: 100/350 = 28.57%)
- Venda B: R$ 200,00 (proporção: 200/350 = 57.14%)
- Venda C: R$ 50,00 (proporção: 50/350 = 14.29%, recebe o restante)

**Resultado:**
```
Venda A
├── Pagamentos: [P1 (R$ 100)]
└── Saldo: R$ 0

Venda B
├── Pagamentos: [P2 (R$ 200)]
└── Saldo: R$ 0

Venda C
├── Pagamentos: [P3 (R$ 50)]
└── Saldo: R$ 0
```

**Se emitir nota parcial:**
- Cada venda recebe seus produtos específicos
- Cada venda pode ter sua própria nota parcial
- Ou criar uma nota única consolidada (mais complexo)

---

## ✅ Vantagens

1. **Justo** - Cada venda recebe pagamento proporcional ao seu saldo
2. **Rastreável** - Cada venda tem seus pagamentos corretos
3. **Relatórios corretos** - Não distorce valores por venda
4. **Fluxo atômico** - Tudo em uma transação única

---

## 🎯 Resumo

**Abordagem:** Pagamento distribuído proporcionalmente
- Usuário paga valor único (ex: R$ 350)
- Sistema distribui proporcionalmente entre todas as vendas
- Cada venda recebe sua parte do pagamento
- Na finalização, consolida tudo e cria nota única

