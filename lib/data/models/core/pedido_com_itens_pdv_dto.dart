/// DTO simplificado para pedidos com itens no PDV
/// Usado especificamente para exibir produtos agrupados de mesa/comanda
class PedidoComItensPdvDto {
  final String id;
  final String numero;
  final String? mesaId;
  final String? comandaId;
  final List<ItemPedidoPdvDto> itens;

  PedidoComItensPdvDto({
    required this.id,
    required this.numero,
    this.mesaId,
    this.comandaId,
    required this.itens,
  });

  factory PedidoComItensPdvDto.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final id = idValue is String ? idValue : idValue?.toString() ?? '';

    final numero = json['numero']?.toString() ?? '';

    final mesaIdValue = json['mesaId'];
    final mesaId = mesaIdValue?.toString();

    final comandaIdValue = json['comandaId'];
    final comandaId = comandaIdValue?.toString();

    // Processa itens
    final itensData = json['itens'] as List<dynamic>? ?? [];
    final itens = itensData
        .map((item) => ItemPedidoPdvDto.fromJson(item as Map<String, dynamic>))
        .toList();

    return PedidoComItensPdvDto(
      id: id,
      numero: numero,
      mesaId: mesaId,
      comandaId: comandaId,
      itens: itens,
    );
  }
}

/// DTO para valores de atributos de uma variação de produto
class ProdutoVariacaoAtributoValorDto {
  final String nomeAtributo;
  final String nomeValor;

  ProdutoVariacaoAtributoValorDto({
    required this.nomeAtributo,
    required this.nomeValor,
  });

  factory ProdutoVariacaoAtributoValorDto.fromJson(Map<String, dynamic> json) {
    return ProdutoVariacaoAtributoValorDto(
      nomeAtributo: json['nomeAtributo']?.toString() ?? '',
      nomeValor: json['nomeValor']?.toString() ?? '',
    );
  }
}

/// DTO simplificado para item de pedido no PDV
class ItemPedidoPdvDto {
  final String id;
  final String produtoId;
  final String produtoNome;
  final String? produtoVariacaoId;
  final String? produtoVariacaoNome;
  final double precoUnitario;
  final int quantidade;
  final List<ProdutoVariacaoAtributoValorDto> variacaoAtributosValores;

  ItemPedidoPdvDto({
    required this.id,
    required this.produtoId,
    required this.produtoNome,
    this.produtoVariacaoId,
    this.produtoVariacaoNome,
    required this.precoUnitario,
    required this.quantidade,
    this.variacaoAtributosValores = const [],
  });

  factory ItemPedidoPdvDto.fromJson(Map<String, dynamic> json) {
    // ID do item (obrigatório para operações de edição/exclusão)
    final idValue = json['id'];
    final id = idValue is String ? idValue : idValue?.toString() ?? '';

    final produtoIdValue = json['produtoId'];
    final produtoId = produtoIdValue is String
        ? produtoIdValue
        : produtoIdValue?.toString() ?? '';

    final produtoNome = json['produtoNome']?.toString() ?? '';

    final produtoVariacaoIdValue = json['produtoVariacaoId'];
    final produtoVariacaoId = produtoVariacaoIdValue?.toString();

    final produtoVariacaoNome = json['produtoVariacaoNome']?.toString();

    final precoUnitario = json['precoUnitario'] is num
        ? (json['precoUnitario'] as num).toDouble()
        : double.tryParse(json['precoUnitario']?.toString() ?? '0') ?? 0.0;

    // Quantidade pode vir como int, double ou decimal (num)
    int quantidade = 0;
    if (json['quantidade'] is int) {
      quantidade = json['quantidade'] as int;
    } else if (json['quantidade'] is num) {
      quantidade = (json['quantidade'] as num).toInt();
    } else {
      quantidade = int.tryParse(json['quantidade']?.toString() ?? '0') ?? 0;
    }

    // Processa valores dos atributos da variação
    final variacaoAtributosValoresData = json['variacaoAtributosValores'] as List<dynamic>? ?? [];
    final variacaoAtributosValores = variacaoAtributosValoresData
        .map((item) => ProdutoVariacaoAtributoValorDto.fromJson(item as Map<String, dynamic>))
        .toList();

    return ItemPedidoPdvDto(
      id: id,
      produtoId: produtoId,
      produtoNome: produtoNome,
      produtoVariacaoId: produtoVariacaoId,
      produtoVariacaoNome: produtoVariacaoNome,
      precoUnitario: precoUnitario,
      quantidade: quantidade,
      variacaoAtributosValores: variacaoAtributosValores,
    );
  }
}
