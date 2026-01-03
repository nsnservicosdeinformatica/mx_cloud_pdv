# 🖨️ Impressão com SDK: Integração com Nova Arquitetura

## 🎯 Objetivo

Manter compatibilidade com o sistema atual (Stone P2 SDK) e integrar com a nova arquitetura de configuração.

---

## 📊 Como Funciona Atualmente (Stone P2)

### **Sistema Atual:**

```
PrintService.printNfce()
  ↓
Busca PrintConfig (print_stone_p2.json)
  ↓
Provider: "stone_thermal"
  ↓
StoneThermalAdapter.printNfce()
  ↓
Usa SDK Stone Payments
  ↓
Imprime na impressora integrada
```

### **Configuração Atual (print_stone_p2.json):**

```json
{
  "documents": {
    "nfce": {
      "defaultOutput": "thermalPrinter",
      "availableOutputs": ["thermalPrinter", "pdf"],
      "providerKey": "stone_thermal"
    }
  },
  "supportedProviders": ["stone_thermal", "pdf"],
  "defaultProvider": "stone_thermal",
  "providerSettings": {
    "stone_thermal": {
      "model": "P2",
      "appName": "MX Cloud PDV",
      "stoneCode": "206192723"
    }
  }
}
```

---

## 🔄 Como Integrar com Nova Arquitetura

### **Opção 1: Manter Sistema Atual + Nova Arquitetura (Recomendado)**

Mantém o sistema atual funcionando e adiciona a nova arquitetura como opção.

#### **Fluxo Híbrido:**

```
PDV precisa imprimir
  ↓
Verifica se tem config local (nova arquitetura):
  ├─ Se tem → Usa nova arquitetura
  └─ Se não tem → Usa sistema atual (PrintConfig)
```

#### **Implementação:**

```dart
// lib/core/printing/services/print_service_extended.dart

class PrintServiceExtended {
  final PrintService _printServiceOriginal; // Sistema atual
  final ImpressoraConfigRepository _configRepo;
  final ImpressaoApiService? _apiService;
  
  /// Imprime usando sistema híbrido
  Future<PrintResult> imprimirComTipo({
    required ConfiguracaoImpressoraLocal configLocal,
    required dynamic dadosFormatados,
    DocumentType tipoDocumento = DocumentType.comandaProduto,
  }) async {
    switch (configLocal.tipoConexaoEnum) {
      case TipoConexaoImpressora.integrada:
        // Usa sistema atual (PrintService original)
        return await _imprimirIntegrada(dadosFormatados, tipoDocumento);
        
      case TipoConexaoImpressora.bluetooth:
        return await _imprimirBluetooth(...);
        
      case TipoConexaoImpressora.api:
        return await _enviarParaFila(...);
    }
  }
  
  /// Impressão integrada (usa sistema atual)
  Future<PrintResult> _imprimirIntegrada(
    dynamic dadosFormatados,
    DocumentType tipoDocumento,
  ) async {
    if (!FlavorConfig.isStoneP2) {
      return PrintResult(
        success: false,
        errorMessage: 'Impressora integrada não disponível',
      );
    }
    
    // USA SISTEMA ATUAL (PrintService original)
    if (tipoDocumento == DocumentType.nfce) {
      return await _printServiceOriginal.printNfce(
        data: dadosFormatados as NfcePrintData,
      );
    } else {
      return await _printServiceOriginal.printDocument(
        documentType: tipoDocumento,
        data: dadosFormatados as PrintData,
      );
    }
  }
}
```

---

## 🎯 Cenários de Uso

### **Cenário 1: Stone P2 - Cupom Fiscal (Integrada)**

```
1. Retaguarda configura:
   - CupomFiscal → "INTEGRADA" (ou "imp-cupom" se quiser usar outra)

2. PDV configura localmente:
   - "INTEGRADA" → Tipo: Integrada
   (ou não configura, usa padrão do PrintConfig)

3. PDV finaliza venda:
   - Busca: CupomFiscal → "INTEGRADA"
   - Busca config: "INTEGRADA" → Tipo: Integrada
   - Chama: PrintServiceExtended.imprimirComTipo()
   - Decisão: tipoConexao = Integrada
   - Chama: _imprimirIntegrada()
   - Usa: PrintService original
   - Usa: StoneThermalAdapter
   - Imprime: SDK Stone Payments
```

### **Cenário 2: Stone P2 - Comanda Produto (API)**

```
1. Retaguarda configura:
   - Pizza → imp-cozinha

2. PDV configura localmente:
   - imp-cozinha → Tipo: API

3. PDV cria pedido:
   - Busca: Pizza → imp-cozinha
   - Busca config: imp-cozinha → Tipo: API
   - Chama: PrintServiceExtended.imprimirComTipo()
   - Decisão: tipoConexao = API
   - Chama: _enviarParaFila()
   - Envia: POST /api/impressao/enfileirar
   - API Local processa e imprime
```

### **Cenário 3: Stone P2 - Sem Config Local (Fallback)**

```
1. Retaguarda configura:
   - CupomFiscal → "INTEGRADA"

2. PDV NÃO configura localmente:
   - "INTEGRADA" → null (não tem config)

3. PDV finaliza venda:
   - Busca: CupomFiscal → "INTEGRADA"
   - Busca config: "INTEGRADA" → null
   - Fallback: Usa PrintService original
   - Usa: PrintConfig (print_stone_p2.json)
   - Provider: "stone_thermal"
   - Imprime: SDK Stone Payments
```

---

## 🔧 Implementação Detalhada

### **1. PrintServiceExtended com Fallback**

```dart
// lib/core/printing/services/print_service_extended.dart

class PrintServiceExtended {
  final PrintService _printServiceOriginal;
  final ImpressoraConfigRepository _configRepo;
  final ImpressaoApiService? _apiService;
  
  /// Imprime com fallback para sistema atual
  Future<PrintResult> imprimirComTipo({
    required String impressoraId,
    required dynamic dadosFormatados,
    DocumentType tipoDocumento = DocumentType.comandaProduto,
  }) async {
    // 1. Tenta buscar config local
    final configLocal = await _configRepo.getByImpressoraId(impressoraId);
    
    // 2. Se tem config local, usa nova arquitetura
    if (configLocal != null) {
      return await _imprimirComConfigLocal(
        configLocal: configLocal,
        dadosFormatados: dadosFormatados,
        tipoDocumento: tipoDocumento,
      );
    }
    
    // 3. Se não tem config local, usa sistema atual (fallback)
    return await _imprimirComSistemaAtual(
      impressoraId: impressoraId,
      dadosFormatados: dadosFormatados,
      tipoDocumento: tipoDocumento,
    );
  }
  
  /// Imprime usando config local (nova arquitetura)
  Future<PrintResult> _imprimirComConfigLocal({
    required ConfiguracaoImpressoraLocal configLocal,
    required dynamic dadosFormatados,
    required DocumentType tipoDocumento,
  }) async {
    switch (configLocal.tipoConexaoEnum) {
      case TipoConexaoImpressora.integrada:
        // Usa sistema atual para impressora integrada
        return await _imprimirIntegrada(dadosFormatados, tipoDocumento);
        
      case TipoConexaoImpressora.bluetooth:
        return await _imprimirBluetooth(...);
        
      case TipoConexaoImpressora.api:
        return await _enviarParaFila(...);
    }
  }
  
  /// Imprime usando sistema atual (fallback)
  Future<PrintResult> _imprimirComSistemaAtual({
    required String impressoraId,
    required dynamic dadosFormatados,
    required DocumentType tipoDocumento,
  }) async {
    // Se é impressora integrada, usa sistema atual
    if (impressoraId == ImpressoraEspecial.IMPRESSORA_INTEGRADA_ID) {
      return await _imprimirIntegrada(dadosFormatados, tipoDocumento);
    }
    
    // Para outras impressoras, tenta usar sistema atual
    // (pode não funcionar se não tiver config no PrintConfig)
    if (tipoDocumento == DocumentType.nfce) {
      return await _printServiceOriginal.printNfce(
        data: dadosFormatados as NfcePrintData,
      );
    } else {
      return await _printServiceOriginal.printDocument(
        documentType: tipoDocumento,
        data: dadosFormatados as dadosFormatados as PrintData,
      );
    }
  }
  
  /// Impressão integrada (usa sistema atual)
  Future<PrintResult> _imprimirIntegrada(
    dynamic dadosFormatados,
    DocumentType tipoDocumento,
  ) async {
    if (!FlavorConfig.isStoneP2) {
      return PrintResult(
        success: false,
        errorMessage: 'Impressora integrada não disponível',
      );
    }
    
    // USA SISTEMA ATUAL
    if (tipoDocumento == DocumentType.nfce) {
      return await _printServiceOriginal.printNfce(
        data: dadosFormatados as NfcePrintData,
      );
    } else {
      return await _printServiceOriginal.printDocument(
        documentType: tipoDocumento,
        data: dadosFormatados as PrintData,
      );
    }
  }
}
```

---

## 📋 Configuração para Stone P2

### **Opção A: Configurar Localmente (Nova Arquitetura)**

```
PDV Stone P2:
  1. Busca impressoras do retaguarda
  2. Para "INTEGRADA":
     - Configura: Tipo: Integrada
     - Salva no Hive
  3. Ao imprimir:
     - Busca config local
     - Usa sistema atual (PrintService)
```

### **Opção B: Não Configurar (Sistema Atual)**

```
PDV Stone P2:
  1. Não configura localmente
  2. Ao imprimir:
     - Busca config local → null
     - Fallback: Usa PrintConfig (print_stone_p2.json)
     - Usa sistema atual
```

---

## 🔄 Fluxo Completo: Stone P2

### **Cenário: Cupom Fiscal**

```
1. Retaguarda:
   - CupomFiscal → "INTEGRADA"

2. PDV Stone P2:
   - Busca config local: "INTEGRADA" → null (não configurado)
   - OU: "INTEGRADA" → Tipo: Integrada (configurado)

3. PrintServiceExtended:
   - Se tem config → Usa nova arquitetura
   - Se não tem → Fallback para sistema atual

4. Sistema Atual (PrintService):
   - Busca PrintConfig (print_stone_p2.json)
   - Provider: "stone_thermal"
   - StoneThermalAdapter.printNfce()
   - SDK Stone Payments
   - Imprime na impressora integrada
```

### **Cenário: Comanda Produto (API)**

```
1. Retaguarda:
   - Pizza → imp-cozinha

2. PDV Stone P2:
   - Configura: imp-cozinha → Tipo: API

3. PrintServiceExtended:
   - Busca config: imp-cozinha → Tipo: API
   - Chama: _enviarParaFila()
   - POST /api/impressao/enfileirar

4. API Local:
   - Processa fila
   - Imprime na impressora de rede
```

---

## ✅ Vantagens da Integração

### **1. Compatibilidade:**
- ✅ Sistema atual continua funcionando
- ✅ Nova arquitetura é opcional
- ✅ Fallback automático

### **2. Flexibilidade:**
- ✅ Stone P2 pode usar integrada (sistema atual)
- ✅ Stone P2 pode usar API Local (nova arquitetura)
- ✅ Usuário escolhe

### **3. Migração Gradual:**
- ✅ Pode migrar aos poucos
- ✅ Não quebra nada existente
- ✅ Testa nova arquitetura sem risco

---

## 📝 Resumo

### **Para Stone P2 (SDK):**

1. **Impressora Integrada:**
   - Se configurado localmente → Usa nova arquitetura
   - Se não configurado → Usa sistema atual (PrintConfig)
   - Ambos usam StoneThermalAdapter

2. **Outras Impressoras:**
   - Precisa configurar localmente
   - Usa nova arquitetura
   - Pode ser API ou Bluetooth

3. **Fallback:**
   - Se não tem config local → Usa sistema atual
   - Garante que sempre funciona

**Sistema atual continua funcionando + Nova arquitetura como opção!** 🎯

