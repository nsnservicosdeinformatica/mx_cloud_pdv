# 🔧 Configuração de Ambiente e Conexão do PDV

## 🎯 Objetivo

Criar estrutura clara para identificar:
1. **Ambiente**: Produção ou Homologação
2. **Tipo de Conexão**: Servidor Local ou Servidor Remoto

---

## 📊 Estrutura de Configuração

### **1. Modelo de Configuração Unificado**

```dart
// lib/core/config/app_connection_config.dart

@HiveType(typeId: 30)
class AppConnectionConfig extends HiveObject {
  /// Tipo de conexão
  @HiveField(0)
  final int tipoConexao; // TipoConexao.index
  
  /// Ambiente
  @HiveField(1)
  final int ambiente; // Ambiente.index
  
  /// URL do servidor (local ou remoto)
  @HiveField(2)
  final String serverUrl;
  
  /// URL da API Local (se tipoConexao = local)
  @HiveField(3)
  final String? apiLocalUrl;
  
  /// Nome do servidor (para exibição)
  @HiveField(4)
  final String? serverName;
  
  AppConnectionConfig({
    required this.tipoConexao,
    required this.ambiente,
    required this.serverUrl,
    this.apiLocalUrl,
    this.serverName,
  });
  
  TipoConexao get tipoConexaoEnum => TipoConexao.values[tipoConexao];
  Ambiente get ambienteEnum => Ambiente.values[ambiente];
  
  /// Se está conectado ao servidor local
  bool get isLocal => tipoConexaoEnum == TipoConexao.local;
  
  /// Se está conectado ao servidor remoto
  bool get isRemoto => tipoConexaoEnum == TipoConexao.remoto;
  
  /// Se é produção
  bool get isProduction => ambienteEnum == Ambiente.producao;
  
  /// Se é homologação
  bool get isHomologacao => ambienteEnum == Ambiente.homologacao;
}

enum TipoConexao {
  local,   // Servidor Local (na rede)
  remoto,  // Servidor Remoto (nuvem)
}

enum Ambiente {
  producao,    // Produção
  homologacao, // Homologação
}
```

---

## 🔍 Detecção Automática

### **1. Detectar Ambiente pela URL**

```dart
// lib/core/config/ambiente_detector.dart

class AmbienteDetector {
  /// Detecta ambiente baseado na URL
  static Ambiente detectarAmbiente(String serverUrl) {
    final url = serverUrl.toLowerCase();
    
    // Produção
    if (url.contains('api.h4nd.com.br') || 
        url.contains('api.h4nd.com') ||
        url.contains('h4nd.com.br') && !url.contains('hml')) {
      return Ambiente.producao;
    }
    
    // Homologação
    if (url.contains('api-hml.h4nd.com.br') ||
        url.contains('hml') ||
        url.contains('homolog')) {
      return Ambiente.homologacao;
    }
    
    // Se não identificar, assume homologação (mais seguro)
    return Ambiente.homologacao;
  }
  
  /// Detecta tipo de conexão baseado na URL
  static TipoConexao detectarTipoConexao(String serverUrl) {
    final url = serverUrl.toLowerCase();
    
    // Servidor Local (IP local ou localhost)
    if (url.contains('localhost') ||
        url.contains('127.0.0.1') ||
        url.contains('192.168.') ||
        url.contains('10.0.') ||
        url.contains('172.16.') ||
        url.contains('172.17.') ||
        url.contains('172.18.') ||
        url.contains('172.19.') ||
        url.contains('172.20.') ||
        url.contains('172.21.') ||
        url.contains('172.22.') ||
        url.contains('172.23.') ||
        url.contains('172.24.') ||
        url.contains('172.25.') ||
        url.contains('172.26.') ||
        url.contains('172.27.') ||
        url.contains('172.28.') ||
        url.contains('172.29.') ||
        url.contains('172.30.') ||
        url.contains('172.31.')) {
      return TipoConexao.local;
    }
    
    // Servidor Remoto (DNS)
    return TipoConexao.remoto;
  }
}
```

---

## 🔧 Serviço de Configuração

```dart
// lib/core/config/connection_config_service.dart

class ConnectionConfigService {
  static const String _configKey = 'app_connection_config';
  
  /// Carrega configuração salva
  static AppConnectionConfig? loadConfig() {
    final saved = PreferencesService.getString(_configKey);
    if (saved == null) return null;
    
    try {
      final json = jsonDecode(saved) as Map<String, dynamic>;
      return AppConnectionConfig(
        tipoConexao: json['tipoConexao'] as int,
        ambiente: json['ambiente'] as int,
        serverUrl: json['serverUrl'] as String,
        apiLocalUrl: json['apiLocalUrl'] as String?,
        serverName: json['serverName'] as String?,
      );
    } catch (e) {
      return null;
    }
  }
  
  /// Salva configuração
  static Future<bool> saveConfig(AppConnectionConfig config) async {
    final json = {
      'tipoConexao': config.tipoConexao,
      'ambiente': config.ambiente,
      'serverUrl': config.serverUrl,
      'apiLocalUrl': config.apiLocalUrl,
      'serverName': config.serverName,
    };
    
    return await PreferencesService.setString(
      _configKey,
      jsonEncode(json),
    );
  }
  
  /// Configura servidor (detecta automaticamente ambiente e tipo)
  static Future<bool> configurarServidor(String serverUrl) async {
    // Normalizar URL
    String normalizedUrl = serverUrl.trim();
    if (!normalizedUrl.startsWith('http://') && 
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'http://$normalizedUrl';
    }
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }
    
    // Detectar ambiente e tipo
    final ambiente = AmbienteDetector.detectarAmbiente(normalizedUrl);
    final tipoConexao = AmbienteDetector.detectarTipoConexao(normalizedUrl);
    
    // Criar configuração
    final config = AppConnectionConfig(
      tipoConexao: tipoConexao.index,
      ambiente: ambiente.index,
      serverUrl: normalizedUrl,
      apiLocalUrl: tipoConexao == TipoConexao.local ? normalizedUrl : null,
      serverName: _gerarNomeServidor(normalizedUrl, ambiente, tipoConexao),
    );
    
    // Salvar
    final saved = await saveConfig(config);
    
    if (saved) {
      // Buscar configurações do backend
      await AppConfigService.fetchFromBackend(normalizedUrl);
    }
    
    return saved;
  }
  
  static String _gerarNomeServidor(
    String url,
    Ambiente ambiente,
    TipoConexao tipoConexao,
  ) {
    if (tipoConexao == TipoConexao.local) {
      return 'Servidor Local';
    }
    
    if (ambiente == Ambiente.producao) {
      return 'Produção';
    } else {
      return 'Homologação';
    }
  }
  
  /// Obtém configuração atual
  static AppConnectionConfig? getCurrentConfig() {
    return loadConfig();
  }
  
  /// Verifica se está configurado
  static bool isConfigured() {
    return loadConfig() != null;
  }
  
  /// Limpa configuração
  static Future<bool> clearConfig() async {
    return await PreferencesService.remove(_configKey);
  }
}
```

---

## 🎨 Interface de Configuração

### **Tela: Configurar Conexão**

```dart
// lib/screens/configuracao/configurar_conexao_screen.dart

class ConfigurarConexaoScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configurar Conexão'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tipo de Conexão
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tipo de Conexão',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 16),
                    RadioListTile<TipoConexao>(
                      title: Text('Servidor Local'),
                      subtitle: Text('Conecta ao servidor na rede local'),
                      value: TipoConexao.local,
                      groupValue: _tipoConexao,
                      onChanged: (v) => setState(() => _tipoConexao = v),
                    ),
                    RadioListTile<TipoConexao>(
                      title: Text('Servidor Remoto'),
                      subtitle: Text('Conecta ao servidor na nuvem'),
                      value: TipoConexao.remoto,
                      groupValue: _tipoConexao,
                      onChanged: (v) => setState(() => _tipoConexao = v),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Ambiente (se remoto)
            if (_tipoConexao == TipoConexao.remoto) ...[
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ambiente',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 16),
                      RadioListTile<Ambiente>(
                        title: Text('Produção'),
                        subtitle: Text('api.h4nd.com.br'),
                        value: Ambiente.producao,
                        groupValue: _ambiente,
                        onChanged: (v) => setState(() => _ambiente = v),
                      ),
                      RadioListTile<Ambiente>(
                        title: Text('Homologação'),
                        subtitle: Text('api-hml.h4nd.com.br'),
                        value: Ambiente.homologacao,
                        groupValue: _ambiente,
                        onChanged: (v) => setState(() => _ambiente = v),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
            
            // URL do Servidor
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tipoConexao == TipoConexao.local
                          ? 'Endereço do Servidor Local'
                          : 'Endereço do Servidor',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _serverUrlController,
                      decoration: InputDecoration(
                        labelText: 'URL do Servidor',
                        hintText: _tipoConexao == TipoConexao.local
                            ? 'Ex: http://192.168.1.100:5100'
                            : _ambiente == Ambiente.producao
                                ? 'https://api.h4nd.com.br'
                                : 'https://api-hml.h4nd.com.br',
                        prefixIcon: Icon(Icons.link),
                      ),
                      onChanged: (value) {
                        // Auto-detecta ambiente e tipo
                        _autoDetectarConfig(value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Informações Detectadas
            if (_configDetectada != null) ...[
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configuração Detectada:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('Tipo: ${_configDetectada!.tipoConexaoEnum.name}'),
                      if (_configDetectada!.isRemoto)
                        Text('Ambiente: ${_configDetectada!.ambienteEnum.name}'),
                      Text('URL: ${_configDetectada!.serverUrl}'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
            
            // Botão Salvar
            ElevatedButton(
              onPressed: _salvarConfiguracao,
              child: Text('Salvar Configuração'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _autoDetectarConfig(String url) {
    if (url.isEmpty) return;
    
    final ambiente = AmbienteDetector.detectarAmbiente(url);
    final tipoConexao = AmbienteDetector.detectarTipoConexao(url);
    
    setState(() {
      _tipoConexao = tipoConexao;
      _ambiente = ambiente;
      _configDetectada = AppConnectionConfig(
        tipoConexao: tipoConexao.index,
        ambiente: ambiente.index,
        serverUrl: url,
      );
    });
  }
}
```

---

## 🔄 Uso no Código

### **Verificar Tipo de Conexão**

```dart
// Em qualquer lugar do código
final config = ConnectionConfigService.getCurrentConfig();

if (config == null) {
  // Não configurado - mostrar tela de configuração
  Navigator.push(context, MaterialPageRoute(
    builder: (context) => ConfigurarConexaoScreen(),
  ));
  return;
}

// Verificar tipo de conexão
if (config.isLocal) {
  // Usa API Local para impressão
  final apiService = ImpressaoApiService(apiLocalClient);
} else {
  // Não tem API Local - só impressão direta
}

// Verificar ambiente
if (config.isProduction) {
  // Produção
} else {
  // Homologação
}
```

---

## 📋 Resumo

### **Estrutura:**
1. **AppConnectionConfig**: Modelo unificado
2. **AmbienteDetector**: Detecta automaticamente
3. **ConnectionConfigService**: Gerencia configuração
4. **Tela de Configuração**: Interface para usuário

### **Detecção Automática:**
- **Ambiente**: Detecta pela URL (api.h4nd.com.br = produção)
- **Tipo**: Detecta pela URL (192.168.x.x = local)

### **Uso:**
```dart
final config = ConnectionConfigService.getCurrentConfig();
if (config.isLocal) {
  // Usa API Local
} else {
  // Usa servidor remoto
}
```

**Estrutura clara e automática!** 🎯

