# Pendências: Impressão de NFC-e

## 📋 Resumo Executivo

Este documento lista todas as pendências e próximos passos para completar a implementação da impressão automática de NFC-e no sistema H4ND PDV.

---

## ✅ O que já está implementado

### Backend (h4nd-api)

1. ✅ **DTO de Impressão** (`NfcePrintDto`)
   - Dados completos da NFC-e para impressão
   - Inclui empresa, nota, cliente, itens, totais, pagamentos, QR Code

2. ✅ **Serviço de Dados** (`NotaFiscalService.GetDadosParaImpressaoAsync`)
   - Busca dados da nota fiscal local
   - Busca QR Code do h4nd-notas via API
   - Monta DTO completo para impressão

3. ✅ **Endpoint de API** (`GET /api/notas-fiscais/{id}/dados-impressao`)
   - Retorna `NfcePrintDto` com todos os dados necessários
   - Inclui QR Code texto e URL de consulta

4. ✅ **HttpClient Configurado**
   - `NotaFiscalService` configurado para buscar QR Code do h4nd-notas
   - Timeout de 10 segundos

### Frontend/PDV (h4nd-pdv - Flutter)

1. ✅ **Modelos de Dados**
   - `NfcePrintData` - Dados estruturados para impressão
   - `NfceItemPrintData` - Dados de itens
   - `NfcePagamentoPrintData` - Dados de pagamentos
   - `NotaFiscalInfoDto` - Informações da nota fiscal no `VendaDto`

2. ✅ **Serviço de API** (`NotaFiscalService`)
   - Método `getDadosParaImpressao` implementado
   - Integrado ao `ServicesProvider`

3. ✅ **Interface de Impressão**
   - Método `printNfce` adicionado à interface `PrintProvider`
   - Método `printNfce` implementado no `PrintService`

4. ✅ **Adapter Stone Thermal** (`StoneThermalAdapter`)
   - Método `printNfce` implementado
   - Formatação completa para impressora térmica 57mm
   - Layout de cupom fiscal com todos os dados obrigatórios
   - Métodos auxiliares: `_formatCNPJ`, `_formatCPF`, `_formatarChaveAcesso`

5. ✅ **Impressão Automática**
   - Implementada em `DetalhesProdutosMesaScreen._finalizarVenda()`
   - Implementada em `PagamentoRestauranteScreen._concluirVenda()`
   - Verifica se nota foi autorizada antes de imprimir

6. ✅ **Outros Adapters**
   - `ElginThermalAdapter.printNfce` - Retorna erro (não implementado)
   - `PDFPrinterAdapter.printNfce` - Retorna erro (não implementado)

---

## ❌ O que falta fazer

### 1. Geração de QR Code como Imagem Base64

**Status**: ⚠️ Parcialmente implementado (código comentado)

**Localização**: `h4nd-pdv/lib/data/adapters/printing/providers/stone_thermal_adapter.dart`

**Problema**: 
- O método `_gerarQrCodeImagem` está implementado mas comentado
- Falta instalar o pacote `qr_flutter`
- O QR Code está sendo impresso apenas como texto (não como imagem)

**Solução**:

#### 1.1. Instalar pacote qr_flutter

```bash
cd /Users/claudiocamargos/Documents/GitHub/H4ND/h4nd-pdv
flutter pub add qr_flutter
```

#### 1.2. Descomentar e ajustar código

**Arquivo**: `h4nd-pdv/lib/data/adapters/printing/providers/stone_thermal_adapter.dart`

**Linhas**: ~1135-1180

**Ações**:
1. Descomentar os imports:
   ```dart
   import 'package:qr_flutter/qr_flutter.dart';
   import 'dart:convert';
   import 'dart:typed_data';
   import 'dart:ui' as ui;
   import 'package:flutter/rendering.dart';
   ```

2. Descomentar o código dentro de `_gerarQrCodeImagem`:
   ```dart
   Future<String?> _gerarQrCodeImagem(String qrCodeTexto) async {
     try {
       debugPrint('🔲 Gerando QR Code como imagem base64...');
       
       const qrSize = 200.0;
       
       final qrPainter = QrPainter(
         data: qrCodeTexto,
         version: QrVersions.auto,
         errorCorrectionLevel: QrErrorCorrectLevel.M,
         size: qrSize,
       );
       
       final recorder = ui.PictureRecorder();
       final canvas = Canvas(recorder);
       final size = Size(qrSize, qrSize);
       
       qrPainter.paint(canvas, size);
       
       final picture = recorder.endRecording();
       final image = await picture.toImage(qrSize.toInt(), qrSize.toInt());
       
       final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
       if (byteData == null) {
         debugPrint('❌ Erro ao converter QR Code para bytes');
         return null;
       }
       
       final pngBytes = byteData.buffer.asUint8List();
       final base64String = base64Encode(pngBytes);
       
       debugPrint('✅ QR Code gerado como base64 (${base64String.length} caracteres)');
       return base64String;
     } catch (e) {
       debugPrint('❌ Erro ao gerar QR Code: $e');
       return null;
     }
   }
   ```

3. Remover o código placeholder que retorna `null`

**Prioridade**: 🔴 Alta (QR Code é obrigatório na impressão)

**Estimativa**: 15 minutos

---

### 2. Testes de Impressão no Dispositivo StoneP2

**Status**: ❌ Não testado

**O que testar**:

#### 2.1. Teste de Impressão Manual

1. **Preparar ambiente**:
   - Dispositivo StoneP2 com impressora térmica conectada
   - Aplicativo compilado com flavor `stoneP2`
   - Certificado digital configurado
   - CSC e numeração configurados

2. **Cenário de teste**:
   - Criar uma venda
   - Processar pagamento
   - Finalizar venda (deve emitir NFC-e)
   - Verificar se a impressão é automática após autorização

3. **Verificações**:
   - ✅ NFC-e é impressa automaticamente após autorização
   - ✅ Layout está correto (57mm térmico)
   - ✅ Todos os dados obrigatórios estão presentes
   - ✅ QR Code aparece como imagem (não apenas texto)
   - ✅ QR Code é escaneável e válido
   - ✅ Formatação está adequada para 57mm
   - ✅ Textos não estão cortados
   - ✅ Chave de acesso está formatada corretamente
   - ✅ Valores estão formatados corretamente (R$)
   - ✅ Data/hora estão formatadas corretamente

#### 2.2. Teste de Casos de Erro

1. **Impressora desconectada**:
   - Verificar se o erro é tratado graciosamente
   - Verificar se o usuário recebe feedback adequado

2. **QR Code inválido ou ausente**:
   - Verificar se a impressão continua (sem QR Code)
   - Verificar se há mensagem informativa

3. **Nota não autorizada**:
   - Verificar se a impressão não é acionada
   - Verificar logs de debug

**Prioridade**: 🔴 Alta (validação final)

**Estimativa**: 2-4 horas (dependendo de acesso ao dispositivo)

---

### 3. Tratamento de Erros e Feedback ao Usuário

**Status**: ⚠️ Parcialmente implementado

**Problemas identificados**:

1. **Erro silencioso**: Se a impressão falhar, o erro é apenas logado, não há feedback visual claro
2. **Timeout**: Não há timeout configurado para a busca de dados da NFC-e
3. **Retry**: Não há mecanismo de retry se a impressão falhar

**Soluções**:

#### 3.1. Melhorar feedback de erro

**Arquivo**: `h4nd-pdv/lib/screens/mesas/detalhes_produtos_mesa_screen.dart`

**Método**: `_imprimirNfceAutomaticamente`

**Mudanças**:
```dart
// Adicionar timeout na busca de dados
final dadosResponse = await _servicesProvider.notaFiscalService
    .getDadosParaImpressao(notaFiscalId)
    .timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('⚠️ Timeout ao buscar dados para impressão');
        return ApiResponse<NfcePrintData?>.error(
          message: 'Timeout ao buscar dados da NFC-e para impressão',
        );
      },
    );

// Melhorar mensagens de erro
if (!dadosResponse.success || dadosResponse.data == null) {
  debugPrint('⚠️ Não foi possível obter dados para impressão: ${dadosResponse.message}');
  
  // Mostrar toast informativo (não erro, pois impressão é opcional)
  if (mounted) {
    AppToast.showInfo(
      context, 
      'NFC-e autorizada, mas não foi possível imprimir automaticamente. Você pode reimprimir depois.',
    );
  }
  return;
}

// Adicionar timeout na impressão
final printResult = await printService
    .printNfce(data: dadosNfce)
    .timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        debugPrint('⚠️ Timeout na impressão da NFC-e');
        return PrintResult(
          success: false,
          errorMessage: 'Timeout na impressão. Tente novamente.',
        );
      },
    );
```

**Prioridade**: 🟡 Média (melhora UX)

**Estimativa**: 30 minutos

---

### 4. Implementação de Reimpressão Manual

**Status**: ❌ Não implementado

**Descrição**: Permitir que o usuário reimprima uma NFC-e já autorizada manualmente.

**Onde implementar**:

1. **Tela de Detalhes da Venda**:
   - Adicionar botão "Reimprimir NFC-e" (se nota foi autorizada)
   - Chamar o mesmo método `_imprimirNfceAutomaticamente`

2. **Tela de Histórico de Vendas**:
   - Adicionar opção de reimpressão no menu de ações
   - Buscar dados da NFC-e e imprimir

**Implementação**:

**Arquivo**: `h4nd-pdv/lib/screens/mesas/detalhes_produtos_mesa_screen.dart`

**Adicionar método público**:
```dart
/// Reimprime NFC-e manualmente (chamado pelo usuário)
Future<void> reimprimirNfce() async {
  // Buscar venda atualizada para obter nota fiscal
  final venda = await _provider.getVendaAtual();
  if (venda?.notaFiscal == null || !venda!.notaFiscal!.foiAutorizada) {
    if (mounted) {
      AppToast.showError(
        context,
        'NFC-e não encontrada ou não autorizada',
      );
    }
    return;
  }
  
  // Mostrar loading
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );
  
  try {
    await _imprimirNfceAutomaticamente(venda.notaFiscal!.id);
  } finally {
    if (mounted) {
      Navigator.of(context).pop(); // Fecha loading
    }
  }
}
```

**Prioridade**: 🟡 Média (funcionalidade útil)

**Estimativa**: 1 hora

---

### 5. Implementação para Outros Adapters

**Status**: ❌ Não implementado

**Adapters afetados**:

#### 5.1. ElginThermalAdapter

**Arquivo**: `h4nd-pdv/lib/data/adapters/printing/providers/elgin_thermal_adapter.dart`

**Status**: Método `printNfce` retorna erro

**Ação**: Implementar formatação similar ao `StoneThermalAdapter`, adaptada para SDK Elgin

**Prioridade**: 🟢 Baixa (se não usar Elgin)

**Estimativa**: 2-3 horas

#### 5.2. PDFPrinterAdapter

**Arquivo**: `h4nd-pdv/lib/data/adapters/printing/providers/pdf_printer_adapter.dart`

**Status**: Método `printNfce` retorna erro

**Ação**: Implementar geração de PDF da NFC-e usando `pdf` package

**Implementação sugerida**:
- Usar layout similar ao térmico, mas adaptado para A4
- Incluir QR Code como imagem
- Formatação mais espaçada (não precisa ser compacto como térmico)

**Prioridade**: 🟡 Média (útil para reimpressão/arquivo)

**Estimativa**: 3-4 horas

---

### 6. Validações e Melhorias

**Status**: ⚠️ Parcialmente implementado

#### 6.1. Validação de Dados Obrigatórios

**Problema**: Não há validação se todos os dados obrigatórios estão presentes antes de imprimir.

**Solução**: Adicionar validações no método `printNfce`:

```dart
// Validar dados obrigatórios
if (data.empresaRazaoSocial.isEmpty) {
  return PrintResult(
    success: false,
    errorMessage: 'Razão social da empresa não informada',
  );
}

if (data.chaveAcesso.isEmpty) {
  return PrintResult(
    success: false,
    errorMessage: 'Chave de acesso não informada',
  );
}

if (data.itens.isEmpty) {
  return PrintResult(
    success: false,
    errorMessage: 'NFC-e não possui itens',
  );
}
```

**Prioridade**: 🟡 Média

**Estimativa**: 30 minutos

#### 6.2. Ajuste de Tamanho de Fonte para 57mm

**Problema**: Fontes podem estar muito grandes ou muito pequenas para impressora térmica 57mm.

**Solução**: Testar e ajustar tamanhos de fonte no `StoneThermalAdapter`:

```dart
// Atualmente usando:
page.DefaultTextStyle(x => x.FontSize(7)); // Fonte menor para 57mm

// Pode precisar ajustar para:
// - Títulos: 8-9
// - Texto normal: 7
// - Detalhes: 6
// - Valores: 8 (bold)
```

**Prioridade**: 🟡 Média (depende de testes)

**Estimativa**: 1 hora (testes + ajustes)

#### 6.3. Quebra de Linhas Longas

**Problema**: Textos longos podem não quebrar corretamente em 57mm.

**Solução**: Verificar se o método `_wrapText` está funcionando corretamente para todos os campos:
- Descrição de produtos
- Endereço da empresa
- Chave de acesso
- URL de consulta

**Prioridade**: 🟡 Média

**Estimativa**: 30 minutos

---

### 7. Logging e Monitoramento

**Status**: ⚠️ Parcialmente implementado

**O que falta**:

#### 7.1. Logs Estruturados

Adicionar logs mais detalhados para debugging:

```dart
_logger.LogInformation("=== INÍCIO IMPRESSÃO NFC-e ===");
_logger.LogInformation("NotaFiscalId: {NotaFiscalId}", notaFiscalId);
_logger.LogInformation("Provider: {Provider}", providerKey);
_logger.LogInformation("Dados obtidos: QR Code presente: {TemQrCode}", dadosNfce.qrCodeTexto != null);
_logger.LogInformation("Resultado impressão: Sucesso: {Sucesso}, Erro: {Erro}", 
    printResult.success, printResult.errorMessage);
_logger.LogInformation("=== FIM IMPRESSÃO NFC-e ===");
```

**Prioridade**: 🟢 Baixa (útil para debugging)

**Estimativa**: 30 minutos

#### 7.2. Métricas de Impressão

Adicionar tracking de:
- Taxa de sucesso de impressão
- Tempo médio de impressão
- Erros mais comuns

**Prioridade**: 🟢 Baixa (nice to have)

**Estimativa**: 2 horas

---

### 8. Documentação

**Status**: ⚠️ Parcialmente documentado

#### 8.1. Documentação Técnica

Criar documento explicando:
- Como funciona a impressão automática
- Fluxo completo (autorização → impressão)
- Estrutura de dados
- Como adicionar novos adapters

**Prioridade**: 🟡 Média

**Estimativa**: 1 hora

#### 8.2. Guia de Troubleshooting

Criar guia com problemas comuns e soluções:
- NFC-e não imprime automaticamente
- QR Code não aparece
- Erro de timeout
- Impressora não responde

**Prioridade**: 🟡 Média

**Estimativa**: 1 hora

---

## 📊 Priorização

### 🔴 Alta Prioridade (Fazer primeiro)

1. **Geração de QR Code como Imagem Base64** (15 min)
   - Instalar `qr_flutter`
   - Descomentar e testar código

2. **Testes de Impressão no Dispositivo StoneP2** (2-4 horas)
   - Validar que tudo funciona end-to-end
   - Ajustar layout se necessário

### 🟡 Média Prioridade (Fazer depois)

3. **Tratamento de Erros e Feedback** (30 min)
   - Timeouts
   - Mensagens mais claras

4. **Reimpressão Manual** (1 hora)
   - Botão na interface

5. **Validações de Dados** (30 min)
   - Garantir dados obrigatórios

6. **Ajustes de Layout** (1 hora)
   - Tamanhos de fonte
   - Quebra de linhas

7. **PDF Printer Adapter** (3-4 horas)
   - Para reimpressão/arquivo

### 🟢 Baixa Prioridade (Nice to have)

8. **Elgin Thermal Adapter** (2-3 horas)
   - Se não usar Elgin, pode pular

9. **Logging Avançado** (30 min)
   - Logs estruturados

10. **Métricas** (2 horas)
    - Tracking de impressões

11. **Documentação** (2 horas)
    - Guias e troubleshooting

---

## 🎯 Plano de Ação Recomendado

### Fase 1: Completar Funcionalidade Básica (1 dia)

1. ✅ Instalar `qr_flutter`
2. ✅ Descomentar código de geração de QR Code
3. ✅ Testar geração de QR Code localmente
4. ✅ Testar impressão no dispositivo StoneP2
5. ✅ Ajustar layout se necessário

### Fase 2: Melhorias e Robustez (1 dia)

1. ✅ Adicionar timeouts
2. ✅ Melhorar mensagens de erro
3. ✅ Adicionar validações
4. ✅ Implementar reimpressão manual

### Fase 3: Funcionalidades Extras (2-3 dias)

1. ✅ Implementar PDF Printer Adapter
2. ✅ Documentação
3. ✅ Logging avançado (opcional)

---

## 📝 Checklist de Validação Final

Antes de considerar a implementação completa, validar:

### Funcionalidade
- [ ] NFC-e é impressa automaticamente após autorização
- [ ] QR Code aparece como imagem escaneável
- [ ] Todos os dados obrigatórios estão presentes
- [ ] Layout está correto para 57mm térmico
- [ ] Reimpressão manual funciona

### Qualidade
- [ ] Erros são tratados graciosamente
- [ ] Usuário recebe feedback adequado
- [ ] Timeouts estão configurados
- [ ] Logs são suficientes para debugging

### Compatibilidade
- [ ] Funciona no dispositivo StoneP2
- [ ] Funciona com diferentes tamanhos de nota
- [ ] Funciona com diferentes quantidades de itens
- [ ] Funciona com diferentes formas de pagamento

---

## 🔗 Arquivos Relacionados

### Backend
- `h4nd-api/MXCloud.Application/DTOs/Core/Vendas/NfcePrintDto.cs`
- `h4nd-api/MXCloud.Application/Services/Core/Vendas/NotaFiscalService.cs`
- `h4nd-api/MXCloud.API/Controllers/Core/Vendas/NotaFiscalController.cs`

### Frontend
- `h4nd-pdv/lib/core/printing/nfce_print_data.dart`
- `h4nd-pdv/lib/core/printing/print_provider.dart`
- `h4nd-pdv/lib/core/printing/print_service.dart`
- `h4nd-pdv/lib/data/adapters/printing/providers/stone_thermal_adapter.dart`
- `h4nd-pdv/lib/data/services/core/nota_fiscal_service.dart`
- `h4nd-pdv/lib/screens/mesas/detalhes_produtos_mesa_screen.dart`
- `h4nd-pdv/lib/screens/pagamento/pagamento_restaurante_screen.dart`

---

## 📌 Notas Importantes

1. **QR Code é obrigatório**: A legislação exige que o QR Code seja impresso e escaneável. Sem ele, a NFC-e impressa não é válida.

2. **Impressão é opcional**: Se a impressão falhar, a venda não deve ser bloqueada. Apenas logar o erro e informar o usuário.

3. **Layout 57mm**: Impressoras térmicas 57mm têm limitações de largura. Textos devem ser quebrados adequadamente.

4. **Base64 para Stone**: O SDK da Stone aceita imagens em base64 diretamente no campo `data` do `ItemPrintModel` com `type: ItemPrintTypeEnum.image`.

5. **Testes são críticos**: Sem testar no dispositivo real, não é possível garantir que o layout está correto.

---

## 🚀 Próximos Passos Imediatos

1. **Instalar qr_flutter**:
   ```bash
   cd /Users/claudiocamargos/Documents/GitHub/H4ND/h4nd-pdv
   flutter pub add qr_flutter
   ```

2. **Descomentar código de QR Code** em `stone_thermal_adapter.dart`

3. **Testar geração de QR Code** localmente (sem impressora)

4. **Testar impressão completa** no dispositivo StoneP2

5. **Ajustar layout** baseado nos testes

---

**Última atualização**: 2025-01-XX
**Status geral**: 🟡 80% completo - Falta principalmente QR Code como imagem e testes finais

