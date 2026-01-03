# 🖨️ Arquitetura de Impressão: Estrutura Completa e Definitiva

## 🎯 Princípios

1. **PDV decide onde imprimir**
2. **PDV formata os dados**
3. **PDV executa impressão direta OU envia para fila**
4. **Estrutura simples e clara**

---

## 📊 Estrutura Completa

### **1. Retaguarda (Online)**

#### **Tabelas:**

```csharp
// Impressoras (Global - por Tenant)
public class Impressora : BaseEntityTenant
{
    public string Nome { get; set; } // "Cozinha", "Bar"
    public string? Descricao { get; set; }
    public bool IsAtiva { get; set; } = true;
}

// ConfiguracaoImpressaoDocumento (por Empresa - Obrigatório)
public class ConfiguracaoImpressaoDocumento : BaseEntityTenant, IHasEmpresaRequired
{
    public Guid EmpresaId { get; set; }
    public TipoDocumentoImpressao TipoDocumento { get; set; }
    public Guid ImpressoraId { get; set; } // Qual impressora usar
    public Impressora Impressora { get; set; } = null!;
    public bool ImprimirAutomaticamente { get; set; } = true;
}

// ProdutoImpressora (por Empresa - Opcional)
public class ProdutoImpressora : BaseEntityTenant, IHasEmpresaRequired
{
    public Guid EmpresaId { get; set; }
    public Guid ProdutoId { get; set; }
    public Produto Produto { get; set; } = null!;
    public Guid? ImpressoraId { get; set; } // NULL = não imprime
    public Impressora? Impressora { get; set; }
}

public enum TipoDocumentoImpressao
{
    CupomFiscal = 1,
    ParcialVenda = 2,
    ComandaConferencia = 3,
    Orcamento = 4,
    Recibo = 5,
}
```

#### **APIs:**

```
GET /api/impressoras?empresaId={id}
→ Lista impressoras disponíveis

GET /api/configuracao-impressao/documento?empresaId={id}&tipoDocumento={tipo}
→ Retorna qual impressora usar para o documento

GET /api/produto-impressora?empresaId={id}&produtoId={id}
→ Retorna qual impressora usar para o produto (ou null)
```

---

### **2. PDV (Flutter)**

#### **Estrutura de Dados:**

```dart
// Configuração local de cada impressora (Hive)
@HiveType(typeId: 21)
class ConfiguracaoImpressoraLocal extends HiveObject {
  @HiveField(0)
  final String impressoraId; // ID do retaguarda
  
  @HiveField(1)
  final String nome; // Nome da impressora
  
  @HiveField(2)
  final int tipoConexao; // TipoConexaoImpressora.index
  
  // Se tipoConexao = bluetooth
  @HiveField(3)
  final String? bluetoothMacAddress;
  
  @HiveField(4)
  final String? bluetoothNome;
  
  // Se tipoConexao = api
  @HiveField(5)
  final String? apiLocalUrl;
  
  TipoConexaoImpressora get tipoConexaoEnum => 
      TipoConexaoImpressora.values[tipoConexao];
}

enum TipoConexaoImpressora {
  integrada,  // Impressora integrada (POS - SDK)
  api,       // Via API Local (fila)
  bluetooth, // Bluetooth direto
}

// Constante especial
class ImpressoraEspecial {
  static const String IMPRESSORA_INTEGRADA_ID = "INTEGRADA";
  static const String IMPRESSORA_INTEGRADA_NOME = "Impressora Integrada";
}
```

---

### **3. API Local**

#### **Tabelas:**

```csharp
// ImpressoraPeriferico (mapeamento físico)
public class ImpressoraPeriferico
{
    public Guid Id { get; set; }
    public Guid ImpressoraId { get; set; } // ID lógico (retaguarda)
    public Guid EmpresaId { get; set; }
    
    public string TipoPeriferico { get; set; } // "Network", "USB", "Bluetooth"
    public string Identificador { get; set; } // IP, MAC, nome
    public int? Porta { get; set; }
    public string? ConfiguracaoJson { get; set; }
    
    public bool IsAtiva { get; set; } = true;
}

// Impressoes (fila)
public class Impressao
{
    public Guid Id { get; set; }
    public Guid EmpresaId { get; set; }
    public Guid? PedidoId { get; set; }
    public Guid? ItemPedidoId { get; set; }
    
    public string ImpressoraId { get; set; } // ID lógico (retaguarda)
    public TipoDocumentoImpressao TipoDocumento { get; set; }
    public string DadosJson { get; set; } // Dados formatados pelo PDV
    
    public StatusImpressao Status { get; set; } = StatusImpressao.Pendente;
    public DateTime CriadoEm { get; set; } = DateTime.UtcNow;
    public DateTime? ProcessadoEm { get; set; }
    public string? Erro { get; set; }
    public int Tentativas { get; set; } = 0;
}

public enum StatusImpressao
{
    Pendente = 0,
    Processando = 1,
    Concluida = 2,
    Erro = 3,
}
```

#### **APIs:**

```
POST /api/impressao/enfileirar
Body: {
  impressoraId: "imp-cozinha",
  tipoDocumento: "comandaProduto",
  dadosFormatados: { ... }, // PrintData ou NfcePrintData (JSON)
  pedidoId: "ped-123",
  itemPedidoId: "item-456"
}
Response: {
  success: true,
  impressaoId: "imp-789"
}

GET /api/impressao/status
Response: {
  pendentes: 5,
  processando: 2,
  concluidasHoje: 150
}
```

---

## 🔄 Fluxo Completo

### **FASE 1: Inicialização do PDV**

```
PDV abre
  ↓
1. Busca impressoras do retaguarda:
   GET /api/impressoras?empresaId={id}
   Response: [
     { id: "imp-cozinha", nome: "Cozinha" },
     { id: "imp-bar", nome: "Bar" },
     { id: "imp-cupom", nome: "Cupom Fiscal" }
   ]
  ↓
2. Para cada impressora, verifica config local:
   - imp-cozinha → Tem config? Não → Precisa configurar
   - imp-bar → Tem config? Não → Precisa configurar
   - imp-cupom → Tem config? Não → Precisa configurar
  ↓
3. Mostra tela: "Configurar Impressoras"
   - Usuário configura cada uma:
     * Cozinha → Tipo: API Local
     * Bar → Tipo: Bluetooth (EPSON TM20)
     * Cupom Fiscal → Tipo: Impressora Integrada
```

---

### **FASE 2: Criar Pedido**

```
PDV cria pedido:
  Pedido {
    itens: [
      { produto: Pizza, quantidade: 1 },
      { produto: Refrigerante, quantidade: 2 }
    ]
  }
  ↓
Para CADA item do pedido:
  ↓
ITEM 1: Pizza
  ↓
1. Busca impressora do produto (retaguarda):
   GET /api/produto-impressora?produtoId=pizza-id
   Response: { impressoraId: "imp-cozinha" }
  ↓
2. Busca config local da impressora:
   ConfiguracaoImpressoraLocal.get("imp-cozinha")
   Response: { tipoConexao: TipoConexaoImpressora.api }
  ↓
3. Formata dados:
   PrintData {
     header: { titulo: "COMANDA", numero: "123" },
     items: [ { produtoNome: "Pizza", quantidade: 1 } ],
     ...
   }
  ↓
4. Executa impressão:
   Se tipoConexao = api:
     → POST /api/impressao/enfileirar {
         impressoraId: "imp-cozinha",
         dadosFormatados: { ... }
       }
   Se tipoConexao = bluetooth:
     → Conecta Bluetooth e imprime direto
   Se tipoConexao = integrada:
     → Imprime direto na integrada (SDK)
  ↓
ITEM 2: Refrigerante
  ↓
1. Busca impressora do produto:
   GET /api/produto-impressora?produtoId=refrigerante-id
   Response: { impressoraId: "imp-bar" }
  ↓
2. Busca config local:
   ConfiguracaoImpressoraLocal.get("imp-bar")
   Response: { tipoConexao: TipoConexaoImpressora.bluetooth, macAddress: "00:11:22:33:44:55" }
  ↓
3. Formata dados:
   PrintData { Refrigerante x2 }
  ↓
4. Executa impressão:
   → Conecta Bluetooth (00:11:22:33:44:55)
   → Imprime direto
```

---

### **FASE 3: Finalizar Venda (Cupom Fiscal)**

```
PDV finaliza venda
  ↓
1. Busca configuração do documento (retaguarda):
   GET /api/configuracao-impressao/documento?tipoDocumento=CupomFiscal
   Response: { impressoraId: "imp-cupom" }
  ↓
2. Busca config local da impressora:
   ConfiguracaoImpressoraLocal.get("imp-cupom")
   Response: { tipoConexao: TipoConexaoImpressora.integrada }
  ↓
3. Busca dados da NFC-e:
   GET /api/notas-fiscais/{id}/dados-impressao
   Response: NfcePrintData { ... }
  ↓
4. Executa impressão:
   → tipoConexao = integrada
   → Usa SDK (StoneThermalAdapter)
   → Imprime direto na impressora integrada
```

---

## 🏗️ Estrutura de Arquivos (PDV)

```
lib/
├── core/
│   └── printing/
│       ├── models/
│       │   ├── impressora_config_local.dart
│       │   ├── impressora_dto.dart
│       │   └── impressora_especial.dart
│       │
│       ├── repositories/
│       │   └── impressora_config_repository.dart
│       │
│       ├── services/
│       │   ├── impressora_service.dart
│       │   ├── pedido_impressao_service.dart
│       │   └── print_service.dart (NOVO - unificado)
│       │
│       ├── providers/
│       │   ├── print_provider.dart (interface)
│       │   ├── integrada_provider.dart (SDK)
│       │   ├── bluetooth_provider.dart
│       │   └── api_provider.dart (envia para fila)
│       │
│       └── formatters/
│           └── impressao_formatter.dart
│
└── data/
    ├── services/
    │   └── impressao_api_service.dart
    │
    └── models/
        └── impressao_enqueue_request.dart
```

---

## 🔧 PrintService Unificado

```dart
// lib/core/printing/services/print_service.dart

class PrintService {
  final ImpressoraService _impressoraService;
  final ImpressoraConfigRepository _configRepo;
  final ImpressaoApiService? _apiService;
  final Map<TipoConexaoImpressora, PrintProvider> _providers;
  
  /// Imprime produto
  Future<PrintResult> imprimirProduto({
    required PedidoDto pedido,
    required ItemPedidoDto item,
  }) async {
    // 1. Busca impressora do produto
    final impressoraId = await _impressoraService.buscarImpressoraProduto(
      item.produtoId,
    );
    
    if (impressoraId == null) {
      return PrintResult(
        success: false,
        errorMessage: 'Produto não tem impressora configurada',
      );
    }
    
    // 2. Busca config local
    final configLocal = await _configRepo.getByImpressoraId(impressoraId);
    if (configLocal == null) {
      return PrintResult(
        success: false,
        errorMessage: 'Impressora não configurada localmente',
      );
    }
    
    // 3. Formata dados
    final dadosFormatados = ImpressaoFormatter.formatarComandaProduto(
      pedido: pedido,
      item: item,
    );
    
    // 4. Imprime
    return await _imprimir(
      configLocal: configLocal,
      dadosFormatados: dadosFormatados,
      tipoDocumento: DocumentType.comandaProduto,
    );
  }
  
  /// Imprime documento
  Future<PrintResult> imprimirDocumento({
    required DocumentType tipoDocumento,
    required dynamic dadosFormatados,
  }) async {
    // 1. Busca impressora do documento
    final impressoraId = await _impressoraService.buscarImpressoraDocumento(
      tipoDocumento.name,
    );
    
    if (impressoraId == null) {
      return PrintResult(
        success: false,
        errorMessage: 'Documento não tem impressora configurada',
      );
    }
    
    // 2. Busca config local
    final configLocal = await _configRepo.getByImpressoraId(impressoraId);
    if (configLocal == null) {
      return PrintResult(
        success: false,
        errorMessage: 'Impressora não configurada localmente',
      );
    }
    
    // 3. Imprime
    return await _imprimir(
      configLocal: configLocal,
      dadosFormatados: dadosFormatados,
      tipoDocumento: tipoDocumento,
    );
  }
  
  /// Método único de impressão
  Future<PrintResult> _imprimir({
    required ConfiguracaoImpressoraLocal configLocal,
    required dynamic dadosFormatados,
    required DocumentType tipoDocumento,
  }) async {
    // Obtém provider baseado no tipo de conexão
    final provider = _getProvider(configLocal.tipoConexaoEnum, configLocal);
    
    if (provider == null) {
      return PrintResult(
        success: false,
        errorMessage: 'Provider não disponível',
      );
    }
    
    // Inicializa e imprime
    await provider.initialize();
    
    if (tipoDocumento == DocumentType.nfce) {
      return await provider.printNfce(dadosFormatados as NfcePrintData);
    } else {
      return await provider.printComanda(dadosFormatados as PrintData);
    }
  }
  
  /// Obtém provider baseado no tipo de conexão
  PrintProvider? _getProvider(
    TipoConexaoImpressora tipoConexao,
    ConfiguracaoImpressoraLocal configLocal,
  ) {
    switch (tipoConexao) {
      case TipoConexaoImpressora.integrada:
        return IntegradaProvider(); // Usa SDK
        
      case TipoConexaoImpressora.bluetooth:
        return BluetoothProvider(
          macAddress: configLocal.bluetoothMacAddress!,
        );
        
      case TipoConexaoImpressora.api:
        return ApiProvider(
          apiService: _apiService!,
          impressoraId: configLocal.impressoraId,
        );
    }
  }
}
```

---

## 🎨 Providers

### **IntegradaProvider (SDK)**

```dart
// lib/core/printing/providers/integrada_provider.dart

class IntegradaProvider implements PrintProvider {
  PrintProvider? _sdkProvider; // StoneThermalAdapter ou similar
  
  @override
  Future<void> initialize() async {
    if (FlavorConfig.isStoneP2) {
      _sdkProvider = StoneThermalAdapter();
    } else if (FlavorConfig.isElgin) {
      _sdkProvider = ElginThermalAdapter();
    }
    
    await _sdkProvider?.initialize();
  }
  
  @override
  Future<PrintResult> printNfce(NfcePrintData data) async {
    return await _sdkProvider?.printNfce(data) ?? PrintResult(
      success: false,
      errorMessage: 'SDK não disponível',
    );
  }
  
  @override
  Future<PrintResult> printComanda(PrintData data) async {
    return await _sdkProvider?.printComanda(data) ?? PrintResult(
      success: false,
      errorMessage: 'SDK não disponível',
    );
  }
}
```

### **BluetoothProvider**

```dart
// lib/core/printing/providers/bluetooth_provider.dart

class BluetoothProvider implements PrintProvider {
  final String macAddress;
  
  BluetoothProvider({required this.macAddress});
  
  @override
  Future<void> initialize() async {
    // Conecta Bluetooth
  }
  
  @override
  Future<PrintResult> printComanda(PrintData data) async {
    // Imprime via Bluetooth
  }
}
```

### **ApiProvider**

```dart
// lib/core/printing/providers/api_provider.dart

class ApiProvider implements PrintProvider {
  final ImpressaoApiService apiService;
  final String impressoraId;
  
  ApiProvider({
    required this.apiService,
    required this.impressoraId,
  });
  
  @override
  Future<void> initialize() async {
    // Não precisa inicializar (só envia para API)
  }
  
  @override
  Future<PrintResult> printComanda(PrintData data) async {
    // Envia para fila
    return await apiService.enfileirarImpressao(
      impressoraId: impressoraId,
      tipoDocumento: DocumentType.comandaProduto,
      dadosFormatados: data,
    );
  }
}
```

---

## ✅ Resumo da Estrutura

### **Retaguarda:**
- ✅ Cadastra impressoras
- ✅ Configura documentos → impressoras (obrigatório)
- ✅ Vincula produtos → impressoras (opcional)

### **PDV:**
- ✅ Busca configurações do retaguarda
- ✅ Configura localmente como conectar cada impressora
- ✅ Formata dados
- ✅ Decide e executa impressão

### **API Local:**
- ✅ Mapeia impressora → periférico físico
- ✅ Processa fila de impressão

### **Providers:**
- ✅ IntegradaProvider (SDK)
- ✅ BluetoothProvider
- ✅ ApiProvider

**Estrutura completa e unificada!** 🎯

