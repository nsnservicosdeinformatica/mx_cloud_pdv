// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'configuracao_restaurante_local.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConfiguracaoRestauranteLocalAdapter
    extends TypeAdapter<ConfiguracaoRestauranteLocal> {
  @override
  final int typeId = 23;

  @override
  ConfiguracaoRestauranteLocal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConfiguracaoRestauranteLocal(
      id: fields[0] as String,
      empresaId: fields[1] as String,
      empresaNome: fields[2] as String,
      tipoVisualizacaoMesas: fields[3] as int,
      permiteMesasSemPosicao: fields[4] as bool,
      permitePedidosSemMesa: fields[5] as bool,
      permiteMultiplosPedidosPorMesa: fields[6] as bool,
      tipoControleVenda: fields[7] as int,
      mapaDisponivel: fields[8] as bool,
      listaDisponivel: fields[9] as bool,
      controlePorMesa: fields[10] as bool,
      controlePorComanda: fields[11] as bool,
      controlePorMesaOuComanda: fields[12] as bool,
      createdAt: fields[13] as DateTime,
      updatedAt: fields[14] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ConfiguracaoRestauranteLocal obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.empresaId)
      ..writeByte(2)
      ..write(obj.empresaNome)
      ..writeByte(3)
      ..write(obj.tipoVisualizacaoMesas)
      ..writeByte(4)
      ..write(obj.permiteMesasSemPosicao)
      ..writeByte(5)
      ..write(obj.permitePedidosSemMesa)
      ..writeByte(6)
      ..write(obj.permiteMultiplosPedidosPorMesa)
      ..writeByte(7)
      ..write(obj.tipoControleVenda)
      ..writeByte(8)
      ..write(obj.mapaDisponivel)
      ..writeByte(9)
      ..write(obj.listaDisponivel)
      ..writeByte(10)
      ..write(obj.controlePorMesa)
      ..writeByte(11)
      ..write(obj.controlePorComanda)
      ..writeByte(12)
      ..write(obj.controlePorMesaOuComanda)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfiguracaoRestauranteLocalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
