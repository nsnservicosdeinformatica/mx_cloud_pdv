/// DTOs para operações de pedidos e itens de pedido

/// DTO para atualização de item de pedido
class UpdateItemPedidoDto {
  /// Quantidade do item (opcional, mínimo 0.001)
  final double? quantidade;
  
  /// Preço unitário do item (opcional, mínimo 0)
  final double? precoUnitario;
  
  /// Desconto em valor (opcional)
  final double? desconto;
  
  /// Desconto em percentual (opcional)
  final double? percentualDesconto;
  
  /// Acréscimo em valor (opcional)
  final double? acrescimo;
  
  /// Status do item (opcional)
  final int? status;
  
  /// Observações do item (opcional, máximo 500 caracteres)
  final String? observacoes;

  UpdateItemPedidoDto({
    this.quantidade,
    this.precoUnitario,
    this.desconto,
    this.percentualDesconto,
    this.acrescimo,
    this.status,
    this.observacoes,
  });

  /// Converte para JSON para envio ao backend
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    
    if (quantidade != null) {
      json['quantidade'] = quantidade;
    }
    if (precoUnitario != null) {
      json['precoUnitario'] = precoUnitario;
    }
    if (desconto != null) {
      json['desconto'] = desconto;
    }
    if (percentualDesconto != null) {
      json['percentualDesconto'] = percentualDesconto;
    }
    if (acrescimo != null) {
      json['acrescimo'] = acrescimo;
    }
    if (status != null) {
      json['status'] = status;
    }
    if (observacoes != null) {
      json['observacoes'] = observacoes;
    }
    
    return json;
  }
}

/// DTO para cancelamento de item de pedido
class CancelarItemPedidoDto {
  /// Motivo do cancelamento (obrigatório, máximo 500 caracteres)
  final String motivo;

  CancelarItemPedidoDto({
    required this.motivo,
  });

  /// Converte para JSON para envio ao backend
  Map<String, dynamic> toJson() {
    return {
      'motivo': motivo,
    };
  }
}

/// DTO para cancelamento de pedido
class CancelarPedidoDto {
  /// Motivo do cancelamento (obrigatório)
  final String motivo;

  CancelarPedidoDto({
    required this.motivo,
  });

  /// Converte para JSON para envio ao backend
  Map<String, dynamic> toJson() {
    return {
      'motivo': motivo,
    };
  }
}

