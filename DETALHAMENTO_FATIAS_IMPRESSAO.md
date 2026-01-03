# 🖨️ Detalhamento Completo: Cada Fatia da Implementação

## 🎯 Objetivo

Explicar em detalhes o que cada fatia faz, por que existe, como funciona e como se conecta com as outras.

---

## 🍰 FATIA 1: Modelo de Configuração Local

### **Arquivo:** `lib/core/printing/models/impressora_config_local.dart`

### **O que faz:**
Define a estrutura de dados que armazena a configuração local de cada impressora no dispositivo (Hive).

### **Por que existe:**
O PDV precisa saber **como conectar** cada impressora. Essa informação é específica do dispositivo e não vem do retaguarda.

### **O que armazena:**
- **impressoraId**: ID da impressora do retaguarda (ex: "imp-cozinha")
- **nome**: Nome da impressora (ex: "Cozinha")
- **tipoConexao**: Como conectar (Integrada, API, Bluetooth)
- **bluetoothMacAddress**: MAC do Bluetooth (se tipo = Bluetooth)
- **apiLocalUrl**: URL da API Local (se tipo = API)

### **Como funciona:**
```dart
// Exemplo de uso:
final config = ConfiguracaoImpressoraLocal.fromEnum(
  impressoraId: "imp-cozinha",
  nome: "Cozinha",
  tipoConexao: TipoConexaoImpressora.api,
  apiLocalUrl: "http://servidor-local:3000",
);

// Salva no Hive
await box.put("imp-cozinha", config);

// Recupera depois
final saved = await box.get("imp-cozinha");
print(saved.tipoConexaoEnum); // TipoConexaoImpressora.api
```

### **Dependências:**
- Hive (armazenamento local)
- Nenhuma outra fatia

### **Responsabilidade:**
- ✅ Definir estrutura de dados
- ✅ Serializar/deserializar para Hive
- ✅ Converter entre enum e int

### **Exemplo Real:**
```
Usuário configura no PDV:
  - Cozinha → Tipo: API Local
  - Bar → Tipo: Bluetooth (MAC: 00:11:22:33:44:55)
  - Cupom Fiscal → Tipo: Impressora Integrada

Isso vira:
  ConfiguracaoImpressoraLocal {
    impressoraId: "imp-cozinha",
    tipoConexao: TipoConexaoImpressora.api,
    apiLocalUrl: "http://servidor-local:3000"
  }
```

---

## 🍰 FATIA 2: DTO de Impressora

### **Arquivo:** `lib/core/printing/models/impressora_dto.dart`

### **O que faz:**
Define a estrutura de dados que representa uma impressora vinda do retaguarda (API).

### **Por que existe:**
O retaguarda retorna impressoras em JSON. Precisamos de um modelo para deserializar e trabalhar com esses dados.

### **O que armazena:**
- **id**: ID único da impressora (ex: "imp-cozinha")
- **nome**: Nome da impressora (ex: "Cozinha")
- **descricao**: Descrição opcional
- **isAtiva**: Se está ativa

### **Como funciona:**
```dart
// Recebe JSON do retaguarda
final json = {
  'id': 'imp-cozinha',
  'nome': 'Cozinha',
  'descricao': 'Impressora da cozinha',
  'isAtiva': true,
};

// Converte para DTO
final impressora = ImpressoraDto.fromJson(json);

// Usa no código
print(impressora.nome); // "Cozinha"

// Combina com config local
final comConfig = ImpressoraComConfigDto(
  impressora: impressora,
  configLocal: configLocal,
);
```

### **Dependências:**
- Nenhuma (é um modelo puro)

### **Responsabilidade:**
- ✅ Deserializar JSON do retaguarda
- ✅ Representar impressora do retaguarda
- ✅ Combinar com config local (ImpressoraComConfigDto)

### **Exemplo Real:**
```
Retaguarda retorna:
  GET /api/impressoras
  Response: [
    { id: "imp-cozinha", nome: "Cozinha" },
    { id: "imp-bar", nome: "Bar" }
  ]

PDV converte para:
  List<ImpressoraDto> = [
    ImpressoraDto(id: "imp-cozinha", nome: "Cozinha"),
    ImpressoraDto(id: "imp-bar", nome: "Bar")
  ]
```

---

## 🍰 FATIA 3: Repositório de Configuração

### **Arquivo:** `lib/core/printing/repositories/impressora_config_repository.dart`

### **O que faz:**
Gerencia o armazenamento e recuperação de configurações locais de impressoras no Hive.

### **Por que existe:**
Precisamos de um lugar centralizado para salvar/recuperar configurações. O repositório abstrai o Hive.

### **O que faz:**
- **init()**: Inicializa o Hive e registra adapters
- **getByImpressoraId()**: Busca config de uma impressora
- **save()**: Salva config de uma impressora
- **delete()**: Remove config de uma impressora
- **getAll()**: Lista todas as configs
- **hasConfig()**: Verifica se tem config

### **Como funciona:**
```dart
// Inicializa (uma vez no início do app)
final repo = ImpressoraConfigRepository();
await repo.init();

// Salva configuração
final config = ConfiguracaoImpressoraLocal.fromEnum(
  impressoraId: "imp-cozinha",
  nome: "Cozinha",
  tipoConexao: TipoConexaoImpressora.api,
);
await repo.save(config);

// Busca depois
final saved = await repo.getByImpressoraId("imp-cozinha");
if (saved != null) {
  print(saved.tipoConexaoEnum); // TipoConexaoImpressora.api
}

// Verifica se tem config
final temConfig = await repo.hasConfig("imp-cozinha");
print(temConfig); // true
```

### **Dependências:**
- FATIA 1 (ConfiguracaoImpressoraLocal)
- Hive

### **Responsabilidade:**
- ✅ Gerenciar armazenamento Hive
- ✅ Abstrair acesso ao banco local
- ✅ Garantir inicialização correta

### **Exemplo Real:**
```
PDV abre tela de configuração:
  1. Busca impressoras do retaguarda
  2. Para cada uma, verifica: repo.hasConfig(impressoraId)
  3. Se não tem → Mostra "Não configurada"
  4. Se tem → Mostra config atual

Usuário configura:
  1. Seleciona tipo de conexão
  2. Preenche dados (MAC, URL, etc)
  3. Salva: repo.save(config)
  4. Config fica salva no Hive
```

---

## 🍰 FATIA 4: Serviço de Impressoras

### **Arquivo:** `lib/core/printing/services/impressora_service.dart`

### **O que faz:**
Comunica com o retaguarda para buscar informações sobre impressoras e produtos.

### **Por que existe:**
O PDV precisa saber:
- Quais impressoras existem (retaguarda)
- Qual impressora usar para cada produto (retaguarda)
- Qual impressora usar para cada documento (retaguarda)

### **O que faz:**
- **buscarImpressoras()**: Busca lista de impressoras do retaguarda
- **buscarImpressorasComConfig()**: Busca impressoras e combina com config local
- **buscarImpressoraProduto()**: Busca qual impressora usar para um produto
- **buscarImpressoraDocumento()**: Busca qual impressora usar para um documento

### **Como funciona:**
```dart
// Busca impressoras do retaguarda
final service = ImpressoraService(
  apiClient: apiClient,
  configRepo: configRepo,
);

// Lista todas as impressoras
final impressoras = await service.buscarImpressoras(
  empresaId: "emp-001",
);
// Retorna: [Cozinha, Bar, Cupom Fiscal]

// Busca com config local
final comConfig = await service.buscarImpressorasComConfig(
  empresaId: "emp-001",
);
// Retorna: [
//   { impressora: Cozinha, configLocal: null, precisaConfigurar: true },
//   { impressora: Bar, configLocal: {...}, precisaConfigurar: false }
// ]

// Busca impressora de um produto
final impressoraId = await service.buscarImpressoraProduto("prod-pizza");
// Retorna: "imp-cozinha"

// Busca impressora de um documento
final impressoraId = await service.buscarImpressoraDocumento("cupomFiscal");
// Retorna: "imp-cupom"
```

### **Dependências:**
- FATIA 2 (ImpressoraDto)
- FATIA 3 (ImpressoraConfigRepository)
- ApiClient (já existe)

### **Responsabilidade:**
- ✅ Comunicar com retaguarda
- ✅ Buscar dados de impressoras
- ✅ Combinar dados do retaguarda com config local

### **Exemplo Real:**
```
PDV precisa imprimir Pizza:
  1. Chama: service.buscarImpressoraProduto("prod-pizza")
  2. Retaguarda retorna: { impressoraId: "imp-cozinha" }
  3. PDV sabe: Pizza vai para "imp-cozinha"

PDV precisa imprimir Cupom Fiscal:
  1. Chama: service.buscarImpressoraDocumento("cupomFiscal")
  2. Retaguarda retorna: { impressoraId: "imp-cupom" }
  3. PDV sabe: Cupom Fiscal vai para "imp-cupom"
```

---

## 🍰 FATIA 5: Serviço de Impressão de Pedidos

### **Arquivo:** `lib/core/printing/services/pedido_impressao_service.dart`

### **O que faz:**
Processa a impressão de todos os itens de um pedido, um por um.

### **Por que existe:**
Quando um pedido é criado, cada produto pode ir para uma impressora diferente. Este serviço coordena isso.

### **O que faz:**
- **processarImpressaoPedido()**: Processa todos os itens do pedido
- **_processarItemPedido()**: Processa um item específico

### **Como funciona:**
```dart
// Processa impressão de um pedido completo
final service = PedidoImpressaoService(
  impressoraService: impressoraService,
  configRepo: configRepo,
  printService: printService,
);

final pedido = PedidoDto(
  itens: [
    ItemPedidoDto(produtoId: "pizza", produtoNome: "Pizza", quantidade: 1),
    ItemPedidoDto(produtoId: "refrigerante", produtoNome: "Refrigerante", quantidade: 2),
  ],
);

final resultado = await service.processarImpressaoPedido(pedido: pedido);

// Resultado:
// {
//   itens: [
//     { produtoNome: "Pizza", sucesso: true, impressora: "Cozinha" },
//     { produtoNome: "Refrigerante", sucesso: true, impressora: "Bar" }
//   ],
//   sucesso: true
// }
```

### **Fluxo Interno:**
```
Para cada item do pedido:
  1. Busca impressora do produto (FATIA 4)
  2. Busca config local da impressora (FATIA 3)
  3. Formata dados (FATIA 7)
  4. Imprime (FATIA 6)
  5. Retorna resultado
```

### **Dependências:**
- FATIA 3 (ImpressoraConfigRepository)
- FATIA 4 (ImpressoraService)
- FATIA 6 (PrintServiceExtended)
- FATIA 7 (ImpressaoFormatter)

### **Responsabilidade:**
- ✅ Coordenar impressão de pedidos
- ✅ Processar cada item individualmente
- ✅ Retornar resultado de cada impressão

### **Exemplo Real:**
```
PDV cria pedido:
  Pedido {
    itens: [
      { produto: Pizza, qtd: 1 },
      { produto: Refrigerante, qtd: 2 }
    ]
  }

Chama: service.processarImpressaoPedido(pedido)

Para Pizza:
  1. Busca: Pizza → imp-cozinha
  2. Config: imp-cozinha → API
  3. Formata: PrintData { Pizza x1 }
  4. Envia: POST /api/impressao/enfileirar

Para Refrigerante:
  1. Busca: Refrigerante → imp-bar
  2. Config: imp-bar → Bluetooth
  3. Formata: PrintData { Refrigerante x2 }
  4. Imprime: Conecta Bluetooth e imprime direto

Retorna: { sucesso: true, itens: [...] }
```

---

## 🍰 FATIA 6: PrintService Estendido

### **Arquivo:** `lib/core/printing/services/print_service_extended.dart`

### **O que faz:**
Executa a impressão baseado no tipo de conexão configurado (Integrada, Bluetooth, API).

### **Por que existe:**
O PrintService original não sabe sobre configuração local. Este serviço estende para usar a nova estrutura.

### **O que faz:**
- **imprimirComTipo()**: Método principal que decide como imprimir
- **_imprimirIntegrada()**: Imprime na impressora integrada (POS)
- **_imprimirBluetooth()**: Imprime via Bluetooth
- **_enviarParaFila()**: Envia para API Local

### **Como funciona:**
```dart
// Recebe config local e dados formatados
final printService = PrintServiceExtended(
  configRepo: configRepo,
  apiService: apiService,
);

final configLocal = ConfiguracaoImpressoraLocal.fromEnum(
  impressoraId: "imp-cozinha",
  nome: "Cozinha",
  tipoConexao: TipoConexaoImpressora.api,
);

final dadosFormatados = PrintData(...);

// Imprime baseado no tipo
final resultado = await printService.imprimirComTipo(
  configLocal: configLocal,
  dadosFormatados: dadosFormatados,
);

// Se tipo = API → Envia para fila
// Se tipo = Bluetooth → Imprime direto
// Se tipo = Integrada → Imprime direto
```

### **Fluxo de Decisão:**
```
imprimirComTipo()
  ↓
Verifica configLocal.tipoConexaoEnum:
  ├─ Integrada → _imprimirIntegrada()
  │   └─ Usa StoneThermalAdapter (se POS)
  │
  ├─ Bluetooth → _imprimirBluetooth()
  │   └─ Conecta Bluetooth e imprime
  │
  └─ API → _enviarParaFila()
      └─ POST /api/impressao/enfileirar
```

### **Dependências:**
- FATIA 1 (ConfiguracaoImpressoraLocal)
- FATIA 3 (ImpressoraConfigRepository)
- FATIA 8 (ImpressaoApiService)
- PrintService original (já existe)
- PrintProviderRegistry (já existe)

### **Responsabilidade:**
- ✅ Decidir como imprimir baseado no tipo
- ✅ Executar impressão direta (integra/bluetooth)
- ✅ Enviar para fila (API)

### **Exemplo Real:**
```
Config: Cozinha → Tipo: API
Dados: PrintData { Pizza x1 }

Chama: printService.imprimirComTipo(...)

Decisão: tipoConexao = API
  → Chama: _enviarParaFila()
  → POST /api/impressao/enfileirar
  → Retorna: { success: true, impressaoId: "..." }
```

---

## 🍰 FATIA 7: Formatador de Dados

### **Arquivo:** `lib/core/printing/formatters/impressao_formatter.dart`

### **O que faz:**
Converte dados do pedido/produto em `PrintData` formatado para impressão.

### **Por que existe:**
Os dados do pedido vêm em formato DTO. Precisamos converter para o formato que as impressoras entendem.

### **O que faz:**
- **formatarComandaProduto()**: Formata comanda de um produto específico
- **formatarComandaPedido()**: Formata comanda completa do pedido

### **Como funciona:**
```dart
// Formata comanda de um produto
final pedido = PedidoDto(
  numero: "123",
  mesaNome: "Mesa 5",
  itens: [...],
);

final item = ItemPedidoDto(
  produtoNome: "Pizza",
  quantidade: 1,
  valorTotal: 25.00,
);

final dadosFormatados = ImpressaoFormatter.formatarComandaProduto(
  pedido: pedido,
  item: item,
);

// Resultado: PrintData {
//   header: { titulo: "COMANDA", numero: "123" },
//   entityInfo: { tipo: "Mesa", nome: "Mesa 5" },
//   items: [ { produtoNome: "Pizza", quantidade: 1 } ],
//   totals: { total: 25.00 }
// }
```

### **Estrutura de PrintData:**
```dart
PrintData {
  header: PrintHeader {
    titulo: "COMANDA",
    numero: "123",
    data: DateTime.now()
  },
  entityInfo: PrintEntityInfo {
    tipo: "Mesa",
    nome: "Mesa 5"
  },
  items: [
    PrintItem {
      produtoNome: "Pizza",
      quantidade: 1,
      valorTotal: 25.00
    }
  ],
  totals: PrintTotals {
    total: 25.00
  },
  footer: PrintFooter {
    mensagem: "Obrigado pela preferência!"
  }
}
```

### **Dependências:**
- PrintData (já existe)
- PedidoDto (já existe)
- ItemPedidoDto (já existe)

### **Responsabilidade:**
- ✅ Converter DTOs para PrintData
- ✅ Formatar dados de forma consistente
- ✅ Garantir que todos os campos necessários estão presentes

### **Exemplo Real:**
```
Pedido criado:
  Pedido {
    numero: "123",
    mesaNome: "Mesa 5",
    itens: [
      { produtoNome: "Pizza", qtd: 1, valor: 25.00 }
    ]
  }

Chama: ImpressaoFormatter.formatarComandaProduto(...)

Resultado: PrintData formatado pronto para impressão
  → Vai para PrintService
  → Vai para Impressora
  → Imprime na impressora física
```

---

## 🍰 FATIA 8: Serviço de API Local

### **Arquivo:** `lib/data/services/impressao_api_service.dart`

### **O que faz:**
Comunica com a API Local para enfileirar impressões.

### **Por que existe:**
Quando o tipo de conexão é "API", o PDV não imprime direto. Envia para a API Local processar.

### **O que faz:**
- **enfileirarImpressao()**: Envia impressão para a fila da API Local

### **Como funciona:**
```dart
// Enfileira impressão na API Local
final apiService = ImpressaoApiService(apiClient);

final resultado = await apiService.enfileirarImpressao(
  impressoraId: "imp-cozinha",
  tipoDocumento: DocumentType.comandaProduto,
  dadosFormatados: PrintData(...),
  pedidoId: "ped-123",
  itemPedidoId: "item-456",
);

// Faz POST /api/impressao/enfileirar
// Body: {
//   impressoraId: "imp-cozinha",
//   tipoDocumento: "comandaProduto",
//   dadosFormatados: { ... },
//   pedidoId: "ped-123",
//   itemPedidoId: "item-456"
// }

// Retorna: { success: true, impressaoId: "imp-789" }
```

### **Fluxo:**
```
enfileirarImpressao()
  ↓
Serializa dadosFormatados para JSON
  ↓
POST /api/impressao/enfileirar
  ↓
API Local recebe e enfileira
  ↓
Retorna { success: true, impressaoId: "..." }
```

### **Dependências:**
- FATIA 9 (ImpressaoEnqueueRequest)
- ApiClient (já existe)
- PrintData (já existe)
- NfcePrintData (já existe)

### **Responsabilidade:**
- ✅ Comunicar com API Local
- ✅ Serializar dados para JSON
- ✅ Enfileirar impressões

### **Exemplo Real:**
```
PDV precisa imprimir Pizza:
  Config: Cozinha → Tipo: API
  Dados: PrintData { Pizza x1 }

Chama: apiService.enfileirarImpressao(...)

Faz: POST http://servidor-local:3000/api/impressao/enfileirar
Body: {
  impressoraId: "imp-cozinha",
  dadosFormatados: { ... }
}

API Local:
  1. Recebe request
  2. Mapeia: imp-cozinha → IP 192.168.1.100
  3. Enfileira: Impressao { ... }
  4. Worker processa e imprime

PDV recebe: { success: true }
```

---

## 🍰 FATIA 9: Modelo de Request

### **Arquivo:** `lib/data/models/impressao_enqueue_request.dart`

### **O que faz:**
Define a estrutura do request que será enviado para a API Local.

### **Por que existe:**
Precisamos de um modelo claro para o que enviamos para a API Local.

### **O que armazena:**
- **impressoraId**: ID da impressora
- **tipoDocumento**: Tipo do documento (comandaProduto, nfce, etc)
- **dadosFormatados**: Dados já formatados (JSON)
- **pedidoId**: ID do pedido (opcional)
- **itemPedidoId**: ID do item (opcional)

### **Como funciona:**
```dart
// Cria request
final request = ImpressaoEnqueueRequest(
  impressoraId: "imp-cozinha",
  tipoDocumento: "comandaProduto",
  dadosFormatados: {
    'header': { 'titulo': 'COMANDA', ... },
    'items': [ ... ],
    ...
  },
  pedidoId: "ped-123",
  itemPedidoId: "item-456",
);

// Converte para JSON
final json = request.toJson();
// {
//   "impressoraId": "imp-cozinha",
//   "tipoDocumento": "comandaProduto",
//   "dadosFormatados": { ... },
//   "pedidoId": "ped-123",
//   "itemPedidoId": "item-456"
// }

// Envia para API
await apiClient.post('/impressao/enfileirar', data: json);
```

### **Dependências:**
- Nenhuma (é um modelo puro)

### **Responsabilidade:**
- ✅ Definir estrutura do request
- ✅ Serializar para JSON
- ✅ Garantir que todos os campos necessários estão presentes

### **Exemplo Real:**
```
PDV precisa enviar impressão para API Local:
  impressoraId: "imp-cozinha"
  dadosFormatados: PrintData { Pizza x1 }

Cria: ImpressaoEnqueueRequest(...)
Converte: toJson()
Envia: POST /api/impressao/enfileirar

API Local recebe JSON e processa
```

---

## 🔗 Como as Fatias se Conectam

### **Fluxo Completo:**

```
1. FATIA 4 (ImpressoraService)
   → Busca impressoras do retaguarda
   → Usa FATIA 2 (ImpressoraDto)
   → Usa FATIA 3 (ImpressoraConfigRepository)

2. FATIA 5 (PedidoImpressaoService)
   → Para cada item do pedido:
     → Usa FATIA 4 para buscar impressora
     → Usa FATIA 3 para buscar config local
     → Usa FATIA 7 para formatar dados
     → Usa FATIA 6 para imprimir

3. FATIA 6 (PrintServiceExtended)
   → Recebe config local (FATIA 1)
   → Decide como imprimir:
     → Se API → Usa FATIA 8
     → Se Bluetooth → Implementa provider
     → Se Integrada → Usa PrintService original

4. FATIA 8 (ImpressaoApiService)
   → Usa FATIA 9 para criar request
   → Envia para API Local
```

---

## ✅ Resumo por Fatia

| Fatia | O que faz | Dependências |
|-------|-----------|--------------|
| **1** | Modelo de config local (Hive) | Nenhuma |
| **2** | DTO de impressora (retaguarda) | Nenhuma |
| **3** | Repositório (Hive) | Fatia 1 |
| **4** | Serviço de impressoras (API) | Fatias 2, 3 |
| **5** | Serviço de impressão de pedidos | Fatias 3, 4, 6, 7 |
| **6** | PrintService estendido | Fatias 1, 3, 8 |
| **7** | Formatador de dados | PrintData (já existe) |
| **8** | Serviço de API Local | Fatia 9 |
| **9** | Modelo de request | Nenhuma |

**Cada fatia tem responsabilidade única e clara!** 🎯

