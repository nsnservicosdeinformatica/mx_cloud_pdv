# 🖨️ Configuração de Impressoras: No PDV

## 🎯 Decisão: Interface no PDV (Flutter)

**Por que faz mais sentido:**
- ✅ Usuário já está no PDV
- ✅ Não precisa abrir navegador
- ✅ Mais integrado e prático
- ✅ Interface nativa (melhor UX)

---

## 🏗️ Estrutura

### **API Local: Apenas Endpoints**

```
API Local expõe apenas APIs REST:
  - POST /api/impressoras/descobrir
  - GET /api/impressoras/retaguarda
  - GET /api/impressoras/mapeamentos
  - POST /api/impressoras/mapear
  - DELETE /api/impressoras/mapear/{id}
  - POST /api/impressoras/testar/{id}
```

### **PDV: Interface Completa**

```
PDV (Flutter) tem tela de configuração:
  - Tela: "Configurar Impressoras da API Local"
  - Acessível do menu principal
  - Consome APIs da API Local
```

---

## 🎨 Interface no PDV

### **Tela: Configurar Impressoras da API Local**

```
┌─────────────────────────────────────────┐
│  ← Configurar Impressoras (API Local)   │
├─────────────────────────────────────────┤
│                                         │
│  Impressoras do Retaguarda:              │
│  ┌─────────────────────────────────┐  │
│  │ 📋 Cozinha                       │  │
│  │ 📋 Bar                           │  │
│  │ 📋 Cupom Fiscal                  │  │
│  └─────────────────────────────────┘  │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  [Buscar Impressoras na Rede]           │
│                                         │
│  Impressoras Encontradas:               │
│  ┌─────────────────────────────────┐  │
│  │ 📡 EPSON TM20                    │  │
│  │    Network - 192.168.1.100:9100 │  │
│  │    [Mapear para "Cozinha"]      │  │
│  │                                  │  │
│  │ 📡 Bematech MP-4200              │  │
│  │    Network - 192.168.1.101:9100 │  │
│  │    [Mapear para "Bar"]          │  │
│  └─────────────────────────────────┘  │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  Mapeamentos Configurados:              │
│  ┌─────────────────────────────────┐  │
│  │ 📋 Cozinha                       │  │
│  │    → EPSON TM20                 │  │
│  │    192.168.1.100:9100            │  │
│  │    [Testar] [Remover]            │  │
│  │                                  │  │
│  │ 📋 Bar                           │  │
│  │    → Bematech MP-4200            │  │
│  │    192.168.1.101:9100            │  │
│  │    [Testar] [Remover]            │  │
│  └─────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

---

## 🔧 Implementação

### **1. Serviço de API Local (PDV)**

```dart
// lib/data/services/impressora_api_local_service.dart

class ImpressoraApiLocalService {
  final ApiClient _apiLocalClient;
  
  ImpressoraApiLocalService(this._apiLocalClient);
  
  /// Descobre impressoras disponíveis
  Future<ImpressorasDescobertasDto> descobrirImpressoras() async {
    final response = await _apiLocalClient.post<Map<String, dynamic>>(
      '/impressoras/descobrir',
    );
    
    return ImpressorasDescobertasDto.fromJson(response.data!);
  }
  
  /// Lista impressoras do retaguarda
  Future<List<ImpressoraDto>> listarImpressorasRetaguarda() async {
    final response = await _apiLocalClient.get<List<dynamic>>(
      '/impressoras/retaguarda',
    );
    
    return response.data!
        .map((e) => ImpressoraDto.fromJson(e))
        .toList();
  }
  
  /// Lista mapeamentos configurados
  Future<List<ImpressoraMapeamentoDto>> listarMapeamentos() async {
    final response = await _apiLocalClient.get<List<dynamic>>(
      '/impressoras/mapeamentos',
    );
    
    return response.data!
        .map((e) => ImpressoraMapeamentoDto.fromJson(e))
        .toList();
  }
  
  /// Mapeia impressora
  Future<bool> mapearImpressora(MapearImpressoraRequest request) async {
    final response = await _apiLocalClient.post<Map<String, dynamic>>(
      '/impressoras/mapear',
      data: request.toJson(),
    );
    
    return response.data!['success'] as bool? ?? false;
  }
  
  /// Remove mapeamento
  Future<bool> removerMapeamento(String impressoraId) async {
    final response = await _apiLocalClient.delete<Map<String, dynamic>>(
      '/impressoras/mapear/$impressoraId',
    );
    
    return response.data!['success'] as bool? ?? false;
  }
  
  /// Testa impressão
  Future<bool> testarImpressao(String impressoraId) async {
    final response = await _apiLocalClient.post<Map<String, dynamic>>(
      '/impressoras/testar/$impressoraId',
    );
    
    return response.data!['success'] as bool? ?? false;
  }
}
```

---

### **2. Tela de Configuração (Flutter)**

```dart
// lib/screens/configuracao/configurar_impressoras_api_local_screen.dart

class ConfigurarImpressorasApiLocalScreen extends StatefulWidget {
  @override
  State<ConfigurarImpressorasApiLocalScreen> createState() =>
      _ConfigurarImpressorasApiLocalScreenState();
}

class _ConfigurarImpressorasApiLocalScreenState
    extends State<ConfigurarImpressorasApiLocalScreen> {
  final ImpressoraApiLocalService _apiLocalService;
  List<ImpressoraDto> _impressorasRetaguarda = [];
  List<ImpressoraDescobertaDto> _impressorasDescobertas = [];
  List<ImpressoraMapeamentoDto> _mapeamentos = [];
  bool _carregando = false;
  
  @override
  void initState() {
    super.initState();
    _carregarDados();
  }
  
  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    
    try {
      _impressorasRetaguarda = await _apiLocalService.listarImpressorasRetaguarda();
      _mapeamentos = await _apiLocalService.listarMapeamentos();
    } catch (e) {
      AppToast.showError(context, 'Erro ao carregar dados: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }
  
  Future<void> _descobrirImpressoras() async {
    setState(() => _carregando = true);
    
    try {
      final resultado = await _apiLocalService.descobrirImpressoras();
      setState(() {
        _impressorasDescobertas = [
          ...resultado.rede,
          ...resultado.usb,
          ...resultado.bluetooth,
        ];
      });
    } catch (e) {
      AppToast.showError(context, 'Erro ao descobrir: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }
  
  Future<void> _mapearImpressora(
    ImpressoraDescobertaDto descoberta,
  ) async {
    // Mostra dialog para selecionar impressora do retaguarda
    final impressoraSelecionada = await _mostrarDialogSelecionarImpressora();
    if (impressoraSelecionada == null) return;
    
    try {
      final request = MapearImpressoraRequest(
        impressoraId: impressoraSelecionada.id,
        tipoPeriferico: descoberta.tipo,
        identificador: descoberta.identificador,
        porta: descoberta.porta,
      );
      
      final sucesso = await _apiLocalService.mapearImpressora(request);
      
      if (sucesso) {
        AppToast.showSuccess(context, 'Mapeamento salvo!');
        await _carregarDados();
      } else {
        AppToast.showError(context, 'Erro ao salvar mapeamento');
      }
    } catch (e) {
      AppToast.showError(context, 'Erro: $e');
    }
  }
  
  Future<ImpressoraDto?> _mostrarDialogSelecionarImpressora() async {
    return await showDialog<ImpressoraDto>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Selecionar Impressora'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _impressorasRetaguarda.length,
            itemBuilder: (context, index) {
              final impressora = _impressorasRetaguarda[index];
              return ListTile(
                title: Text(impressora.nome),
                onTap: () => Navigator.pop(context, impressora),
              );
            },
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configurar Impressoras (API Local)'),
      ),
      body: _carregando
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Seção: Impressoras do Retaguarda
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Impressoras do Retaguarda',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          SizedBox(height: 8),
                          ..._impressorasRetaguarda.map((imp) => ListTile(
                                leading: Icon(Icons.print),
                                title: Text(imp.nome),
                                subtitle: Text(imp.id),
                              )),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Botão: Descobrir
                  ElevatedButton.icon(
                    onPressed: _descobrirImpressoras,
                    icon: Icon(Icons.search),
                    label: Text('Buscar Impressoras na Rede'),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Seção: Impressoras Descobertas
                  if (_impressorasDescobertas.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Impressoras Encontradas',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            SizedBox(height: 8),
                            ..._impressorasDescobertas.map((imp) => ListTile(
                                  leading: Icon(_getIconTipo(imp.tipo)),
                                  title: Text(imp.nome ?? imp.identificador),
                                  subtitle: Text(
                                    '${imp.tipo} - ${imp.identificador}${imp.porta != null ? ':${imp.porta}' : ''}',
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () => _mapearImpressora(imp),
                                    child: Text('Mapear'),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  
                  // Seção: Mapeamentos
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mapeamentos Configurados',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          SizedBox(height: 8),
                          ..._mapeamentos.map((map) => Card(
                                child: ListTile(
                                  leading: Icon(Icons.print),
                                  title: Text(map.impressoraNome),
                                  subtitle: Text(
                                    '${map.tipoPeriferico}: ${map.identificador}${map.porta != null ? ':${map.porta}' : ''}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.play_arrow),
                                        onPressed: () => _testarImpressao(map.impressoraId),
                                        tooltip: 'Testar',
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete),
                                        onPressed: () => _removerMapeamento(map.impressoraId),
                                        tooltip: 'Remover',
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  IconData _getIconTipo(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'network':
        return Icons.wifi;
      case 'usb':
        return Icons.usb;
      case 'bluetooth':
        return Icons.bluetooth;
      default:
        return Icons.print;
    }
  }
  
  Future<void> _testarImpressao(String impressoraId) async {
    try {
      final sucesso = await _apiLocalService.testarImpressao(impressoraId);
      if (sucesso) {
        AppToast.showSuccess(context, 'Teste de impressão enviado!');
      } else {
        AppToast.showError(context, 'Erro ao testar impressão');
      }
    } catch (e) {
      AppToast.showError(context, 'Erro: $e');
    }
  }
  
  Future<void> _removerMapeamento(String impressoraId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remover Mapeamento'),
        content: Text('Deseja remover este mapeamento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remover'),
          ),
        ],
      ),
    );
    
    if (confirmar != true) return;
    
    try {
      final sucesso = await _apiLocalService.removerMapeamento(impressoraId);
      if (sucesso) {
        AppToast.showSuccess(context, 'Mapeamento removido!');
        await _carregarDados();
      } else {
        AppToast.showError(context, 'Erro ao remover');
      }
    } catch (e) {
      AppToast.showError(context, 'Erro: $e');
    }
  }
}
```

---

### **3. Menu Principal (Acesso)**

```dart
// lib/screens/home/home_screen.dart

// Adicionar item no menu:
ListTile(
  leading: Icon(Icons.settings),
  title: Text('Configurações'),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ConfiguracoesScreen(),
    ),
  ),
),

// Em ConfiguracoesScreen:
ListTile(
  leading: Icon(Icons.print),
  title: Text('Impressoras da API Local'),
  subtitle: Text('Configurar mapeamento de impressoras'),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ConfigurarImpressorasApiLocalScreen(),
    ),
  ),
),
```

---

## ✅ Vantagens

### **No PDV:**
- ✅ Usuário já está no app
- ✅ Interface nativa (melhor UX)
- ✅ Não precisa abrir navegador
- ✅ Mais integrado
- ✅ Funciona offline (se já carregou dados)

### **API Local:**
- ✅ Apenas endpoints REST (simples)
- ✅ Não precisa servir HTML/CSS/JS
- ✅ Foco em lógica de negócio

---

## 🔄 Fluxo Completo

```
1. Usuário abre PDV
   ↓
2. Menu → Configurações → Impressoras da API Local
   ↓
3. PDV carrega:
   - Impressoras do retaguarda (via API Local)
   - Mapeamentos existentes (via API Local)
   ↓
4. Usuário clica: "Buscar Impressoras na Rede"
   ↓
5. PDV chama: POST /api/impressoras/descobrir
   ↓
6. API Local descobre e retorna
   ↓
7. PDV mostra impressoras encontradas
   ↓
8. Usuário mapeia: Cozinha → EPSON TM20
   ↓
9. PDV chama: POST /api/impressoras/mapear
   ↓
10. API Local salva mapeamento
```

---

## 📋 Resumo

### **API Local:**
- ✅ Apenas endpoints REST
- ✅ Não serve interface web

### **PDV:**
- ✅ Tela completa de configuração
- ✅ Consome APIs da API Local
- ✅ Interface nativa (Flutter)

**Muito mais prático e integrado!** 🎯

