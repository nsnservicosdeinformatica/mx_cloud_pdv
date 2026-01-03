# 🖨️ Implementação: Fatias Finas e Organizadas

## 🎯 Objetivo

Implementar o sistema de impressão de forma incremental, uma fatia por vez, com código organizado e claro.

---

## 📁 Estrutura de Arquivos

```
lib/
├── core/
│   └── printing/
│       ├── models/
│       │   ├── impressora_config_local.dart      (FATIA 1)
│       │   └── impressora_dto.dart                (FATIA 2)
│       │
│       ├── repositories/
│       │   └── impressora_config_repository.dart  (FATIA 3)
│       │
│       ├── services/
│       │   ├── impressora_service.dart            (FATIA 4)
│       │   ├── pedido_impressao_service.dart      (FATIA 5)
│       │   └── print_service_extended.dart       (FATIA 6)
│       │
│       └── formatters/
│           └── impressao_formatter.dart           (FATIA 7)
│
└── data/
    ├── services/
    │   └── impressao_api_service.dart             (FATIA 8)
    │
    └── models/
        └── impressao_enqueue_request.dart          (FATIA 9)
```

---

## 🍰 FATIA 1: Modelo de Configuração Local

### **Arquivo:** `lib/core/printing/models/impressora_config_local.dart`

```dart
import 'package:hive/hive.dart';

part 'impressora_config_local.g.dart';

/// Configuração local de uma impressora (armazenada no Hive)
@HiveType(typeId: 21)
class ConfiguracaoImpressoraLocal extends HiveObject {
  /// ID da impressora do retaguarda
  @HiveField(0)
  final String impressoraId;
  
  /// Nome da impressora (cópia do retaguarda)
  @HiveField(1)
  final String nome;
  
  /// Tipo de conexão configurado
  @HiveField(2)
  final int tipoConexao; // TipoConexaoImpressora.index
  
  /// MAC Address do Bluetooth (se tipoConexao = bluetooth)
  @HiveField(3)
  final String? bluetoothMacAddress;
  
  /// Nome do dispositivo Bluetooth (se tipoConexao = bluetooth)
  @HiveField(4)
  final String? bluetoothNome;
  
  /// URL da API Local (se tipoConexao = api)
  @HiveField(5)
  final String? apiLocalUrl;
  
  ConfiguracaoImpressoraLocal({
    required this.impressoraId,
    required this.nome,
    required this.tipoConexao,
    this.bluetoothMacAddress,
    this.bluetoothNome,
    this.apiLocalUrl,
  });
  
  /// Converte enum para index
  TipoConexaoImpressora get tipoConexaoEnum => 
      TipoConexaoImpressora.values[tipoConexao];
  
  /// Cria do enum
  factory ConfiguracaoImpressoraLocal.fromEnum({
    required String impressoraId,
    required String nome,
    required TipoConexaoImpressora tipoConexao,
    String? bluetoothMacAddress,
    String? bluetoothNome,
    String? apiLocalUrl,
  }) {
    return ConfiguracaoImpressoraLocal(
      impressoraId: impressoraId,
      nome: nome,
      tipoConexao: tipoConexao.index,
      bluetoothMacAddress: bluetoothMacAddress,
      bluetoothNome: bluetoothNome,
      apiLocalUrl: apiLocalUrl,
    );
  }
}

/// Tipos de conexão disponíveis
enum TipoConexaoImpressora {
  integrada,  // Impressora integrada do dispositivo (POS)
  api,       // Via API Local (fila)
  bluetooth, // Bluetooth conectado no dispositivo
}

/// Constantes para impressora especial
class ImpressoraEspecial {
  static const String IMPRESSORA_INTEGRADA_ID = "INTEGRADA";
  static const String IMPRESSORA_INTEGRADA_NOME = "Impressora Integrada";
}
```

**Teste:**
```dart
void main() {
  final config = ConfiguracaoImpressoraLocal.fromEnum(
    impressoraId: "imp-cozinha",
    nome: "Cozinha",
    tipoConexao: TipoConexaoImpressora.api,
    apiLocalUrl: "http://servidor-local:3000",
  );
  
  print(config.impressoraId); // imp-cozinha
  print(config.tipoConexaoEnum); // TipoConexaoImpressora.api
}
```

---

## 🍰 FATIA 2: DTO de Impressora (Retaguarda)

### **Arquivo:** `lib/core/printing/models/impressora_dto.dart`

```dart
/// DTO de impressora vindo do retaguarda
class ImpressoraDto {
  final String id;
  final String nome;
  final String? descricao;
  final bool isAtiva;
  
  ImpressoraDto({
    required this.id,
    required this.nome,
    this.descricao,
    this.isAtiva = true,
  });
  
  factory ImpressoraDto.fromJson(Map<String, dynamic> json) {
    return ImpressoraDto(
      id: json['id'] as String,
      nome: json['nome'] as String,
      descricao: json['descricao'] as String?,
      isAtiva: json['isAtiva'] as bool? ?? true,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'isAtiva': isAtiva,
    };
  }
}

/// DTO de impressora com configuração local
class ImpressoraComConfigDto {
  final ImpressoraDto impressora;
  final ConfiguracaoImpressoraLocal? configLocal;
  
  /// Se precisa configurar (não tem config local)
  bool get precisaConfigurar => configLocal == null;
  
  /// Se está configurada
  bool get estaConfigurada => configLocal != null;
  
  ImpressoraComConfigDto({
    required this.impressora,
    this.configLocal,
  });
}
```

**Teste:**
```dart
void main() {
  final impressora = ImpressoraDto.fromJson({
    'id': 'imp-cozinha',
    'nome': 'Cozinha',
    'isAtiva': true,
  });
  
  print(impressora.nome); // Cozinha
}
```

---

## 🍰 FATIA 3: Repositório de Configuração

### **Arquivo:** `lib/core/printing/repositories/impressora_config_repository.dart`

```dart
import 'package:hive/hive.dart';
import '../models/impressora_config_local.dart';

/// Repositório para gerenciar configurações locais de impressoras
class ImpressoraConfigRepository {
  static const String boxName = 'impressora_config';
  late Box<ConfiguracaoImpressoraLocal> _box;
  bool _initialized = false;
  
  /// Inicializa o repositório (chamar no início do app)
  Future<void> init() async {
    if (_initialized) return;
    
    // Registra adapter se necessário
    if (!Hive.isAdapterRegistered(21)) {
      Hive.registerAdapter(ConfiguracaoImpressoraLocalAdapter());
    }
    
    // Abre box
    _box = await Hive.openBox<ConfiguracaoImpressoraLocal>(boxName);
    _initialized = true;
  }
  
  /// Busca configuração por ID da impressora
  Future<ConfiguracaoImpressoraLocal?> getByImpressoraId(String impressoraId) async {
    await _ensureInitialized();
    return _box.get(impressoraId);
  }
  
  /// Salva configuração
  Future<void> save(ConfiguracaoImpressoraLocal config) async {
    await _ensureInitialized();
    await _box.put(config.impressoraId, config);
  }
  
  /// Remove configuração
  Future<void> delete(String impressoraId) async {
    await _ensureInitialized();
    await _box.delete(impressoraId);
  }
  
  /// Lista todas as configurações
  Future<List<ConfiguracaoImpressoraLocal>> getAll() async {
    await _ensureInitialized();
    return _box.values.toList();
  }
  
  /// Verifica se tem configuração
  Future<bool> hasConfig(String impressoraId) async {
    await _ensureInitialized();
    return _box.containsKey(impressoraId);
  }
  
  /// Limpa todas as configurações
  Future<void> clear() async {
    await _ensureInitialized();
    await _box.clear();
  }
  
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }
}
```

**Teste:**
```dart
void main() async {
  final repo = ImpressoraConfigRepository();
  await repo.init();
  
  final config = ConfiguracaoImpressoraLocal.fromEnum(
    impressoraId: "imp-cozinha",
    nome: "Cozinha",
    tipoConexao: TipoConexaoImpressora.api,
  );
  
  await repo.save(config);
  
  final saved = await repo.getByImpressoraId("imp-cozinha");
  print(saved?.nome); // Cozinha
}
```

---

## 🍰 FATIA 4: Serviço de Impressoras

### **Arquivo:** `lib/core/printing/services/impressora_service.dart`

```dart
import 'package:flutter/foundation.dart';
import '../../data/services/core/api_client.dart';
import '../models/impressora_dto.dart';
import '../models/impressora_config_local.dart';
import '../repositories/impressora_config_repository.dart';

/// Serviço para gerenciar impressoras
class ImpressoraService {
  final ApiClient _apiClient;
  final ImpressoraConfigRepository _configRepo;
  
  ImpressoraService({
    required ApiClient apiClient,
    required ImpressoraConfigRepository configRepo,
  }) : _apiClient = apiClient,
       _configRepo = configRepo;
  
  /// Busca impressoras do retaguarda
  Future<List<ImpressoraDto>> buscarImpressoras({
    required String empresaId,
  }) async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        '/impressoras?empresaId=$empresaId',
      );
      
      if (response.data == null) {
        return [];
      }
      
      return response.data!
          .map((e) => ImpressoraDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erro ao buscar impressoras: $e');
      return [];
    }
  }
  
  /// Busca impressoras com configuração local
  Future<List<ImpressoraComConfigDto>> buscarImpressorasComConfig({
    required String empresaId,
  }) async {
    // 1. Busca do retaguarda
    final impressoras = await buscarImpressoras(empresaId: empresaId);
    
    // 2. Para cada uma, busca config local
    final resultado = <ImpressoraComConfigDto>[];
    
    for (var impressora in impressoras) {
      final configLocal = await _configRepo.getByImpressoraId(impressora.id);
      
      resultado.add(ImpressoraComConfigDto(
        impressora: impressora,
        configLocal: configLocal,
      ));
    }
    
    return resultado;
  }
  
  /// Busca impressora de um produto
  Future<String?> buscarImpressoraProduto(String produtoId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/produto-impressora?produtoId=$produtoId',
      );
      
      if (response.data == null) {
        return null;
      }
      
      return response.data!['impressoraId'] as String?;
    } catch (e) {
      debugPrint('❌ Erro ao buscar impressora do produto: $e');
      return null;
    }
  }
  
  /// Busca impressora de um documento
  Future<String?> buscarImpressoraDocumento(String tipoDocumento) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/configuracao-impressao/documento?tipoDocumento=$tipoDocumento',
      );
      
      if (response.data == null) {
        return null;
      }
      
      return response.data!['impressoraId'] as String?;
    } catch (e) {
      debugPrint('❌ Erro ao buscar impressora do documento: $e');
      return null;
    }
  }
}
```

**Teste:**
```dart
void main() async {
  final service = ImpressoraService(
    apiClient: apiClient,
    configRepo: configRepo,
  );
  
  final impressoras = await service.buscarImpressorasComConfig(
    empresaId: "emp-001",
  );
  
  for (var item in impressoras) {
    print('${item.impressora.nome}: ${item.estaConfigurada ? "Configurada" : "Não configurada"}');
  }
}
```

---

## 🍰 FATIA 5: Serviço de Impressão de Pedidos

### **Arquivo:** `lib/core/printing/services/pedido_impressao_service.dart`

```dart
import 'package:flutter/foundation.dart';
import '../../data/models/core/pedido_dto.dart';
import '../../data/models/core/item_pedido_dto.dart';
import '../models/impressora_config_local.dart';
import '../repositories/impressora_config_repository.dart';
import 'impressora_service.dart';
import 'print_service_extended.dart';
import '../formatters/impressao_formatter.dart';

/// Resultado de impressão de um item
class ItemImpressaoResult {
  final String itemId;
  final String produtoNome;
  final String? impressoraId;
  final String? impressoraNome;
  final TipoConexaoImpressora? tipoConexao;
  final bool sucesso;
  final String? erro;
  
  ItemImpressaoResult({
    required this.itemId,
    required this.produtoNome,
    this.impressoraId,
    this.impressoraNome,
    this.tipoConexao,
    required this.sucesso,
    this.erro,
  });
}

/// Resultado de impressão de pedido completo
class ImpressaoPedidoResult {
  final List<ItemImpressaoResult> itens;
  final bool sucesso;
  
  ImpressaoPedidoResult({
    required this.itens,
    required this.sucesso,
  });
}

/// Serviço para processar impressão de pedidos
class PedidoImpressaoService {
  final ImpressoraService _impressoraService;
  final ImpressoraConfigRepository _configRepo;
  final PrintServiceExtended _printService;
  
  PedidoImpressaoService({
    required ImpressoraService impressoraService,
    required ImpressoraConfigRepository configRepo,
    required PrintServiceExtended printService,
  }) : _impressoraService = impressoraService,
       _configRepo = configRepo,
       _printService = printService;
  
  /// Processa impressão de todos os itens do pedido
  Future<ImpressaoPedidoResult> processarImpressaoPedido({
    required PedidoDto pedido,
  }) async {
    final resultados = <ItemImpressaoResult>[];
    
    // Para cada item do pedido
    for (var item in pedido.itens) {
      final resultado = await _processarItemPedido(pedido, item);
      resultados.add(resultado);
    }
    
    return ImpressaoPedidoResult(
      itens: resultados,
      sucesso: resultados.every((r) => r.sucesso),
    );
  }
  
  /// Processa impressão de um item específico
  Future<ItemImpressaoResult> _processarItemPedido(
    PedidoDto pedido,
    ItemPedidoDto item,
  ) async {
    try {
      // 1. Busca impressora do produto
      final impressoraId = await _impressoraService.buscarImpressoraProduto(
        item.produtoId,
      );
      
      if (impressoraId == null) {
        return ItemImpressaoResult(
          itemId: item.id,
          produtoNome: item.produtoNome,
          sucesso: false,
          erro: 'Produto não tem impressora configurada',
        );
      }
      
      // 2. Busca config local
      final configLocal = await _configRepo.getByImpressoraId(impressoraId);
      
      if (configLocal == null) {
        return ItemImpressaoResult(
          itemId: item.id,
          produtoNome: item.produtoNome,
          impressoraId: impressoraId,
          sucesso: false,
          erro: 'Impressora não configurada localmente',
        );
      }
      
      // 3. Formata dados
      final dadosFormatados = ImpressaoFormatter.formatarComandaProduto(
        pedido: pedido,
        item: item,
      );
      
      // 4. Imprime
      final resultado = await _printService.imprimirComTipo(
        configLocal: configLocal,
        dadosFormatados: dadosFormatados,
      );
      
      return ItemImpressaoResult(
        itemId: item.id,
        produtoNome: item.produtoNome,
        impressoraId: impressoraId,
        impressoraNome: configLocal.nome,
        tipoConexao: configLocal.tipoConexaoEnum,
        sucesso: resultado.success,
        erro: resultado.errorMessage,
      );
    } catch (e) {
      return ItemImpressaoResult(
        itemId: item.id,
        produtoNome: item.produtoNome,
        sucesso: false,
        erro: 'Erro: ${e.toString()}',
      );
    }
  }
}
```

**Teste:**
```dart
void main() async {
  final service = PedidoImpressaoService(
    impressoraService: impressoraService,
    configRepo: configRepo,
    printService: printService,
  );
  
  final resultado = await service.processarImpressaoPedido(
    pedido: pedido,
  );
  
  for (var item in resultado.itens) {
    print('${item.produtoNome}: ${item.sucesso ? "OK" : item.erro}');
  }
}
```

---

## 🍰 FATIA 6: PrintService Estendido

### **Arquivo:** `lib/core/printing/services/print_service_extended.dart`

```dart
import 'package:flutter/foundation.dart';
import '../models/impressora_config_local.dart';
import '../print_provider.dart';
import '../print_data.dart';
import '../nfce_print_data.dart';
import '../print_config.dart';
import '../../config/flavor_config.dart';
import '../../data/adapters/printing/print_provider_registry.dart';
import '../repositories/impressora_config_repository.dart';
import '../../data/services/impressao_api_service.dart';

/// Extensão do PrintService para novo sistema
class PrintServiceExtended {
  final ImpressoraConfigRepository _configRepo;
  final ImpressaoApiService? _apiService;
  final PrintConfig? _printConfig;
  
  PrintServiceExtended({
    required ImpressoraConfigRepository configRepo,
    ImpressaoApiService? apiService,
    PrintConfig? printConfig,
  }) : _configRepo = configRepo,
       _apiService = apiService,
       _printConfig = printConfig;
  
  /// Imprime baseado no tipo de conexão configurado
  Future<PrintResult> imprimirComTipo({
    required ConfiguracaoImpressoraLocal configLocal,
    required dynamic dadosFormatados,
    DocumentType tipoDocumento = DocumentType.comandaProduto,
  }) async {
    switch (configLocal.tipoConexaoEnum) {
      case TipoConexaoImpressora.integrada:
        return await _imprimirIntegrada(dadosFormatados, tipoDocumento);
        
      case TipoConexaoImpressora.bluetooth:
        return await _imprimirBluetooth(
          configLocal: configLocal,
          dadosFormatados: dadosFormatados,
          tipoDocumento: tipoDocumento,
        );
        
      case TipoConexaoImpressora.api:
        return await _enviarParaFila(
          impressoraId: configLocal.impressoraId,
          dadosFormatados: dadosFormatados,
          tipoDocumento: tipoDocumento,
        );
    }
  }
  
  /// Impressão integrada (POS)
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
    
    final provider = await _getProvider('stone_thermal');
    if (provider == null) {
      return PrintResult(
        success: false,
        errorMessage: 'Provider stone_thermal não disponível',
      );
    }
    
    await provider.initialize();
    
    if (tipoDocumento == DocumentType.nfce) {
      return await provider.printNfce(dadosFormatados as NfcePrintData);
    } else {
      return await provider.printComanda(dadosFormatados as PrintData);
    }
  }
  
  /// Impressão Bluetooth
  Future<PrintResult> _imprimirBluetooth({
    required ConfiguracaoImpressoraLocal configLocal,
    required dynamic dadosFormatados,
    required DocumentType tipoDocumento,
  }) async {
    if (configLocal.bluetoothMacAddress == null) {
      return PrintResult(
        success: false,
        errorMessage: 'Bluetooth não configurado',
      );
    }
    
    // TODO: Implementar provider Bluetooth
    return PrintResult(
      success: false,
      errorMessage: 'Bluetooth ainda não implementado',
    );
  }
  
  /// Envia para fila (API Local)
  Future<PrintResult> _enviarParaFila({
    required String impressoraId,
    required dynamic dadosFormatados,
    required DocumentType tipoDocumento,
  }) async {
    if (_apiService == null) {
      return PrintResult(
        success: false,
        errorMessage: 'API Local não configurada',
      );
    }
    
    return await _apiService!.enfileirarImpressao(
      impressoraId: impressoraId,
      tipoDocumento: tipoDocumento,
      dadosFormatados: dadosFormatados,
    );
  }
  
  Future<PrintProvider?> _getProvider(String providerKey) async {
    final settings = _printConfig?.providerSettings?[providerKey];
    return PrintProviderRegistry.getProvider(providerKey, settings: settings);
  }
}
```

---

## 🍰 FATIA 7: Formatador de Dados

### **Arquivo:** `lib/core/printing/formatters/impressao_formatter.dart`

```dart
import '../print_data.dart';
import '../../data/models/core/pedido_dto.dart';
import '../../data/models/core/item_pedido_dto.dart';

/// Formatador de dados de impressão
class ImpressaoFormatter {
  /// Formata comanda de produto
  static PrintData formatarComandaProduto({
    required PedidoDto pedido,
    required ItemPedidoDto item,
  }) {
    return PrintData(
      header: PrintHeader(
        titulo: 'COMANDA',
        numero: pedido.numero,
        data: DateTime.now(),
      ),
      entityInfo: PrintEntityInfo(
        tipo: pedido.mesaNome != null ? 'Mesa' : 'Comanda',
        nome: pedido.mesaNome ?? pedido.comandaNumero ?? '',
      ),
      items: [
        PrintItem(
          produtoNome: item.produtoNome,
          quantidade: item.quantidade,
          observacoes: item.observacoes,
          valorUnitario: item.valorUnitario,
          valorTotal: item.valorTotal,
        ),
      ],
      totals: PrintTotals(
        total: item.valorTotal,
      ),
      footer: PrintFooter(
        mensagem: 'Obrigado pela preferência!',
      ),
    );
  }
  
  /// Formata comanda completa do pedido
  static PrintData formatarComandaPedido({
    required PedidoDto pedido,
  }) {
    return PrintData(
      header: PrintHeader(
        titulo: 'COMANDA',
        numero: pedido.numero,
        data: DateTime.now(),
      ),
      entityInfo: PrintEntityInfo(
        tipo: pedido.mesaNome != null ? 'Mesa' : 'Comanda',
        nome: pedido.mesaNome ?? pedido.comandaNumero ?? '',
      ),
      items: pedido.itens.map((item) => PrintItem(
        produtoNome: item.produtoNome,
        quantidade: item.quantidade,
        observacoes: item.observacoes,
        valorUnitario: item.valorUnitario,
        valorTotal: item.valorTotal,
      )).toList(),
      totals: PrintTotals(
        subtotal: pedido.subtotal,
        desconto: pedido.desconto,
        total: pedido.valorTotal,
      ),
      footer: PrintFooter(
        mensagem: 'Obrigado pela preferência!',
      ),
    );
  }
}
```

---

## 🍰 FATIA 8: Serviço de API Local

### **Arquivo:** `lib/data/services/impressao_api_service.dart`

```dart
import 'package:flutter/foundation.dart';
import '../../core/printing/print_config.dart';
import '../../core/printing/print_data.dart';
import '../../core/printing/nfce_print_data.dart';
import '../../core/network/api_client.dart';
import '../models/impressao_enqueue_request.dart';

/// Serviço para comunicação com API Local
class ImpressaoApiService {
  final ApiClient _apiClient;
  
  ImpressaoApiService(this._apiClient);
  
  /// Enfileira impressão na API Local
  Future<ImpressaoEnqueueResponse> enfileirarImpressao({
    required String impressoraId,
    required DocumentType tipoDocumento,
    required dynamic dadosFormatados, // PrintData ou NfcePrintData
    String? pedidoId,
    String? itemPedidoId,
  }) async {
    try {
      final request = ImpressaoEnqueueRequest(
        impressoraId: impressoraId,
        tipoDocumento: tipoDocumento.name,
        dadosFormatados: _serializarDados(dadosFormatados),
        pedidoId: pedidoId,
        itemPedidoId: itemPedidoId,
      );
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/impressao/enfileirar',
        data: request.toJson(),
      );
      
      if (response.data == null) {
        return ImpressaoEnqueueResponse(
          success: false,
          errorMessage: 'Erro ao enfileirar impressão',
        );
      }
      
      final data = response.data!;
      return ImpressaoEnqueueResponse(
        success: data['success'] as bool? ?? false,
        impressaoId: data['impressaoId'] as String?,
        errorMessage: data['errorMessage'] as String?,
      );
    } catch (e) {
      debugPrint('❌ Erro ao enfileirar impressão: $e');
      return ImpressaoEnqueueResponse(
        success: false,
        errorMessage: 'Erro: ${e.toString()}',
      );
    }
  }
  
  Map<String, dynamic> _serializarDados(dynamic dados) {
    if (dados is PrintData) {
      return dados.toJson();
    } else if (dados is NfcePrintData) {
      return dados.toJson();
    }
    throw Exception('Tipo de dados não suportado');
  }
}

class ImpressaoEnqueueResponse {
  final bool success;
  final String? impressaoId;
  final String? errorMessage;
  
  ImpressaoEnqueueResponse({
    required this.success,
    this.impressaoId,
    this.errorMessage,
  });
}
```

---

## 🍰 FATIA 9: Modelo de Request

### **Arquivo:** `lib/data/models/impressao_enqueue_request.dart`

```dart
/// Request para enfileirar impressão
class ImpressaoEnqueueRequest {
  final String impressoraId;
  final String tipoDocumento;
  final Map<String, dynamic> dadosFormatados;
  final String? pedidoId;
  final String? itemPedidoId;
  
  ImpressaoEnqueueRequest({
    required this.impressoraId,
    required this.tipoDocumento,
    required this.dadosFormatados,
    this.pedidoId,
    this.itemPedidoId,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'impressoraId': impressoraId,
      'tipoDocumento': tipoDocumento,
      'dadosFormatados': dadosFormatados,
      if (pedidoId != null) 'pedidoId': pedidoId,
      if (itemPedidoId != null) 'itemPedidoId': itemPedidoId,
    };
  }
}
```

---

## 📋 Ordem de Implementação

### **Fase 1: Modelos (FATIAS 1, 2, 9)**
1. ✅ FATIA 1: Modelo de Configuração Local
2. ✅ FATIA 2: DTO de Impressora
3. ✅ FATIA 9: Modelo de Request

### **Fase 2: Repositório (FATIA 3)**
4. ✅ FATIA 3: Repositório de Configuração

### **Fase 3: Serviços (FATIAS 4, 5, 6, 8)**
5. ✅ FATIA 4: Serviço de Impressoras
6. ✅ FATIA 8: Serviço de API Local
7. ✅ FATIA 6: PrintService Estendido
8. ✅ FATIA 5: Serviço de Impressão de Pedidos

### **Fase 4: Formatadores (FATIA 7)**
9. ✅ FATIA 7: Formatador de Dados

---

## ✅ Resumo

**Cada fatia é:**
- ✅ Um arquivo único
- ✅ Responsabilidade clara
- ✅ Testável isoladamente
- ✅ Fácil de entender

**Ordem:**
1. Modelos (dados)
2. Repositório (armazenamento)
3. Serviços (lógica)
4. Formatadores (formatação)

**Pronto para implementar!** 🎯

