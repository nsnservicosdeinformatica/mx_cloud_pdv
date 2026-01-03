# 🔧 Configuração de Servidor: Versão Simples

## 🎯 Objetivo

Tela inicial simples onde usuário escolhe:
- **Servidor Online** (H4ND) → Sistema detecta produção/homologação automaticamente
- **Servidor Local** → Usuário informa endereço

---

## 🔍 Como Identificar Produção vs Homologação

### **Opção 1: Build Mode (Recomendado)**

```dart
import 'package:flutter/foundation.dart';

bool get isProduction {
  // kReleaseMode = true quando é build de release (produção)
  // kDebugMode = true quando é build de debug (desenvolvimento)
  // kProfileMode = true quando é build de profile (testes)
  
  return kReleaseMode;
}
```

**Como funciona:**
- `flutter run` → `kDebugMode = true` → Homologação
- `flutter build apk --release` → `kReleaseMode = true` → Produção
- `flutter build apk --profile` → `kProfileMode = true` → Homologação

---

### **Opção 2: Variável de Ambiente (Build Time)**

```dart
bool get isProduction {
  const bool isProd = bool.fromEnvironment('PRODUCTION', defaultValue: false);
  return isProd;
}
```

**Como usar:**
```bash
# Build de produção
flutter build apk --dart-define=PRODUCTION=true

# Build de homologação (padrão)
flutter build apk
```

---

### **Opção 3: Package Info (Versão do App)**

```dart
import 'package:package_info_plus/package_info_plus.dart';

Future<bool> isProduction() async {
  final packageInfo = await PackageInfo.fromPlatform();
  
  // Verifica se tem "dev", "hml", "test" no nome
  final buildNumber = packageInfo.buildNumber.toLowerCase();
  if (buildNumber.contains('dev') || 
      buildNumber.contains('hml') || 
      buildNumber.contains('test')) {
    return false; // Homologação
  }
  
  // Se não tem, assume produção
  return true;
}
```

---

### **Opção 4: Config File (Recomendado para Flexibilidade)**

```dart
// assets/config/app_config.json

// Produção
{
  "environment": "production",
  "apiUrl": "https://api.h4nd.com.br"
}

// Homologação
{
  "environment": "homologation",
  "apiUrl": "https://api-hml.h4nd.com.br"
}
```

**Como usar:**
- Build produção → Copia `app_config.prod.json` → `app_config.json`
- Build homologação → Copia `app_config.hml.json` → `app_config.json`

---

## 🎯 RECOMENDAÇÃO: Combinar Build Mode + Config

### **Estrutura:**

```dart
// lib/core/config/environment_detector.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class EnvironmentDetector {
  static String? _cachedEnvironment;
  
  /// Detecta ambiente (produção ou homologação)
  static Future<String> detectEnvironment() async {
    if (_cachedEnvironment != null) {
      return _cachedEnvironment!;
    }
    
    // 1. Tenta ler de arquivo de config (mais flexível)
    try {
      final configJson = await rootBundle.loadString('assets/config/app_config.json');
      final config = jsonDecode(configJson) as Map<String, dynamic>;
      final env = config['environment'] as String?;
      
      if (env != null) {
        _cachedEnvironment = env;
        return env;
      }
    } catch (e) {
      // Arquivo não existe, continua
    }
    
    // 2. Usa build mode como fallback
    if (kReleaseMode) {
      _cachedEnvironment = 'production';
    } else {
      _cachedEnvironment = 'homologation';
    }
    
    return _cachedEnvironment!;
  }
  
  /// Verifica se é produção
  static Future<bool> isProduction() async {
    final env = await detectEnvironment();
    return env == 'production';
  }
  
  /// Obtém URL do servidor baseado no ambiente
  static Future<String> getServerUrl() async {
    final isProd = await isProduction();
    
    if (isProd) {
      return 'https://api.h4nd.com.br';
    } else {
      return 'https://api-hml.h4nd.com.br';
    }
  }
}
```

---

## 🎨 Tela de Configuração Simplificada

### **Tela Inicial: Escolher Tipo de Servidor**

```dart
// lib/screens/configuracao/escolher_servidor_screen.dart

class EscolherServidorScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Icon(Icons.cloud, size: 80),
                SizedBox(height: 24),
                
                Text(
                  'Escolha o Tipo de Servidor',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                SizedBox(height: 48),
                
                // Opção 1: Servidor Online (H4ND)
                Card(
                  child: InkWell(
                    onTap: () => _configurarServidorOnline(),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.cloud, size: 48),
                          SizedBox(height: 16),
                          Text(
                            'Servidor Online (H4ND)',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Conecta ao servidor na nuvem',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          SizedBox(height: 8),
                          FutureBuilder<bool>(
                            future: EnvironmentDetector.isProduction(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return CircularProgressIndicator();
                              }
                              
                              final isProd = snapshot.data!;
                              return Text(
                                isProd 
                                  ? 'Produção: api.h4nd.com.br'
                                  : 'Homologação: api-hml.h4nd.com.br',
                                style: TextStyle(
                                  color: isProd ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Opção 2: Servidor Local
                Card(
                  child: InkWell(
                    onTap: () => _configurarServidorLocal(),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.dns, size: 48),
                          SizedBox(height: 16),
                          Text(
                            'Servidor Local',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Conecta ao servidor na rede local',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Future<void> _configurarServidorOnline() async {
    // Detecta ambiente automaticamente
    final isProd = await EnvironmentDetector.isProduction();
    final serverUrl = await EnvironmentDetector.getServerUrl();
    
    // Salva configuração
    final config = AppConnectionConfig(
      tipoConexao: TipoConexao.remoto.index,
      ambiente: (isProd ? Ambiente.producao : Ambiente.homologacao).index,
      serverUrl: serverUrl,
      serverName: isProd ? 'Produção' : 'Homologação',
    );
    
    await ConnectionConfigService.saveConfig(config);
    
    // Valida conexão
    final healthResult = await HealthCheckService.checkHealth(serverUrl);
    
    if (healthResult.success) {
      // Busca config do backend
      await AppConfigService.fetchFromBackend(serverUrl);
      
      // Reinicia app
      await initializeApp();
    } else {
      AppToast.showError(context, 'Erro ao conectar: ${healthResult.message}');
    }
  }
  
  Future<void> _configurarServidorLocal() async {
    // Navega para tela de configurar servidor local
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConfigurarServidorLocalScreen(),
      ),
    );
  }
}
```

---

## 🔧 Modelo de Configuração Simplificado

```dart
// lib/core/config/app_connection_config.dart

@HiveType(typeId: 30)
class AppConnectionConfig extends HiveObject {
  /// Tipo de conexão
  @HiveField(0)
  final int tipoConexao; // TipoConexao.index
  
  /// Ambiente (só se tipoConexao = remoto)
  @HiveField(1)
  final int? ambiente; // Ambiente.index (null se local)
  
  /// URL do servidor
  @HiveField(2)
  final String serverUrl;
  
  /// Nome do servidor (para exibição)
  @HiveField(3)
  final String serverName;
  
  AppConnectionConfig({
    required this.tipoConexao,
    this.ambiente,
    required this.serverUrl,
    required this.serverName,
  });
  
  TipoConexao get tipoConexaoEnum => TipoConexao.values[tipoConexao];
  Ambiente? get ambienteEnum => ambiente != null ? Ambiente.values[ambiente!] : null;
  
  /// Se está conectado ao servidor local
  bool get isLocal => tipoConexaoEnum == TipoConexao.local;
  
  /// Se está conectado ao servidor remoto (H4ND)
  bool get isRemoto => tipoConexaoEnum == TipoConexao.remoto;
  
  /// Se é produção (só se remoto)
  bool get isProduction => ambienteEnum == Ambiente.producao;
  
  /// Se é homologação (só se remoto)
  bool get isHomologacao => ambienteEnum == Ambiente.homologacao;
  
  /// Se usa rede H4ND (servidor remoto)
  bool get usaRedeH4ND => isRemoto;
  
  /// Se usa rede local
  bool get usaRedeLocal => isLocal;
}

enum TipoConexao {
  local,   // Servidor Local (na rede)
  remoto,  // Servidor Remoto (H4ND - nuvem)
}

enum Ambiente {
  producao,    // Produção
  homologacao, // Homologação
}
```

---

## 🔧 Serviço de Configuração Simplificado

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
        ambiente: json['ambiente'] as int?,
        serverUrl: json['serverUrl'] as String,
        serverName: json['serverName'] as String,
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
      'serverName': config.serverName,
    };
    
    return await PreferencesService.setString(
      _configKey,
      jsonEncode(json),
    );
  }
  
  /// Configura servidor online (H4ND)
  static Future<bool> configurarServidorOnline() async {
    // Detecta ambiente automaticamente
    final isProd = await EnvironmentDetector.isProduction();
    final serverUrl = await EnvironmentDetector.getServerUrl();
    
    final config = AppConnectionConfig(
      tipoConexao: TipoConexao.remoto.index,
      ambiente: (isProd ? Ambiente.producao : Ambiente.homologacao).index,
      serverUrl: serverUrl,
      serverName: isProd ? 'Produção (H4ND)' : 'Homologação (H4ND)',
    );
    
    return await saveConfig(config);
  }
  
  /// Configura servidor local
  static Future<bool> configurarServidorLocal(String serverUrl) async {
    // Normalizar URL
    String normalizedUrl = serverUrl.trim();
    if (!normalizedUrl.startsWith('http://') && 
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'http://$normalizedUrl';
    }
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }
    
    final config = AppConnectionConfig(
      tipoConexao: TipoConexao.local.index,
      ambiente: null, // Local não tem ambiente
      serverUrl: normalizedUrl,
      serverName: 'Servidor Local',
    );
    
    return await saveConfig(config);
  }
  
  /// Verifica se está configurado
  static bool isConfigured() {
    return loadConfig() != null;
  }
  
  /// Obtém configuração atual
  static AppConnectionConfig? getCurrentConfig() {
    return loadConfig();
  }
}
```

---

## 📋 Arquivo de Config (Assets)

### **assets/config/app_config.prod.json**

```json
{
  "environment": "production",
  "apiUrl": "https://api.h4nd.com.br"
}
```

### **assets/config/app_config.hml.json**

```json
{
  "environment": "homologation",
  "apiUrl": "https://api-hml.h4nd.com.br"
}
```

### **Build Script (opcional)**

```bash
# build_prod.sh
cp assets/config/app_config.prod.json assets/config/app_config.json
flutter build apk --release

# build_hml.sh
cp assets/config/app_config.hml.json assets/config/app_config.json
flutter build apk --release
```

---

## 🔄 Fluxo Completo

```
1. App inicia
   ↓
2. Verifica: ConnectionConfigService.isConfigured()?
   ├─ Se não → Mostra tela: EscolherServidorScreen
   └─ Se sim → Usa configuração salva
   ↓
3. Tela: EscolherServidorScreen
   ├─ Opção 1: Servidor Online (H4ND)
   │   → Detecta ambiente (produção/homologação)
   │   → Usa URL automática
   │   → Salva config
   │
   └─ Opção 2: Servidor Local
       → Mostra tela para digitar URL
       → Salva config
   ↓
4. App usa configuração:
   - Se remoto → api.h4nd.com.br ou api-hml.h4nd.com.br
   - Se local → URL informada pelo usuário
```

---

## ✅ Resumo

### **Identificação de Ambiente:**

1. **Build Mode** (kReleaseMode): Simples, automático
2. **Config File** (assets/config/app_config.json): Flexível
3. **Combinado**: Config file + Build mode como fallback

### **Tela Inicial:**

- Escolher: Servidor Online OU Servidor Local
- Se Online: Detecta produção/homologação automaticamente
- Se Local: Usuário digita URL

### **Registro:**

- `tipoConexao`: local ou remoto
- `ambiente`: produção ou homologação (só se remoto)
- `usaRedeH4ND`: true se remoto
- `usaRedeLocal`: true se local

**Solução simples e clara!** 🎯

