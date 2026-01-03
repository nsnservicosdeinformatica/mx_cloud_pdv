import 'dart:convert';

/// Tipo de conexão do servidor
enum TipoConexao {
  local,   // Servidor Local (na rede)
  remoto,  // Servidor Remoto (H4ND - nuvem)
}

/// Ambiente do servidor (só se tipoConexao = remoto)
enum Ambiente {
  producao,    // Produção
  homologacao, // Homologação
}

/// Configuração de conexão do app
/// Define se usa servidor local ou remoto, e qual ambiente
class AppConnectionConfig {
  /// Tipo de conexão
  final TipoConexao tipoConexao;
  
  /// Ambiente (só se tipoConexao = remoto)
  final Ambiente? ambiente;
  
  /// URL do servidor
  final String serverUrl;
  
  /// Nome do servidor (para exibição)
  final String serverName;
  
  AppConnectionConfig({
    required this.tipoConexao,
    this.ambiente,
    required this.serverUrl,
    required this.serverName,
  });
  
  /// Se está conectado ao servidor local
  bool get isLocal => tipoConexao == TipoConexao.local;
  
  /// Se está conectado ao servidor remoto (H4ND)
  bool get isRemoto => tipoConexao == TipoConexao.remoto;
  
  /// Se é produção (só se remoto)
  bool get isProduction => ambiente == Ambiente.producao;
  
  /// Se é homologação (só se remoto)
  bool get isHomologacao => ambiente == Ambiente.homologacao;
  
  /// Se usa rede H4ND (servidor remoto)
  bool get usaRedeH4ND => isRemoto;
  
  /// Se usa rede local
  bool get usaRedeLocal => isLocal;
  
  /// Converte para JSON
  Map<String, dynamic> toJson() {
    return {
      'tipoConexao': tipoConexao.index,
      'ambiente': ambiente?.index,
      'serverUrl': serverUrl,
      'serverName': serverName,
    };
  }
  
  /// Cria a partir de JSON
  factory AppConnectionConfig.fromJson(Map<String, dynamic> json) {
    return AppConnectionConfig(
      tipoConexao: TipoConexao.values[json['tipoConexao'] as int],
      ambiente: json['ambiente'] != null 
          ? Ambiente.values[json['ambiente'] as int]
          : null,
      serverUrl: json['serverUrl'] as String,
      serverName: json['serverName'] as String,
    );
  }
  
  /// Converte para string JSON
  String toJsonString() {
    return jsonEncode(toJson());
  }
  
  /// Cria a partir de string JSON
  factory AppConnectionConfig.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return AppConnectionConfig.fromJson(json);
  }
  
  @override
  String toString() {
    return 'AppConnectionConfig('
        'tipoConexao: $tipoConexao, '
        'ambiente: $ambiente, '
        'serverUrl: $serverUrl, '
        'serverName: $serverName'
        ')';
  }
}

