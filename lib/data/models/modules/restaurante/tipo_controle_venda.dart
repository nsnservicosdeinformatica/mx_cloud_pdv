/// Enum para tipo de controle de venda no módulo restaurante
/// Espelha o enum do backend C#
enum TipoControleVenda {
  /// Controle por Mesa - Apenas mesa (comanda não é usada)
  porMesa(1),
  
  /// Controle por Comanda - Apenas comanda (mesa não é usada)
  porComanda(2),
  
  /// Controle por Mesa OU Comanda - Permite usar mesa, comanda ou ambos (nenhum é obrigatório)
  porMesaOuComanda(3);

  final int value;
  const TipoControleVenda(this.value);

  /// Converte de int para enum
  static TipoControleVenda fromInt(int value) {
    return TipoControleVenda.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TipoControleVenda.porMesa, // Default
    );
  }

  /// Converte de enum para int
  int toInt() => value;
}

