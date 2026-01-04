/// Endpoints da API
class ApiEndpoints {
  // Auth
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String revoke = '/auth/revoke';
  static const String validateUser = '/auth/validate-user';
  static const String health = '/auth/health';
  
  // Pedidos
  static const String pedidos = '/pedidos';
  static String pedidoById(String id) => '/pedidos/$id';
  static String pedidosPorMesa(String mesaId) => '/pedidos/por-mesa/$mesaId';
  static String pedidosPorComanda(String comandaId) => '/pedidos/por-comanda/$comandaId';
  static String pedidosPorCliente(String clienteId) => '/pedidos/por-cliente/$clienteId';
  static String pedidoItens(String pedidoId) => '/pedidos/$pedidoId/itens';
  static String pedidoItem(String pedidoId, String itemId) => '/pedidos/$pedidoId/itens/$itemId';
  static String cancelarItem(String pedidoId, String itemId) => '/pedidos/$pedidoId/itens/$itemId/cancelar';
  static String pedidoPagamentos(String pedidoId) => '/pedidos/$pedidoId/pagamentos';
  static String finalizarPedido(String pedidoId) => '/pedidos/$pedidoId/finalizar';
  static String cancelarPedido(String pedidoId) => '/pedidos/$pedidoId/cancelar';
  
  // Mesas
  static const String mesas = '/mesas';
  static String mesaById(String id) => '/mesas/$id';
  static String mesasPorLayout(String layoutId) => '/mesas/por-layout/$layoutId';
  static String ocuparMesa(String id) => '/mesas/$id/ocupar';
  static String liberarMesa(String id) => '/mesas/$id/liberar';
  
  // Comandas
  static const String comandas = '/comandas';
  static String comandaById(String id) => '/comandas/$id';
  static String comandaPorCodigoBarras(String codigo) => '/comandas/por-codigo-barras/$codigo';
  static String encerrarComanda(String id) => '/comandas/$id/encerrar';
  static String cancelarComanda(String id) => '/comandas/$id/cancelar';
  static String reabrirComanda(String id) => '/comandas/$id/reabrir';
  
  // Sincronização PDV
  static const String syncProdutos = '/produto-pdv-sync/produtos';
  static const String syncGruposExibicao = '/produto-pdv-sync/grupos-exibicao';
  static const String syncMesasComandas = '/pdv-sync/mesas-comandas';
}
