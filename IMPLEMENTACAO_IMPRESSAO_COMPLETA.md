# 🖨️ Implementação Completa: Sistema de Impressão

## 🎯 Objetivo

Integrar o novo sistema de impressão com a estrutura existente, mantendo compatibilidade com flavors e adicionando:
- Configuração local por tipo de documento
- Decisão automática de modo (integra, bluetooth, fila)
- Formatação de dados no PDV
- Envio para fila quando necessário

---

## 📁 Estrutura de Arquivos

```
lib/
├── core/
│   └── printing/
│       ├── print_service.dart (atualizado)
│       ├── print_config.dart (atualizado)
│       ├── print_provider.dart (mantido)
│       ├── print_data.dart (mantido)
│       ├── nfce_print_data.dart (mantido)
│       ├── impressao_config_local.dart (NOVO)
│       ├── impressao_decisor.dart (NOVO)
│       └── impressao_formatter.dart (NOVO)
│
├── data/
│   ├── repositories/
│   │   └── impressao_config_repository.dart (NOVO)
│   ├── services/
│   │   └── impressao_api_service.dart (NOVO)
│   └── models/
│       └── impressao_enqueue_request.dart (NOVO)
│
└── screens/
    └── configuracao/
        └── configurar_impressao_screen.dart (NOVO)
```

---

## 🔧 Implementação Detalhada

### **1. Modelos de Dados (Hive)**

```dart
// lib/core/printing/impressao_config_local.dart

import 'package:hive/hive.dart';
import 'print_config.dart';

part 'impressao_config_local.g.dart';

@HiveType(typeId: 21)
class ConfiguracaoImpressaoLocal extends HiveObject {
  @HiveField(0)
  Map<String, ConfiguracaoDocumentoImpressao> configuracoes;
  
  @HiveField(1)
  DateTime atualizadoEm;
  
  ConfiguracaoImpressaoLocal({
    required this.configuracoes,
    required this.atualizadoEm,
  });
  
  factory ConfiguracaoImpressaoLocal.empty() {
    return ConfiguracaoImpressaoLocal(
      configuracoes: {},
      atualizadoEm: DateTime.now(),
    );
  }
  
  ConfiguracaoDocumentoImpressao? getConfig(DocumentType tipo) {
    return configuracoes[tipo.name];
  }
  
  void setConfig(DocumentType tipo, ConfiguracaoDocumentoImpressao config) {
    configuracoes[tipo.name] = config;
    atualizadoEm = DateTime.now();
  }
}

@HiveType(typeId: 22)
class ConfiguracaoDocumentoImpressao extends HiveObject {
  @HiveField(0)
  String tipoDocumento; // DocumentType.name
  
  @HiveField(1)
  int modo; // ModoImpressaoLocal.index
  
  @HiveField(2)
  String? impressoraId; // UUID ou "INTEGRADA"
  
  @HiveField(3)
  ImpressoraConexaoLocal? conexaoLocal;
  
  @HiveField(4)
  bool imprimirAutomaticamente;
  
  ConfiguracaoDocumentoImpressao({
    required this.tipoDocumento,
    required this.modo,
    this.impressoraId,
    this.conexaoLocal,
    this.imprimirAutomaticamente = true,
  });
  
  ModoImpressaoLocal get modoEnum => ModoImpressaoLocal.values[modo];
  DocumentType get tipoDocumentoEnum => 
      DocumentType.values.firstWhere((e) => e.name == tipoDocumento);
}

enum ModoImpressaoLocal {
  integrada,        // Impressora integrada (POS)
  bluetoothLocal,   // Bluetooth/USB conectado no dispositivo
  apiLocal,        // Via API Local (fila)
}

@HiveType(typeId: 23)
class ImpressoraConexaoLocal extends HiveObject {
  @HiveField(0)
  int tipoConexao; // TipoConexaoImpressora.index
  
  @HiveField(1)
  String identificador; // MAC, IP, nome
  
  @HiveField(2)
  String? providerKey; // "bluetooth_thermal", "wifi_thermal"
  
  @HiveField(3)
  String? configuracaoJson; // Config específica
  
  ImpressoraConexaoLocal({
    required this.tipoConexao,
    required this.identificador,
    this.providerKey,
    this.configuracaoJson,
  });
  
  TipoConexaoImpressora get tipoConexaoEnum => 
      TipoConexaoImpressora.values[tipoConexao];
}

enum TipoConexaoImpressora {
  bluetooth,
  wifi,
  usb,
  network,
}

// Constantes
class ImpressoraEspecial {
  static const String IMPRESSORA_INTEGRADA_ID = "INTEGRADA";
  static const String IMPRESSORA_INTEGRADA_NOME = "Impressora Integrada";
}
```

---

### **2. Repositório de Configuração Local**

```dart
// lib/data/repositories/impressao_config_repository.dart

import 'package:hive/hive.dart';
import '../../core/printing/impressao_config_local.dart';
import '../../core/printing/print_config.dart';

class ImpressaoConfigRepository {
  static const String boxName = 'impressao_config';
  late Box<ConfiguracaoImpressaoLocal> _box;
  
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(21)) {
      Hive.registerAdapter(ConfiguracaoImpressaoLocalAdapter());
    }
    if (!Hive.isAdapterRegistered(22)) {
      Hive.registerAdapter(ConfiguracaoDocumentoImpressaoAdapter());
    }
    if (!Hive.isAdapterRegistered(23)) {
      Hive.registerAdapter(ImpressoraConexaoLocalAdapter());
    }
    
    _box = await Hive.openBox<ConfiguracaoImpressaoLocal>(boxName);
  }
  
  Future<ConfiguracaoImpressaoLocal?> get() async {
    return _box.get('config');
  }
  
  Future<void> save(ConfiguracaoImpressaoLocal config) async {
    await _box.put('config', config);
  }
  
  Future<ConfiguracaoDocumentoImpressao?> getConfig(DocumentType tipo) async {
    final configGeral = await get();
    return configGeral?.getConfig(tipo);
  }
  
  Future<void> setConfig(
    DocumentType tipo,
    ConfiguracaoDocumentoImpressao config,
  ) async {
    final configGeral = await get() ?? ConfiguracaoImpressaoLocal.empty();
    configGeral.setConfig(tipo, config);
    await save(configGeral);
  }
}
```

---

### **3. Serviço de API Local (Fila)**

```dart
// lib/data/services/impressao_api_service.dart

import 'package:flutter/foundation.dart';
import '../../core/printing/print_config.dart';
import '../../core/printing/print_data.dart';
import '../../core/printing/nfce_print_data.dart';
import '../../core/network/api_client.dart';
import '../models/impressao_enqueue_request.dart';

class ImpressaoApiService {
  final ApiClient? _apiLocalClient;
  
  ImpressaoApiService(this._apiLocalClient);
  
  /// Enfileira impressão na API Local
  Future<ImpressaoEnqueueResponse> enfileirarImpressao({
    required String impressoraId,
    required DocumentType tipoDocumento,
    required dynamic dadosFormatados, // PrintData ou NfcePrintData
    String? pedidoId,
    String? itemPedidoId,
  }) async {
    if (_apiLocalClient == null) {
      return ImpressaoEnqueueResponse(
        success: false,
        errorMessage: 'API Local não configurada',
      );
    }
    
    try {
      final request = ImpressaoEnqueueRequest(
        impressoraId: impressoraId,
        tipoDocumento: tipoDocumento.name,
        dadosFormatados: _serializarDados(dadosFormatados),
        pedidoId: pedidoId,
        itemPedidoId: itemPedidoId,
      );
      
      final response = await _apiLocalClient!.post<Map<String, dynamic>>(
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

### **4. Modelo de Request**

```dart
// lib/data/models/impressao_enqueue_request.dart

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

### **5. Decisor de Impressão**

```dart
// lib/core/printing/impressao_decisor.dart

import 'package:flutter/foundation.dart';
import '../config/flavor_config.dart';
import 'impressao_config_local.dart';
import '../data/repositories/impressao_config_repository.dart';

class ImpressaoDecisor {
  final ImpressaoConfigRepository _configRepository;
  
  ImpressaoDecisor(this._configRepository);
  
  /// Decide modo de impressão para uma impressora
  Future<ModoImpressaoLocal> decidirModo({
    required String impressoraId,
  }) async {
    // CASO 1: Impressora Integrada
    if (impressoraId == ImpressoraEspecial.IMPRESSORA_INTEGRADA_ID) {
      if (!FlavorConfig.isStoneP2) {
        throw Exception('Impressora integrada não disponível neste dispositivo');
      }
      return ModoImpressaoLocal.integrada;
    }
    
    // CASO 2: POS com impressora externa
    if (FlavorConfig.isStoneP2) {
      // POS sempre usa fila para impressoras externas
      return ModoImpressaoLocal.apiLocal;
    }
    
    // CASO 3: Mobile - verifica configuração local
    final configLocal = await _configRepository.get();
    if (configLocal != null) {
      // Verifica se tem config para esta impressora
      final configDoc = configLocal.configuracoes.values.firstWhere(
        (c) => c.impressoraId == impressoraId,
        orElse: () => throw Exception('Configuração não encontrada'),
      );
      
      return configDoc.modoEnum;
    }
    
    // Fallback: API Local (se configurado)
    return ModoImpressaoLocal.apiLocal;
  }
  
  /// Busca configuração local para tipo de documento
  Future<ConfiguracaoDocumentoImpressao?> getConfigLocal(
    DocumentType tipoDocumento,
  ) async {
    return await _configRepository.getConfig(tipoDocumento);
  }
}
```

---

### **6. Formatador de Dados**

```dart
// lib/core/printing/impressao_formatter.dart

import 'print_data.dart';
import 'nfce_print_data.dart';
import '../data/models/core/pedido_dto.dart';
import '../data/models/core/item_pedido_dto.dart';

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
  
  /// Formata parcial de venda
  static PrintData formatarParcialVenda({
    required PedidoDto pedido,
    required double valorPago,
  }) {
    return PrintData(
      header: PrintHeader(
        titulo: 'PAGAMENTO PARCIAL',
        numero: pedido.numero,
        data: DateTime.now(),
      ),
      entityInfo: PrintEntityInfo(
        tipo: pedido.mesaNome != null ? 'Mesa' : 'Comanda',
        nome: pedido.mesaNome ?? pedido.comandaNumero ?? '',
      ),
      items: [],
      totals: PrintTotals(
        total: pedido.valorTotal,
        valorPago: valorPago,
        troco: valorPago - pedido.valorTotal,
      ),
      footer: PrintFooter(
        mensagem: 'Pagamento parcial registrado',
      ),
    );
  }
}
```

---

### **7. PrintService Atualizado**

```dart
// lib/core/printing/print_service.dart (ATUALIZADO)

import 'package:flutter/foundation.dart';
import 'print_config.dart';
import 'print_data.dart';
import 'nfce_print_data.dart';
import 'print_provider.dart';
import 'impressao_config_local.dart';
import 'impressao_decisor.dart';
import 'impressao_formatter.dart';
import '../config/flavor_config.dart';
import '../data/adapters/printing/print_provider_registry.dart';
import '../data/repositories/impressao_config_repository.dart';
import '../data/services/impressao_api_service.dart';

class PrintService {
  PrintConfig? _config;
  static PrintService? _instance;
  
  final ImpressaoConfigRepository _configRepository;
  final ImpressaoDecisor _decisor;
  final ImpressaoApiService? _apiService;
  
  static Future<PrintService> getInstance({
    ImpressaoConfigRepository? configRepository,
    ImpressaoApiService? apiService,
  }) async {
    _instance ??= PrintService._(
      configRepository: configRepository,
      apiService: apiService,
    );
    await _instance!._initialize();
    return _instance!;
  }
  
  PrintService._({
    ImpressaoConfigRepository? configRepository,
    ImpressaoApiService? apiService,
  }) : _configRepository = configRepository ?? ImpressaoConfigRepository(),
       _decisor = ImpressaoDecisor(configRepository ?? ImpressaoConfigRepository()),
       _apiService = apiService;
  
  Future<void> _initialize() async {
    await _configRepository.init();
    _config = await PrintConfig.load();
    await PrintProviderRegistry.registerAll(_config!);
  }
  
  /// Imprime documento usando configuração local ou padrão
  Future<PrintResult> imprimir({
    required DocumentType tipoDocumento,
    required dynamic dadosFormatados, // PrintData ou NfcePrintData
    String? impressoraId, // Se especificado, sobrescreve config
    String? produtoId, // Para comanda de produto
  }) async {
    try {
      // 1. Busca configuração local
      final configLocal = await _decisor.getConfigLocal(tipoDocumento);
      
      // 2. Decide impressora
      String? finalImpressoraId = impressoraId;
      
      if (finalImpressoraId == null) {
        if (configLocal != null) {
          finalImpressoraId = configLocal.impressoraId;
        } else {
          // Busca do retaguarda (fallback)
          finalImpressoraId = await _buscarImpressoraPadrao(
            tipoDocumento: tipoDocumento,
            produtoId: produtoId,
          );
        }
      }
      
      if (finalImpressoraId == null) {
        return PrintResult(
          success: false,
          errorMessage: 'Impressora não configurada',
        );
      }
      
      // 3. Decide modo
      ModoImpressaoLocal modo;
      if (configLocal != null) {
        modo = configLocal.modoEnum;
      } else {
        modo = await _decisor.decidirModo(impressoraId: finalImpressoraId);
      }
      
      // 4. Executa impressão
      return await _executarImpressao(
        modo: modo,
        impressoraId: finalImpressoraId,
        tipoDocumento: tipoDocumento,
        dadosFormatados: dadosFormatados,
        configLocal: configLocal,
      );
    } catch (e) {
      return PrintResult(
        success: false,
        errorMessage: 'Erro ao imprimir: ${e.toString()}',
      );
    }
  }
  
  /// Executa impressão baseado no modo
  Future<PrintResult> _executarImpressao({
    required ModoImpressaoLocal modo,
    required String impressoraId,
    required DocumentType tipoDocumento,
    required dynamic dadosFormatados,
    ConfiguracaoDocumentoImpressao? configLocal,
  }) async {
    switch (modo) {
      case ModoImpressaoLocal.integrada:
        return await _imprimirIntegrada(tipoDocumento, dadosFormatados);
        
      case ModoImpressaoLocal.bluetoothLocal:
        if (configLocal?.conexaoLocal == null) {
          return PrintResult(
            success: false,
            errorMessage: 'Conexão local não configurada',
          );
        }
        return await _imprimirBluetoothLocal(
          conexaoLocal: configLocal!.conexaoLocal!,
          tipoDocumento: tipoDocumento,
          dadosFormatados: dadosFormatados,
        );
        
      case ModoImpressaoLocal.apiLocal:
        return await _enviarParaFila(
          impressoraId: impressoraId,
          tipoDocumento: tipoDocumento,
          dadosFormatados: dadosFormatados,
        );
    }
  }
  
  /// Impressão na integrada (POS)
  Future<PrintResult> _imprimirIntegrada(
    DocumentType tipoDocumento,
    dynamic dadosFormatados,
  ) async {
    if (!FlavorConfig.isStoneP2) {
      return PrintResult(
        success: false,
        errorMessage: 'Impressora integrada não disponível',
      );
    }
    
    final provider = await getProvider('stone_thermal');
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
  
  /// Impressão Bluetooth direta
  Future<PrintResult> _imprimirBluetoothLocal({
    required ImpressoraConexaoLocal conexaoLocal,
    required DocumentType tipoDocumento,
    required dynamic dadosFormatados,
  }) async {
    // TODO: Implementar providers Bluetooth/WiFi/USB
    // Por enquanto, retorna erro
    return PrintResult(
      success: false,
      errorMessage: 'Impressão Bluetooth local ainda não implementada',
    );
  }
  
  /// Envia para fila (API Local)
  Future<PrintResult> _enviarParaFila({
    required String impressoraId,
    required DocumentType tipoDocumento,
    required dynamic dadosFormatados,
  }) async {
    if (_apiService == null) {
      return PrintResult(
        success: false,
        errorMessage: 'API Local não configurada',
      );
    }
    
    final response = await _apiService!.enfileirarImpressao(
      impressoraId: impressoraId,
      tipoDocumento: tipoDocumento,
      dadosFormatados: dadosFormatados,
    );
    
    return PrintResult(
      success: response.success,
      errorMessage: response.errorMessage,
      printJobId: response.impressaoId,
    );
  }
  
  /// Busca impressora padrão (retaguarda)
  Future<String?> _buscarImpressoraPadrao({
    required DocumentType tipoDocumento,
    String? produtoId,
  }) async {
    // TODO: Implementar busca no retaguarda
    // Por enquanto, retorna null
    return null;
  }
  
  // Mantém métodos antigos para compatibilidade
  Future<PrintResult> printDocument({
    required DocumentType documentType,
    required PrintData data,
    String? providerKey,
    OutputStrategy? outputStrategy,
  }) async {
    // Usa novo sistema
    return await imprimir(
      tipoDocumento: documentType,
      dadosFormatados: data,
    );
  }
  
  Future<PrintResult> printNfce({
    required NfcePrintData data,
    String? providerKey,
    OutputStrategy? outputStrategy,
  }) async {
    // Usa novo sistema
    return await imprimir(
      tipoDocumento: DocumentType.nfce,
      dadosFormatados: data,
    );
  }
  
  Future<PrintProvider?> getProvider(String providerKey) async {
    final settings = _config?.providerSettings?[providerKey];
    return PrintProviderRegistry.getProvider(providerKey, settings: settings);
  }
}
```

---

## 🔄 Fluxo Completo de Uso

### **Exemplo: Imprimir Comanda de Produto**

```dart
// No código que cria pedido
final printService = await PrintService.getInstance();

// Formata dados
final dadosFormatados = ImpressaoFormatter.formatarComandaProduto(
  pedido: pedido,
  item: itemPizza,
);

// Imprime (usa configuração local automaticamente)
final resultado = await printService.imprimir(
  tipoDocumento: DocumentType.comandaProduto,
  dadosFormatados: dadosFormatados,
  produtoId: itemPizza.produtoId, // Para buscar impressora do produto
);

if (resultado.success) {
  print('Impressão enfileirada: ${resultado.printJobId}');
} else {
  print('Erro: ${resultado.errorMessage}');
}
```

### **Exemplo: Imprimir Cupom Fiscal**

```dart
// No código que finaliza venda
final printService = await PrintService.getInstance();

// Busca dados da NFC-e (já existe)
final dadosNfce = await notaFiscalService.getDadosParaImpressao(notaFiscalId);

// Imprime (usa configuração local)
final resultado = await printService.imprimir(
  tipoDocumento: DocumentType.nfce,
  dadosFormatados: dadosNfce.data!,
);

if (resultado.success) {
  print('Cupom fiscal impresso');
} else {
  print('Erro: ${resultado.errorMessage}');
}
```

---

## ✅ Resumo da Implementação

### **Arquivos Criados/Modificados:**

1. ✅ `impressao_config_local.dart` - Modelos Hive
2. ✅ `impressao_config_repository.dart` - Repositório
3. ✅ `impressao_api_service.dart` - Serviço API Local
4. ✅ `impressao_decisor.dart` - Lógica de decisão
5. ✅ `impressao_formatter.dart` - Formatação de dados
6. ✅ `print_service.dart` - Atualizado com novo sistema
7. ✅ `impressao_enqueue_request.dart` - Modelo de request

### **Compatibilidade:**

- ✅ Mantém métodos antigos (`printDocument`, `printNfce`)
- ✅ Compatível com flavors (Stone P2, Mobile)
- ✅ Usa PrintConfig existente
- ✅ Usa PrintProvider existente

### **Próximos Passos:**

1. Implementar providers Bluetooth/WiFi/USB
2. Implementar busca de impressoras no retaguarda
3. Criar tela de configuração
4. Testar fluxo completo

**Código pronto para implementação!** 🎯

