import 'package:hive/hive.dart';

part 'configuracao_restaurante_local.g.dart';

/// Modelo local de ConfiguracaoRestaurante para persistência offline
@HiveType(typeId: 23)
class ConfiguracaoRestauranteLocal extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String empresaId;

  @HiveField(2)
  String empresaNome;

  @HiveField(3)
  int tipoVisualizacaoMesas;

  @HiveField(4)
  bool permiteMesasSemPosicao;

  @HiveField(5)
  bool permitePedidosSemMesa;

  @HiveField(6)
  bool permiteMultiplosPedidosPorMesa;

  @HiveField(7)
  int tipoControleVenda;

  @HiveField(8)
  bool mapaDisponivel;

  @HiveField(9)
  bool listaDisponivel;

  @HiveField(10)
  bool controlePorMesa;

  @HiveField(11)
  bool controlePorComanda;

  @HiveField(12)
  bool controlePorMesaOuComanda;

  @HiveField(13)
  DateTime createdAt;

  @HiveField(14)
  DateTime? updatedAt;

  ConfiguracaoRestauranteLocal({
    required this.id,
    required this.empresaId,
    required this.empresaNome,
    required this.tipoVisualizacaoMesas,
    required this.permiteMesasSemPosicao,
    required this.permitePedidosSemMesa,
    required this.permiteMultiplosPedidosPorMesa,
    required this.tipoControleVenda,
    required this.mapaDisponivel,
    required this.listaDisponivel,
    required this.controlePorMesa,
    required this.controlePorComanda,
    required this.controlePorMesaOuComanda,
    required this.createdAt,
    this.updatedAt,
  });

  /// Converte de ConfiguracaoRestauranteDto para ConfiguracaoRestauranteLocal
  factory ConfiguracaoRestauranteLocal.fromDto(dynamic dto) {
    return ConfiguracaoRestauranteLocal(
      id: dto.id,
      empresaId: dto.empresaId,
      empresaNome: dto.empresaNome,
      tipoVisualizacaoMesas: dto.tipoVisualizacaoMesas,
      permiteMesasSemPosicao: dto.permiteMesasSemPosicao,
      permitePedidosSemMesa: dto.permitePedidosSemMesa,
      permiteMultiplosPedidosPorMesa: dto.permiteMultiplosPedidosPorMesa,
      tipoControleVenda: dto.tipoControleVenda,
      mapaDisponivel: dto.mapaDisponivel,
      listaDisponivel: dto.listaDisponivel,
      controlePorMesa: dto.controlePorMesa,
      controlePorComanda: dto.controlePorComanda,
      controlePorMesaOuComanda: dto.controlePorMesaOuComanda,
      createdAt: dto.createdAt,
      updatedAt: dto.updatedAt,
    );
  }

  /// Converte para ConfiguracaoRestauranteDto
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'empresaId': empresaId,
      'empresaNome': empresaNome,
      'tipoVisualizacaoMesas': tipoVisualizacaoMesas,
      'permiteMesasSemPosicao': permiteMesasSemPosicao,
      'permitePedidosSemMesa': permitePedidosSemMesa,
      'permiteMultiplosPedidosPorMesa': permiteMultiplosPedidosPorMesa,
      'tipoControleVenda': tipoControleVenda,
      'mapaDisponivel': mapaDisponivel,
      'listaDisponivel': listaDisponivel,
      'controlePorMesa': controlePorMesa,
      'controlePorComanda': controlePorComanda,
      'controlePorMesaOuComanda': controlePorMesaOuComanda,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

