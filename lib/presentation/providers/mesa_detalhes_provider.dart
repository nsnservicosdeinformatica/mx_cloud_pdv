import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/core/produto_agrupado.dart';
import '../../data/models/core/vendas/venda_dto.dart';
import '../../data/models/core/vendas/pagamento_venda_dto.dart';
import '../../models/mesas/comanda_com_produtos.dart';
import '../../models/mesas/entidade_produtos.dart' show TipoEntidade, TipoVisualizacao, MesaComandaInfo;
import '../../data/services/core/pedido_service.dart';
import '../../data/services/core/venda_service.dart';
import '../../data/services/modules/restaurante/mesa_service.dart';
import '../../data/services/modules/restaurante/comanda_service.dart';
import '../../data/repositories/pedido_local_repository.dart';
import '../../data/models/local/pedido_local.dart';
import '../../data/models/local/sync_status_pedido.dart';
import '../../data/models/core/pedido_com_itens_pdv_dto.dart';
import '../../data/models/core/pedidos_com_venda_comandas_dto.dart';
import '../../data/models/modules/restaurante/comanda_list_item.dart';
import '../../data/models/modules/restaurante/configuracao_restaurante_dto.dart';
import '../../core/events/app_event_bus.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Provider para gerenciar estado da tela de detalhes de produtos (mesa/comanda)
class MesaDetalhesProvider extends ChangeNotifier {
  final MesaComandaInfo entidade;
  final PedidoService pedidoService;
  final MesaService mesaService;
  final ComandaService comandaService;
  final VendaService vendaService;
  final ConfiguracaoRestauranteDto? configuracaoRestaurante;
  final PedidoLocalRepository pedidoRepo;

  MesaDetalhesProvider({
    required this.entidade,
    required this.pedidoService,
    required this.mesaService,
    required this.comandaService,
    required this.vendaService,
    required this.configuracaoRestaurante,
    required this.pedidoRepo,
  }) {
    // Inicializa status da mesa com o status inicial da entidade
    _statusMesa = entidade.status;
    
    // Configura listeners de eventos
    _setupEventBusListener();
    // Recalcula contadores iniciais
    _recalcularContadoresPedidos();
    _isInitialized = true;
  }

  // Estado de produtos
  List<ProdutoAgrupado> _produtosAgrupados = [];
  bool _isLoading = true;
  bool _carregandoProdutos = false;
  String? _errorMessage;

  // Estado de pedidos (para visualização por pedido)
  List<PedidoComItensPdvDto> _pedidos = [];
  
  // Tipo de visualização ativa
  TipoVisualizacao _tipoVisualizacao = TipoVisualizacao.agrupado;

  // Estado de venda
  VendaDto? _vendaAtual;

  // Controle de abas (apenas quando controle é por comanda e é mesa)
  String? _abaSelecionada; // null = "Mesa" (venda integral - tudo), comandaId = comanda específica, "_SEM_COMANDA" = "Sem Comanda" (apenas sem comanda)

  // Constante para identificar aba "Sem Comanda"
  static const String _SEM_COMANDA = "_SEM_COMANDA";
  
  // Getter público para a constante (usado pela tela)
  static String get semComandaId => _SEM_COMANDA;

  // Dados das comandas da mesa
  List<ComandaComProdutos> _comandasDaMesa = [];
  bool _carregandoComandas = false;
  Map<String, List<ProdutoAgrupado>> _produtosPorComanda = {}; // comandaId -> produtos (ou "_SEM_COMANDA" para sem comanda)
  Map<String, VendaDto?> _vendasPorComanda = {}; // comandaId -> venda (ou "_SEM_COMANDA" para sem comanda)

  // Controle de expansão do histórico de pagamentos
  bool _historicoPagamentosExpandido = false;
  
  // Status da mesa (atualizado via eventos)
  String? _statusMesa;
  
  // Status de sincronização (contadores de pedidos locais)
  int _pedidosPendentes = 0;
  int _pedidosSincronizando = 0;
  int _pedidosComErro = 0;
  
  // Listeners de eventos
  List<StreamSubscription<AppEvent>> _eventBusSubscriptions = [];
  bool _isInitialized = false;
  
  // Rastreamento de pedidos já processados para evitar duplicação
  final Set<String> _pedidosProcessados = {};

  // Getters
  List<ProdutoAgrupado> get produtosAgrupados => _produtosAgrupados;
  bool get isLoading => _isLoading;
  bool get carregandoProdutos => _carregandoProdutos;
  String? get errorMessage => _errorMessage;
  VendaDto? get vendaAtual => _vendaAtual;
  String? get abaSelecionada => _abaSelecionada;
  List<ComandaComProdutos> get comandasDaMesa => _comandasDaMesa;
  bool get carregandoComandas => _carregandoComandas;
  Map<String, List<ProdutoAgrupado>> get produtosPorComanda => _produtosPorComanda;
  Map<String, VendaDto?> get vendasPorComanda => _vendasPorComanda;
  bool get historicoPagamentosExpandido => _historicoPagamentosExpandido;
  String? get statusMesa => _statusMesa;
  
  // Getters de pedidos e visualização
  List<PedidoComItensPdvDto> get pedidos => _pedidos;
  TipoVisualizacao get tipoVisualizacao => _tipoVisualizacao;
  
  // Getters de status de sincronização
  int get pedidosPendentes => _pedidosPendentes;
  int get pedidosSincronizando => _pedidosSincronizando;
  int get pedidosComErro => _pedidosComErro;
  bool get estaSincronizando => _pedidosSincronizando > 0;
  bool get temErros => _pedidosComErro > 0;
  
  /// Retorna o status visual da mesa/comanda
  /// Se há pedidos pendentes, sincronizando ou com erro, retorna "ocupada"
  /// Se há produtos na mesa (pedidos do servidor), retorna "ocupada"
  /// Caso contrário, retorna o status do servidor
  String get statusVisual {
    // Se há pedidos locais ativos (pendentes, sincronizando ou erro), mesa está ocupada
    if (_pedidosPendentes > 0 || _pedidosSincronizando > 0 || _pedidosComErro > 0) {
      return 'ocupada';
    }
    
    // Se há produtos na mesa (pedidos do servidor), mesa está ocupada
    // Isso garante que mesmo após sincronização, se há produtos, a mesa continua ocupada
    final produtosParaAcao = getProdutosParaAcao();
    if (produtosParaAcao.isNotEmpty) {
      return 'ocupada';
    }
    
    // Caso contrário, usa o status do servidor
    return _statusMesa ?? entidade.status;
  }

  /// Retorna os produtos para ação (da aba selecionada)
  /// null = "Mesa" (venda integral - todos os produtos)
  /// comandaId = produtos da comanda específica
  /// "_SEM_COMANDA" = apenas produtos sem comanda
  List<ProdutoAgrupado> getProdutosParaAcao() {
    // Se entidade é comanda (não mesa), retorna produtos agrupados diretamente
    if (entidade.tipo == TipoEntidade.comanda) {
      return _produtosAgrupados;
    }
    
    // Se aba selecionada é null, retorna TODOS os produtos (venda integral)
    if (_abaSelecionada == null) {
      return _getTodosProdutosMesa();
    }
    // Se é "_SEM_COMANDA", retorna apenas produtos sem comanda
    if (_abaSelecionada == _SEM_COMANDA) {
      return _produtosPorComanda[_SEM_COMANDA] ?? [];
    }
    // Caso contrário, retorna produtos da comanda específica
    return _produtosPorComanda[_abaSelecionada] ?? [];
  }

  /// Retorna todos os produtos da mesa (com comanda + sem comanda) - venda integral
  List<ProdutoAgrupado> _getTodosProdutosMesa() {
    final produtosMap = <String, ProdutoAgrupado>{};
    
    // Adiciona produtos de todas as comandas
    for (final comanda in _comandasDaMesa) {
      for (final produto in comanda.produtos) {
        _agruparProdutoNoMapa(
          produtosMap,
          produto.produtoId,
          produto.produtoNome,
          produto.produtoVariacaoId,
          produto.produtoVariacaoNome,
          produto.precoUnitario,
          produto.quantidadeTotal,
          variacaoAtributosValores: produto.variacaoAtributosValores,
        );
      }
    }
    
    // Adiciona produtos sem comanda
    final produtosSemComanda = _produtosPorComanda[_SEM_COMANDA] ?? [];
    for (final produto in produtosSemComanda) {
      _agruparProdutoNoMapa(
        produtosMap,
        produto.produtoId,
        produto.produtoNome,
        produto.produtoVariacaoId,
        produto.produtoVariacaoNome,
        produto.precoUnitario,
        produto.quantidadeTotal,
        variacaoAtributosValores: produto.variacaoAtributosValores,
      );
    }
    
    return _mapaParaProdutosOrdenados(produtosMap);
  }

  /// Retorna a venda para ação (da aba selecionada)
  /// null = "Mesa" (venda integral) - retorna venda atual da mesa se houver
  /// comandaId = venda da comanda específica
  /// "_SEM_COMANDA" = venda sem comanda
  VendaDto? getVendaParaAcao() {
    // Se entidade é comanda (não mesa), retorna venda atual diretamente
    if (entidade.tipo == TipoEntidade.comanda) {
      return _vendaAtual;
    }
    
    // Se aba selecionada é null ("Mesa" - venda integral), retorna venda atual da mesa
    if (_abaSelecionada == null) {
      return _vendaAtual;
    }
    // Se é "_SEM_COMANDA", retorna venda sem comanda
    if (_abaSelecionada == _SEM_COMANDA) {
      return _vendasPorComanda[_SEM_COMANDA];
    }
    // Caso contrário, retorna venda da comanda específica
    return _vendasPorComanda[_abaSelecionada];
  }

  /// Retorna os pedidos para ação (da aba selecionada)
  /// null = "Mesa" (venda integral - todos os pedidos)
  /// comandaId = pedidos da comanda específica
  /// "_SEM_COMANDA" = apenas pedidos sem comanda
  List<PedidoComItensPdvDto> getPedidosParaAcao() {
    // Se entidade é comanda (não mesa), retorna pedidos filtrados por comanda
    if (entidade.tipo == TipoEntidade.comanda) {
      return _pedidos.where((p) => p.comandaId == entidade.id).toList()
        ..sort((a, b) => b.numero.compareTo(a.numero)); // Mais recente primeiro
    }
    
    // Se aba selecionada é null, retorna TODOS os pedidos (venda integral)
    if (_abaSelecionada == null) {
      return List.from(_pedidos)
        ..sort((a, b) => b.numero.compareTo(a.numero)); // Mais recente primeiro
    }
    
    // Se é "_SEM_COMANDA", retorna apenas pedidos sem comanda
    if (_abaSelecionada == _SEM_COMANDA) {
      return _pedidos.where((p) => p.comandaId == null).toList()
        ..sort((a, b) => b.numero.compareTo(a.numero)); // Mais recente primeiro
    }
    
    // Caso contrário, retorna pedidos da comanda específica
    return _pedidos.where((p) => p.comandaId == _abaSelecionada).toList()
      ..sort((a, b) => b.numero.compareTo(a.numero)); // Mais recente primeiro
  }

  /// Altera o tipo de visualização
  void setTipoVisualizacao(TipoVisualizacao tipo) {
    if (_tipoVisualizacao != tipo) {
      _tipoVisualizacao = tipo;
      notifyListeners();
    }
  }

  /// Seleciona automaticamente a primeira aba disponível (Mesa ou primeira comanda)
  void _selecionarPrimeiraAbaDisponivel() {
    // Se já tem uma aba selecionada e ela ainda existe, mantém
    if (_abaSelecionada != null) {
      if (_abaSelecionada == _SEM_COMANDA && temProdutosSemComanda) {
        return; // Aba "Sem Comanda" ainda existe
      }
      if (_abaSelecionada != _SEM_COMANDA && 
          _comandasDaMesa.any((c) => c.comanda.id == _abaSelecionada)) {
        return; // Comanda selecionada ainda existe
      }
    }
    
    // Seleciona primeira aba disponível: "Mesa" (null) sempre primeiro se houver produtos
    // Depois "Sem Comanda" se necessário, depois comandas
    if (_comandasDaMesa.isNotEmpty || temProdutosSemComanda) {
      _abaSelecionada = null; // Aba "Mesa" (venda integral)
    } else {
      _abaSelecionada = null;
    }
  }

  /// Verifica se há produtos sem comanda (venda sem comanda)
  bool get temProdutosSemComanda => _produtosPorComanda.containsKey(_SEM_COMANDA) && 
                                     (_produtosPorComanda[_SEM_COMANDA]?.isNotEmpty ?? false);

  /// Verifica se deve mostrar a aba "Sem Comanda"
  /// Só mostra se houver produtos SEM comanda E produtos COM comanda (ambos)
  bool get deveMostrarAbaSemComanda => temProdutosSemComanda && _comandasDaMesa.isNotEmpty;

  /// Retorna a venda sem comanda (se houver)
  VendaDto? get vendaSemComanda => _vendasPorComanda[_SEM_COMANDA];


  /// Define a aba selecionada
  void setAbaSelecionada(String? comandaId) {
    if (_abaSelecionada != comandaId) {
      _abaSelecionada = comandaId;
      notifyListeners();
    }
  }

  /// Alterna expansão do histórico de pagamentos
  void toggleHistoricoPagamentos() {
    _historicoPagamentosExpandido = !_historicoPagamentosExpandido;
    notifyListeners();
  }

  /// Verifica se um evento pertence a esta entidade (mesa ou comanda)
  bool _eventoPertenceAEstaEntidade(AppEvent evento) {
    if (entidade.tipo == TipoEntidade.mesa) {
      // Para mesa: verifica se mesaId do evento corresponde
      return evento.mesaId == entidade.id;
    } else {
      // Para comanda: verifica se comandaId do evento corresponde
      return evento.comandaId == entidade.id;
    }
  }

  /// Configura listeners de eventos do AppEventBus
  /// Escuta apenas eventos relacionados à mesa/comanda que este provider controla
  void _setupEventBusListener() {
    final eventBus = AppEventBus.instance;
    
    // Escuta eventos de pedido criado (disparado pelo AutoSyncManager após salvar no Hive)
    // Apenas marca mesa como sincronizando - produtos só aparecem após sincronização
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoCriado).listen((evento) {
        if (_eventoPertenceAEstaEntidade(evento) && evento.pedidoId != null) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Pedido ${evento.pedidoId} criado');
          // Reseta flag de venda finalizada quando um novo pedido é criado
          _vendaFinalizada = false;
          // Apenas atualiza contadores - produtos só aparecem após sincronização
          _recalcularContadoresPedidos();
        }
      }),
    );
    
    // Escuta eventos de pedido sincronizando
    // Apenas atualiza contadores, não precisa recarregar produtos
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoSincronizando).listen((evento) {
        if (_eventoPertenceAEstaEntidade(evento)) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Pedido ${evento.pedidoId} sincronizando');
          if (_pedidosPendentes > 0) _pedidosPendentes--;
          _pedidosSincronizando++;
          _atualizarStatusSincronizacao();
          // NÃO recarrega produtos - pedido ainda não está no servidor
        }
      }),
    );
    
    // Escuta eventos de pedido sincronizado
    // Recarrega dados do servidor e verifica se ainda há pedidos pendentes
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoSincronizado).listen((evento) async {
        if (_eventoPertenceAEstaEntidade(evento)) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Pedido ${evento.pedidoId} sincronizado');
          
          // Atualiza contadores
          if (_pedidosSincronizando > 0) _pedidosSincronizando--;
          _recalcularContadoresPedidos();
          
          // Recarrega dados do servidor para incluir o pedido sincronizado
          await loadProdutos(refresh: true);
          
          // Verifica se ainda há pedidos pendentes após sincronização
          _recalcularContadoresPedidos();
        }
      }),
    );
    
    // Escuta eventos de pedido com erro
    // Apenas atualiza contadores, pedido ainda está na listagem local
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoErro).listen((evento) {
        if (_eventoPertenceAEstaEntidade(evento)) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Pedido ${evento.pedidoId} com erro');
          if (_pedidosSincronizando > 0) _pedidosSincronizando--;
          _pedidosComErro++;
          _atualizarStatusSincronizacao();
          // NÃO recarrega produtos - pedido ainda está na listagem local
        }
      }),
    );
    
    // Escuta eventos de pedido removido
    // Recarrega dados do servidor
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoRemovido).listen((evento) async {
        if (_eventoPertenceAEstaEntidade(evento) && evento.pedidoId != null) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Pedido ${evento.pedidoId} removido');
          // Atualiza contadores
          _recalcularContadoresPedidos();
          // Recarrega dados do servidor
          await loadProdutos(refresh: true);
        }
      }),
    );
    
    // Escuta eventos de pedido finalizado
    // Quando pedido é finalizado, apenas atualiza contadores
    // O pedido já está na listagem local, não precisa recarregar do servidor
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoFinalizado).listen((evento) {
        if (_eventoPertenceAEstaEntidade(evento)) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Pedido ${evento.pedidoId} finalizado');
          // Apenas atualiza contadores, pedido já está na listagem local
          _recalcularContadoresPedidos();
        }
      }),
    );
    
    // Escuta eventos de pagamento processado
    // Adiciona pagamento à venda local sem ir no servidor
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pagamentoProcessado).listen((evento) {
        debugPrint('🔔 [MesaDetalhesProvider] Evento pagamentoProcessado recebido: vendaId=${evento.vendaId}, mesaId=${evento.mesaId}, comandaId=${evento.comandaId}');
        debugPrint('   Entidade atual: tipo=${entidade.tipo}, id=${entidade.id}');
        debugPrint('   Pertence à entidade? ${_eventoPertenceAEstaEntidade(evento)}');
        
        if (_eventoPertenceAEstaEntidade(evento) && evento.vendaId != null) {
          debugPrint('✅ [MesaDetalhesProvider] Evento: Pagamento processado para venda ${evento.vendaId}');
          // Adiciona pagamento à venda local (sem ir no servidor)
          _adicionarPagamentoAVendaLocal(
            vendaId: evento.vendaId!,
            valor: evento.get<double>('valor') ?? 0.0,
          );
        } else {
          debugPrint('⚠️ [MesaDetalhesProvider] Evento pagamentoProcessado ignorado - não pertence à entidade ou vendaId é null');
        }
      }),
    );
    
    // Escuta eventos de venda finalizada
    // Escuta eventos de venda finalizada
    // Recarrega dados da mesa e verifica se ainda há vendas abertas antes de liberar
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.vendaFinalizada).listen((evento) async {
        if (_eventoPertenceAEstaEntidade(evento)) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Venda ${evento.vendaId} finalizada');
          
          // Recarrega dados da mesa e verifica se ainda há vendas abertas
          // Só libera a mesa se não houver nenhuma venda aberta após recarregar
          await marcarVendaFinalizada(
            comandaId: evento.comandaId,
            mesaId: evento.mesaId,
          );
        }
      }),
    );
    
    // Escuta eventos de comanda paga
    // Recarrega dados da mesa e verifica se ainda há vendas abertas antes de liberar
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.comandaPaga).listen((evento) async {
        if (_eventoPertenceAEstaEntidade(evento)) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Comanda ${evento.comandaId} paga');
          
          // Se for a comanda atual (entidade é comanda), recarrega tudo
          if (entidade.tipo == TipoEntidade.comanda && evento.comandaId == entidade.id) {
            await marcarVendaFinalizada(
              comandaId: evento.comandaId,
              mesaId: evento.mesaId,
            );
          } else if (entidade.tipo == TipoEntidade.mesa && evento.comandaId != null) {
            // Se for mesa, recarrega e verifica se ainda há vendas abertas
            await marcarVendaFinalizada(
              comandaId: evento.comandaId,
              mesaId: evento.mesaId ?? entidade.id,
            );
          }
        }
      }),
    );
    
    // Escuta eventos de mesa liberada
    // Quando mesa é liberada, limpa todos os dados e marca como livre
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.mesaLiberada).listen((evento) {
        if (entidade.tipo == TipoEntidade.mesa && evento.mesaId == entidade.id) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Mesa ${evento.mesaId} liberada');
          // Marca como finalizada e limpa todos os dados
          if (!_vendaFinalizada) {
            _vendaFinalizada = true;
          }
          _limparDadosMesa();
        }
      }),
    );
    
    // Escuta eventos de status da mesa mudou
    // NOTA: Não atualiza se a mesa já foi limpa (venda finalizada)
    // porque o status já foi atualizado localmente para "livre"
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.statusMesaMudou).listen((evento) {
        if (entidade.tipo == TipoEntidade.mesa && evento.mesaId == entidade.id) {
          debugPrint('📢 [MesaDetalhesProvider] Evento: Status da mesa mudou');
          // Se a mesa está vazia (venda foi finalizada), não precisa ir no servidor
          // porque já atualizamos o status localmente para "livre"
          if (_produtosAgrupados.isEmpty && _comandasDaMesa.isEmpty) {
            debugPrint('ℹ️ [MesaDetalhesProvider] Mesa já está limpa, ignorando atualização do servidor');
            return;
          }
          // Atualiza status da mesa apenas se ainda há dados na mesa
          _atualizarStatusMesa();
        }
      }),
    );
    
    debugPrint('✅ [MesaDetalhesProvider] Listeners de eventos configurados para ${entidade.tipo.name} ${entidade.id}');
  }

  // Métodos removidos: _adicionarPedidoLocalAListagem, _adicionarPedidoLocalAVisaoGeral, _adicionarPedidoLocalAComanda
  // Produtos de pedidos locais não aparecem mais na mesa até serem sincronizados
  
  /// Cria ou atualiza uma comanda virtual com número real do servidor
  /// Método centralizado para evitar duplicação de lógica
  Future<void> _criarOuAtualizarComandaVirtual(
    String comandaId,
    List<ProdutoAgrupado> produtos,
    double totalPedidos,
  ) async {
    try {
      // Busca comanda do servidor para pegar o número real
      final response = await comandaService.getComandaById(comandaId);
      
      String numeroComanda;
      String? codigoBarras;
      String? descricao;
      
      if (response.success && response.data != null) {
        numeroComanda = response.data!.numero;
        codigoBarras = response.data!.codigoBarras;
        descricao = response.data!.descricao;
      } else {
        // Se não conseguir buscar, usa o ID como número temporário
        numeroComanda = comandaId.substring(0, 8);
        codigoBarras = null;
        descricao = null;
      }
      
      // Usa índice otimizado para buscar comanda
      final indiceComandas = _criarIndiceComandas();
      final comandaIndex = indiceComandas[comandaId];
      
      if (comandaIndex != null) {
        // Atualiza comanda existente com número real
        _comandasDaMesa[comandaIndex] = ComandaComProdutos(
          comanda: ComandaListItemDto(
            id: comandaId,
            numero: numeroComanda,
            codigoBarras: codigoBarras,
            descricao: descricao,
            status: _comandasDaMesa[comandaIndex].comanda.status,
            ativa: _comandasDaMesa[comandaIndex].comanda.ativa,
            totalPedidosAtivos: _comandasDaMesa[comandaIndex].comanda.totalPedidosAtivos,
            valorTotalPedidosAtivos: _comandasDaMesa[comandaIndex].comanda.valorTotalPedidosAtivos,
            vendaAtualId: _comandasDaMesa[comandaIndex].comanda.vendaAtualId,
            pagamentos: _comandasDaMesa[comandaIndex].comanda.pagamentos,
          ),
          produtos: _comandasDaMesa[comandaIndex].produtos,
          venda: _comandasDaMesa[comandaIndex].venda,
        );
      } else {
        // Cria nova comanda virtual usando método auxiliar
        _criarComandaVirtualInterna(comandaId, numeroComanda, codigoBarras, descricao, produtos, totalPedidos);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [MesaDetalhesProvider] Erro ao buscar número da comanda: $e');
      // Em caso de erro, apenas cria se não existir
      final indiceComandas = _criarIndiceComandas();
      if (!indiceComandas.containsKey(comandaId)) {
        _criarComandaVirtualInterna(
          comandaId, 
          comandaId.substring(0, 8), 
          null, 
          null, 
          produtos, 
          totalPedidos
        );
        notifyListeners();
      }
    }
  }
  
  /// Método auxiliar para criar comanda virtual (evita duplicação)
  void _criarComandaVirtualInterna(
    String comandaId,
    String numeroComanda,
    String? codigoBarras,
    String? descricao,
    List<ProdutoAgrupado> produtos,
    double totalPedidos,
  ) {
    final comandaVirtual = ComandaListItemDto(
      id: comandaId,
      numero: numeroComanda,
      codigoBarras: codigoBarras,
      descricao: descricao,
      status: 'Em Uso',
      ativa: true,
      totalPedidosAtivos: 1,
      valorTotalPedidosAtivos: totalPedidos,
      vendaAtualId: null,
      pagamentos: [],
    );
    
    _produtosPorComanda[comandaId] = produtos;
    _vendasPorComanda[comandaId] = null;
    
    _comandasDaMesa.add(ComandaComProdutos(
      comanda: comandaVirtual,
      produtos: produtos,
      venda: null,
    ));
  }

  // Método removido: _removerPedidoLocalDaListagem
  // Remoção de pedidos agora é tratada via evento que recarrega do servidor

  /// Recalcula contadores de pedidos locais
  void _recalcularContadoresPedidos() {
    if (!Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
      _pedidosPendentes = 0;
      _pedidosSincronizando = 0;
      _pedidosComErro = 0;
      return;
    }
    
    final box = Hive.box<PedidoLocal>(PedidoLocalRepository.boxName);
    final pedidos = box.values.where((p) {
      if (entidade.tipo == TipoEntidade.mesa) {
        return p.mesaId == entidade.id;
      } else {
        return p.comandaId == entidade.id;
      }
    }).toList();
    
    _pedidosPendentes = pedidos.where((p) => p.syncStatus == SyncStatusPedido.pendente).length;
    _pedidosSincronizando = pedidos.where((p) => p.syncStatus == SyncStatusPedido.sincronizando).length;
    _pedidosComErro = pedidos.where((p) => p.syncStatus == SyncStatusPedido.erro).length;
    
    _atualizarStatusSincronizacao();
  }

  /// Atualiza status de sincronização e notifica listeners
  void _atualizarStatusSincronizacao() {
    notifyListeners();
    debugPrint('📊 [MesaDetalhesProvider] Status sincronização: pendentes=$_pedidosPendentes, sincronizando=$_pedidosSincronizando, erros=$_pedidosComErro');
  }

  /// Atualiza status da mesa buscando do servidor
  /// Não vai no servidor se a mesa já foi limpa (venda finalizada)
  Future<void> _atualizarStatusMesa() async {
    if (entidade.tipo != TipoEntidade.mesa) return;
    
    // Se a mesa está vazia (venda foi finalizada), não precisa ir no servidor
    // porque já atualizamos o status localmente para "livre"
    if (_produtosAgrupados.isEmpty && _comandasDaMesa.isEmpty) {
      debugPrint('ℹ️ [MesaDetalhesProvider] Mesa já está limpa, não precisa buscar status do servidor');
      return;
    }
    
    try {
      final response = await mesaService.getMesaById(entidade.id);
      if (response.success && response.data != null) {
        final novoStatus = response.data!.status.toLowerCase();
        if (_statusMesa != novoStatus) {
          _statusMesa = novoStatus;
          notifyListeners();
          debugPrint('✅ [MesaDetalhesProvider] Status da mesa atualizado: $novoStatus');
        }
      }
    } catch (e) {
      debugPrint('❌ [MesaDetalhesProvider] Erro ao atualizar status da mesa: $e');
    }
  }

  /// Agrupa um produto no mapa de produtos agrupados
  /// Método auxiliar centralizado para evitar duplicação de código
  void _agruparProdutoNoMapa(
    Map<String, ProdutoAgrupado> produtosMap,
    String produtoId,
    String produtoNome,
    String? produtoVariacaoId,
    String? produtoVariacaoNome,
    double precoUnitario,
    int quantidade, {
    List<dynamic>? variacaoAtributosValores,
  }) {
    // Validações básicas
    if (produtoId.isEmpty || quantidade <= 0) return;
    
    // Cria chave de agrupamento
    final chave = produtoVariacaoId != null && produtoVariacaoId!.isNotEmpty
        ? '$produtoId|$produtoVariacaoId'
        : produtoId;
    
    if (produtosMap.containsKey(chave)) {
      // Adiciona quantidade ao produto existente
      produtosMap[chave]!.adicionarQuantidade(quantidade);
    } else {
      // Cria novo produto agrupado
      produtosMap[chave] = ProdutoAgrupado(
        produtoId: produtoId,
        produtoNome: produtoNome,
        produtoVariacaoId: produtoVariacaoId,
        produtoVariacaoNome: produtoVariacaoNome,
        precoUnitario: precoUnitario,
        quantidadeTotal: quantidade,
        variacaoAtributosValores: variacaoAtributosValores?.cast() ?? const [],
      );
    }
  }
  
  /// Converte lista de produtos agrupados para mapa (para facilitar atualizações)
  Map<String, ProdutoAgrupado> _produtosParaMapa(List<ProdutoAgrupado> produtos) {
    final produtosMap = <String, ProdutoAgrupado>{};
    for (var produto in produtos) {
      final chave = produto.produtoVariacaoId != null && produto.produtoVariacaoId!.isNotEmpty
          ? '${produto.produtoId}|${produto.produtoVariacaoId}'
          : produto.produtoId;
      produtosMap[chave] = produto;
    }
    return produtosMap;
  }
  
  /// Converte mapa de produtos agrupados para lista ordenada
  List<ProdutoAgrupado> _mapaParaProdutosOrdenados(Map<String, ProdutoAgrupado> produtosMap) {
    return produtosMap.values.toList()
      ..sort((a, b) => a.produtoNome.compareTo(b.produtoNome));
  }
  
  /// Cria índice de comandas para busca O(1)
  /// Retorna Map<comandaId, index> para acesso rápido
  Map<String, int> _criarIndiceComandas() {
    final indice = <String, int>{};
    for (int i = 0; i < _comandasDaMesa.length; i++) {
      indice[_comandasDaMesa[i].comanda.id] = i;
    }
    return indice;
  }
  
  /// Busca pedidos locais pendentes
  List<PedidoLocal> _getPedidosLocais(Box<PedidoLocal>? box) {
    if (box == null || !Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
      return [];
    }
    
    final pedidos = box.values
        .where((p) {
          if (entidade.tipo == TipoEntidade.mesa) {
            return p.mesaId == entidade.id && 
                   p.syncStatus != SyncStatusPedido.sincronizado;
          } else {
            return p.comandaId == entidade.id && 
                   p.syncStatus != SyncStatusPedido.sincronizado;
          }
        })
        .toList();
    
    return pedidos;
  }

  /// Processa itens de um pedido completo (que já vem com itens da API)
  void _processarItensPedidoServidorCompleto(
    PedidoComItensPdvDto pedido, 
    Map<String, ProdutoAgrupado> produtosMap
  ) {
    try {
      debugPrint('    📋 Itens do pedido ${pedido.numero}: ${pedido.itens.length}');

      for (final item in pedido.itens) {
        _agruparProdutoNoMapa(
          produtosMap,
          item.produtoId,
          item.produtoNome,
          item.produtoVariacaoId,
          item.produtoVariacaoNome,
          item.precoUnitario,
          item.quantidade,
          variacaoAtributosValores: item.variacaoAtributosValores,
        );
      }
    } catch (e) {
      // Ignora erros individuais de pedidos
      debugPrint('❌ Erro ao processar itens do pedido ${pedido.numero}: $e');
    }
  }

  /// Processa itens de um pedido local
  void _processarItensPedidoLocal(
    PedidoLocal pedido, 
    Map<String, ProdutoAgrupado> produtosMap
  ) {
    for (final item in pedido.itens) {
      _agruparProdutoNoMapa(
        produtosMap,
        item.produtoId,
        item.produtoNome,
        item.produtoVariacaoId,
        item.produtoVariacaoNome,
        item.precoUnitario,
        item.quantidade,
      );
    }
  }

  /// Busca pedidos do servidor para mesa ou comanda
  /// Busca pedidos do servidor
  Future<PedidosComVendaComandasDto?> _buscarPedidosServidor() async {
    
    debugPrint('🔍 [MesaDetalhesProvider] Buscando pedidos do servidor - Tipo: ${entidade.tipo}, ID: ${entidade.id}');
    debugPrint('   Status mesa: $_statusMesa, Produtos: ${_produtosAgrupados.length}, Comandas: ${_comandasDaMesa.length}, Venda: ${_vendaAtual != null}');
    
    if (entidade.tipo == TipoEntidade.mesa) {
      final response = await pedidoService.getPedidosPorMesaCompleto(entidade.id);
      debugPrint('📥 Resposta da busca: success=${response.success}, message=${response.message}');
      if (response.success && response.data != null) {
        final resultado = response.data!;
        debugPrint('✅ Pedidos encontrados: ${resultado.pedidos.length}');
        debugPrint('✅ Comandas encontradas: ${resultado.comandas?.length ?? 0}');
        return resultado;
      } else {
        debugPrint('❌ Erro na busca: ${response.message}');
        return null;
      }
    } else {
      final response = await pedidoService.getPedidosPorComandaCompleto(entidade.id);
      debugPrint('📥 Resposta da busca: success=${response.success}, message=${response.message}');
      if (response.success && response.data != null) {
        final resultado = response.data!;
        debugPrint('✅ Pedidos encontrados: ${resultado.pedidos.length}');
        return resultado;
      } else {
        debugPrint('❌ Erro na busca: ${response.message}');
        return null;
      }
    }
  }
  
  /// Busca venda aberta para comanda (quando não vem no retorno de pedidos)
  Future<void> _buscarVendaAbertaSeNecessario() async {
    if (entidade.tipo == TipoEntidade.comanda && _vendaAtual == null) {
      debugPrint('ℹ️ Nenhuma venda encontrada na resposta da comanda, buscando venda aberta diretamente...');
      final vendaResponse = await vendaService.getVendaAbertaPorComanda(entidade.id);
      if (vendaResponse.success && vendaResponse.data != null) {
        _vendaAtual = vendaResponse.data;
        debugPrint('✅ Venda aberta encontrada diretamente: ${vendaResponse.data!.id}');
      } else {
        debugPrint('ℹ️ Nenhuma venda aberta encontrada para a comanda');
        _vendaAtual = null;
      }
    }
  }
  
  // Método removido: _buscarPedidosLocaisFiltrados
  // Pedidos locais não são mais processados para exibição - apenas contadores são atualizados

  /// Carrega produtos agrupados
  /// Se refresh=true, SEMPRE recarrega tudo do servidor sem verificações
  /// IMPORTANTE: Não limpa comandas/produtos antes de buscar - só limpa quando novos dados chegarem
  /// Isso garante que as abas não desapareçam durante o carregamento
  Future<void> loadProdutos({bool refresh = false}) async {
    debugPrint('🔍 [MesaDetalhesProvider] loadProdutos chamado - refresh: $refresh');
    
    // Evita múltiplas chamadas simultâneas (exceto quando é refresh explícito)
    if (_carregandoProdutos && !refresh) {
      debugPrint('⚠️ loadProdutos já está em execução, ignorando chamada duplicada');
      return;
    }

    // Se é refresh, limpa apenas flags e mensagens de erro
    // NÃO limpa comandas/produtos ainda - só limpa quando novos dados chegarem do servidor
    if (refresh) {
      debugPrint('🔄 Refresh completo: recarregando tudo do servidor');
      _errorMessage = null;
      _vendaFinalizada = false;
      // NÃO limpa comandas/produtos aqui - serão limpos quando novos dados chegarem
    }

    _isLoading = true;
    _carregandoProdutos = true;
    notifyListeners();

    try {
      // Busca pedidos do servidor (com itens já incluídos)
      final resultadoCompleto = await _buscarPedidosServidor();
      
      if (resultadoCompleto == null) {
        _isLoading = false;
        _carregandoProdutos = false;
        notifyListeners();
        return;
      }
      
      final pedidosServidor = resultadoCompleto.pedidos;
      
      // Atualiza venda atual se vier no retorno
      if (resultadoCompleto.venda != null) {
        _vendaAtual = resultadoCompleto.venda;
        if (entidade.tipo == TipoEntidade.comanda) {
          debugPrint('✅ Venda encontrada na resposta: ${resultadoCompleto.venda!.id}');
        }
      }
      
      // Busca venda aberta se necessário (apenas para comandas)
      await _buscarVendaAbertaSeNecessario();
      
      // SEMPRE processa comandas se houver no retorno, independente da configuração
      // Se não houver comandas, lista fica vazia e mostra apenas visão geral
      if (entidade.tipo == TipoEntidade.mesa) {
        // Processa comandas do servidor (pode ser lista vazia se não houver comandas)
        final comandasRetorno = resultadoCompleto.comandas ?? [];
        debugPrint('🔄 Processando ${comandasRetorno.length} comandas do servidor (independente da configuração)...');
        // _processarComandasDoRetorno já limpa comandas internamente antes de processar
        _processarComandasDoRetorno(
          comandasRetorno, 
          pedidosServidor
        );
      } else {
        // Se não é mesa, garante que comandas estão limpas
        _comandasDaMesa = [];
        _produtosPorComanda.clear();
        _vendasPorComanda.clear();
      }
      
      // Limpa produtos ANTES de processar novos (garante que lista seja atualizada)
      _produtosAgrupados = [];
      
      // Armazena pedidos completos para visualização por pedido
      _pedidos = List.from(pedidosServidor);

      // Atualiza contadores de status de sincronização
      _recalcularContadoresPedidos();

      // Agrupa produtos apenas dos pedidos do servidor (banco de dados)
      final Map<String, ProdutoAgrupado> produtosMap = {};
      
      // Limpa venda atual se não veio no retorno (será atualizada depois se necessário)
      if (resultadoCompleto.venda == null && entidade.tipo == TipoEntidade.mesa) {
        _vendaAtual = null;
      }

      // Processa apenas pedidos do servidor (itens já vêm na resposta)
      debugPrint('🔄 Processando ${pedidosServidor.length} pedidos do servidor...');
      for (final pedido in pedidosServidor) {
        debugPrint('  📦 Processando pedido: ${pedido.numero} (ID: ${pedido.id})');
        _processarItensPedidoServidorCompleto(pedido, produtosMap);
      }
      debugPrint('✅ Produtos agrupados após processar servidor: ${produtosMap.length}');

      // Converte map para lista ordenada usando método auxiliar
      final produtosList = _mapaParaProdutosOrdenados(produtosMap);

      debugPrint('📊 Total de produtos agrupados: ${produtosList.length}');

      _produtosAgrupados = produtosList;
      _isLoading = false;
      _errorMessage = null;
      _carregandoProdutos = false;
      notifyListeners();
      
      debugPrint('✅ Estado atualizado com ${_produtosAgrupados.length} produtos e ${_comandasDaMesa.length} comandas');
    } catch (e) {
      // Limpa produtos e comandas quando há erro para garantir recarga completa no próximo refresh
      _produtosAgrupados = [];
      _pedidos = [];
      _comandasDaMesa = [];
      _produtosPorComanda.clear();
      _vendasPorComanda.clear();
      
      // Detecta erros de conexão e cria mensagem amigável (sem stack trace)
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('connection') ||
          errorString.contains('conexão') ||
          errorString.contains('network') ||
          errorString.contains('rede') ||
          errorString.contains('timeout') ||
          errorString.contains('socket') ||
          errorString.contains('failed host lookup') ||
          errorString.contains('no internet') ||
          errorString.contains('sem internet') ||
          (e.toString().contains('DioException') && errorString.contains('connection'))) {
        _errorMessage = 'Erro de conexão com o servidor';
      } else {
        // Extrai apenas a mensagem principal do erro, sem stack trace
        final errorMsg = e.toString();
        // Remove stack trace se presente (geralmente vem após #0 ou #1)
        final cleanMessage = errorMsg.split('#0').first.trim();
        // Se ainda for muito longo, pega apenas a primeira linha
        final firstLine = cleanMessage.split('\n').first.trim();
        _errorMessage = firstLine.length > 100 
            ? 'Erro ao carregar produtos: ${firstLine.substring(0, 100)}...'
            : 'Erro ao carregar produtos: $firstLine';
      }
      
      _isLoading = false;
      _carregandoProdutos = false;
      _carregandoComandas = false;
      notifyListeners();
    }
  }

  /// Processa comandas usando dados já retornados (evita chamada duplicada)
  /// Processa apenas comandas do servidor (banco de dados)
  /// IMPORTANTE: Sempre limpa comandas ANTES de processar novas para garantir atualização das abas
  /// Também processa pedidos sem comanda e cria aba "Sem Comanda" se necessário
  void _processarComandasDoRetorno(
    List<ComandaListItemDto> comandasRetorno, 
    List<PedidoComItensPdvDto> pedidos,
  ) {
    _carregandoComandas = true;
    notifyListeners();

    try {
      // SEMPRE limpa comandas antes de processar novas (garante que abas sejam atualizadas)
      _comandasDaMesa = [];
      _produtosPorComanda.clear();
      _vendasPorComanda.clear();
      
      // Cria um mapa de comandas processando apenas dados do servidor
      final comandasMap = <String, ComandaComProdutos>{};
      
      // Processa apenas comandas do servidor (banco de dados)
      for (final comanda in comandasRetorno) {
        // Agrupa produtos dos pedidos dessa comanda (servidor)
        final produtosMap = <String, ProdutoAgrupado>{};
        
        for (final pedido in pedidos) {
          // Só processa pedidos desta comanda
          if (pedido.comandaId != comanda.id) continue;
          
          for (final item in pedido.itens) {
            _agruparProdutoNoMapa(
              produtosMap,
              item.produtoId,
              item.produtoNome,
              item.produtoVariacaoId,
              item.produtoVariacaoNome,
              item.precoUnitario,
              item.quantidade,
              variacaoAtributosValores: item.variacaoAtributosValores,
            );
          }
        }
        
        final produtos = _mapaParaProdutosOrdenados(produtosMap);

        // Usa venda que já vem no objeto comanda se disponível
        VendaDto? vendaComanda = comanda.vendaAtual;

        comandasMap[comanda.id] = ComandaComProdutos(
          comanda: comanda,
          produtos: produtos,
          venda: vendaComanda,
        );
        
        // Popula o mapa de produtos por comanda
        _produtosPorComanda[comanda.id] = produtos;
        _vendasPorComanda[comanda.id] = vendaComanda;
      }
      
      // Processa pedidos SEM comanda (venda sem comanda)
      final produtosSemComandaMap = <String, ProdutoAgrupado>{};
      for (final pedido in pedidos) {
        // Só processa pedidos sem comanda (comandaId é null ou vazio)
        if (pedido.comandaId != null && pedido.comandaId!.isNotEmpty) continue;
        
        debugPrint('📦 Processando pedido sem comanda: ${pedido.numero}');
        
        for (final item in pedido.itens) {
          _agruparProdutoNoMapa(
            produtosSemComandaMap,
            item.produtoId,
            item.produtoNome,
            item.produtoVariacaoId,
            item.produtoVariacaoNome,
            item.precoUnitario,
            item.quantidade,
            variacaoAtributosValores: item.variacaoAtributosValores,
          );
        }
      }
      
      // Se há produtos sem comanda, cria entrada na aba "Sem Comanda"
      if (produtosSemComandaMap.isNotEmpty) {
        final produtosSemComanda = _mapaParaProdutosOrdenados(produtosSemComandaMap);
        
        // Usa a venda atual (que deve ser a venda sem comanda)
        // Se não houver venda atual, será null e será buscada quando necessário
        _produtosPorComanda[_SEM_COMANDA] = produtosSemComanda;
        _vendasPorComanda[_SEM_COMANDA] = _vendaAtual;
        
        debugPrint('✅ Produtos sem comanda processados: ${produtosSemComanda.length} produtos');
        debugPrint('   Venda sem comanda: ${_vendaAtual?.id ?? "null"}');
      }
      
      // Converte mapa para lista
      final comandasComProdutos = comandasMap.values.toList();

      _comandasDaMesa = comandasComProdutos;
      _carregandoComandas = false;
      
      // Seleciona automaticamente a primeira aba disponível
      _selecionarPrimeiraAbaDisponivel();
      
      debugPrint('✅ Comandas processadas: ${_comandasDaMesa.length} comandas com produtos');
      debugPrint('✅ Aba "Sem Comanda": ${temProdutosSemComanda ? "SIM" : "NÃO"}');
      debugPrint('✅ Aba selecionada: ${_abaSelecionada ?? "NENHUMA"}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erro ao processar comandas: $e');
      // Em caso de erro, limpa comandas para garantir estado consistente
      _comandasDaMesa = [];
      _produtosPorComanda.clear();
      _vendasPorComanda.clear();
      _carregandoComandas = false;
      notifyListeners();
    }
  }

  /// Carrega venda atual
  Future<void> loadVendaAtual() async {
    try {
      
      if (entidade.tipo == TipoEntidade.mesa) {
        final response = await mesaService.getMesaById(entidade.id);
        if (response.success && response.data != null) {
          _vendaAtual = response.data!.vendaAtual;
          notifyListeners();
        }
      } else {
        // Para comanda, primeiro tenta buscar pela comanda (pode ter vendaAtual)
        final response = await comandaService.getComandaById(entidade.id);
        if (response.success && response.data != null) {
          // Se a comanda retornou vendaAtual, usa ela
          if (response.data!.vendaAtual != null) {
            _vendaAtual = response.data!.vendaAtual;
            notifyListeners();
          } else {
            // Se não retornou vendaAtual, busca venda aberta diretamente
            debugPrint('🔍 Comanda não retornou vendaAtual, buscando venda aberta diretamente...');
            final vendaResponse = await vendaService.getVendaAbertaPorComanda(entidade.id);
            if (vendaResponse.success && vendaResponse.data != null) {
              _vendaAtual = vendaResponse.data;
              notifyListeners();
              debugPrint('✅ Venda aberta encontrada diretamente: ${vendaResponse.data!.id}');
            } else {
              debugPrint('ℹ️ Nenhuma venda aberta encontrada para a comanda');
              _vendaAtual = null;
              notifyListeners();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar venda atual: $e');
    }
  }

  /// Busca venda aberta quando necessário e atualiza o estado apropriado
  /// Retorna a venda encontrada ou null se não encontrada
  Future<VendaDto?> buscarVendaAberta() async {
    String? comandaIdParaBuscar;
    
    if (entidade.tipo == TipoEntidade.comanda) {
      // Se entidade é comanda diretamente, usa o ID da entidade
      comandaIdParaBuscar = entidade.id;
    } else if (_abaSelecionada != null) {
      // Se há aba selecionada (comanda específica), usa o ID da aba
      comandaIdParaBuscar = _abaSelecionada;
    }
    
    if (comandaIdParaBuscar == null) {
      debugPrint('⚠️ Não foi possível determinar comanda para buscar venda');
      return null;
    }
    
    debugPrint('🔍 Buscando venda aberta para comanda: $comandaIdParaBuscar');
    final vendaResponse = await vendaService.getVendaAbertaPorComanda(comandaIdParaBuscar);
    
    if (vendaResponse.success && vendaResponse.data != null) {
      final venda = vendaResponse.data!;
      // Atualiza o estado apropriado
      if (_abaSelecionada == null) {
        _vendaAtual = venda;
      } else {
        _vendasPorComanda[_abaSelecionada!] = venda;
      }
      notifyListeners();
      debugPrint('✅ Venda aberta encontrada: ${venda.id}');
      return venda;
    } else {
      debugPrint('❌ Nenhuma venda aberta encontrada para comanda: $comandaIdParaBuscar');
      return null;
    }
  }

  /// Cria uma nova instância de VendaDto copiando todos os campos da original
  /// e substituindo apenas a lista de pagamentos
  /// Método auxiliar para evitar duplicação de código
  VendaDto _criarVendaComPagamentoAtualizado(
    VendaDto vendaOriginal,
    List<PagamentoVendaDto> pagamentosAtualizados,
  ) {
    return VendaDto(
      id: vendaOriginal.id,
      empresaId: vendaOriginal.empresaId,
      mesaId: vendaOriginal.mesaId,
      comandaId: vendaOriginal.comandaId,
      veiculoId: vendaOriginal.veiculoId,
      mesaNome: vendaOriginal.mesaNome,
      comandaCodigo: vendaOriginal.comandaCodigo,
      veiculoPlaca: vendaOriginal.veiculoPlaca,
      contextoNome: vendaOriginal.contextoNome,
      contextoDescricao: vendaOriginal.contextoDescricao,
      clienteId: vendaOriginal.clienteId,
      clienteNome: vendaOriginal.clienteNome,
      clienteCPF: vendaOriginal.clienteCPF,
      clienteCNPJ: vendaOriginal.clienteCNPJ,
      status: vendaOriginal.status,
      dataCriacao: vendaOriginal.dataCriacao,
      dataFechamento: vendaOriginal.dataFechamento,
      dataPagamento: vendaOriginal.dataPagamento,
      dataCancelamento: vendaOriginal.dataCancelamento,
      subtotal: vendaOriginal.subtotal,
      descontoTotal: vendaOriginal.descontoTotal,
      acrescimoTotal: vendaOriginal.acrescimoTotal,
      impostosTotal: vendaOriginal.impostosTotal,
      freteTotal: vendaOriginal.freteTotal,
      valorTotal: vendaOriginal.valorTotal,
      pagamentos: pagamentosAtualizados,
    );
  }

  /// Adiciona um pagamento à venda local sem ir no servidor
  /// Atualiza a venda em memória com o novo pagamento e recalcula saldo
  void _adicionarPagamentoAVendaLocal({
    required String vendaId,
    required double valor,
  }) {
    try {
      debugPrint('💰 [MesaDetalhesProvider] Adicionando pagamento local: vendaId=$vendaId, valor=$valor');
      debugPrint('   Venda atual: ${_vendaAtual?.id}, Vendas por comanda: ${_vendasPorComanda.keys.toList()}');
      
      // Cria um pagamento temporário com dados mínimos
      // Quando carregar do servidor, virá com todos os dados completos
      final pagamentoTemporario = PagamentoVendaDto(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        vendaId: vendaId,
        tipoFormaPagamento: 2, // Cartão (padrão, será atualizado quando buscar do servidor)
        formaPagamento: 'Pagamento',
        valor: valor,
        status: 2, // StatusPagamento.Confirmado = 2
        dataPagamento: DateTime.now(),
        dataConfirmacao: DateTime.now(),
      );

      // Atualiza venda atual se for a mesma
      if (_vendaAtual != null && _vendaAtual!.id == vendaId) {
        final pagamentosAtualizados = List<PagamentoVendaDto>.from(_vendaAtual!.pagamentos);
        pagamentosAtualizados.add(pagamentoTemporario);
        
        _vendaAtual = _criarVendaComPagamentoAtualizado(_vendaAtual!, pagamentosAtualizados);
        
        debugPrint('✅ [MesaDetalhesProvider] Pagamento adicionado à venda atual. Total pagamentos: ${pagamentosAtualizados.length}, Saldo restante: ${_vendaAtual!.saldoRestante}');
      } else {
        debugPrint('⚠️ [MesaDetalhesProvider] Venda atual não encontrada ou não corresponde (vendaId atual: ${_vendaAtual?.id})');
      }

      // Atualiza vendas por comanda se necessário
      bool encontrouVendaEmComanda = false;
      for (final entry in _vendasPorComanda.entries) {
        final venda = entry.value;
        if (venda != null && venda.id == vendaId) {
          encontrouVendaEmComanda = true;
          final pagamentosAtualizados = List<PagamentoVendaDto>.from(venda.pagamentos);
          pagamentosAtualizados.add(pagamentoTemporario);
          
          final vendaAtualizada = _criarVendaComPagamentoAtualizado(venda, pagamentosAtualizados);
          _vendasPorComanda[entry.key] = vendaAtualizada;
          
          debugPrint('✅ [MesaDetalhesProvider] Pagamento adicionado à venda da comanda ${entry.key}. Total pagamentos: ${pagamentosAtualizados.length}, Saldo restante: ${vendaAtualizada.saldoRestante}');
          
          // IMPORTANTE: Atualiza também o campo venda dentro de ComandaComProdutos
          // para que a UI reflita a mudança imediatamente
          final comandaIndex = _comandasDaMesa.indexWhere((c) => c.comanda.id == entry.key);
          if (comandaIndex != -1) {
            final comandaExistente = _comandasDaMesa[comandaIndex];
            _comandasDaMesa[comandaIndex] = ComandaComProdutos(
              comanda: comandaExistente.comanda,
              produtos: comandaExistente.produtos,
              venda: vendaAtualizada, // Atualiza venda com pagamentos atualizados
            );
            debugPrint('✅ [MesaDetalhesProvider] Venda atualizada na comanda ${entry.key} da listagem (_comandasDaMesa). Saldo restante: ${vendaAtualizada.saldoRestante}');
          } else {
            debugPrint('⚠️ [MesaDetalhesProvider] Comanda ${entry.key} não encontrada em _comandasDaMesa (total: ${_comandasDaMesa.length})');
          }
        }
      }
      
      if (!encontrouVendaEmComanda && _vendaAtual?.id != vendaId) {
        debugPrint('⚠️ [MesaDetalhesProvider] Venda $vendaId não encontrada nem em _vendaAtual nem em _vendasPorComanda');
        debugPrint('   Vendas por comanda disponíveis: ${_vendasPorComanda.entries.map((e) => '${e.key}: ${e.value?.id}').join(', ')}');
      }

      debugPrint('🔄 [MesaDetalhesProvider] Chamando notifyListeners() após adicionar pagamento');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [MesaDetalhesProvider] Erro ao adicionar pagamento à venda local: $e');
    }
  }

  /// Remove uma comanda específica da listagem quando ela é finalizada
  /// Remove também pagamentos e produtos daquela comanda
  /// Se não sobrar mais nenhuma comanda/pedido, libera a mesa completamente
  void _removerComandaDaListagem(String comandaId) {
    try {
      debugPrint('🧹 [MesaDetalhesProvider] Removendo comanda $comandaId da listagem (incluindo pagamentos)');
      
      // Remove comanda da listagem
      _comandasDaMesa.removeWhere((c) => c.comanda.id == comandaId);
      
      // Remove produtos da comanda
      _produtosPorComanda.remove(comandaId);
      
      // Remove venda da comanda (inclui pagamentos)
      _vendasPorComanda.remove(comandaId);
      
      // Se a aba selecionada era essa comanda, reseta para visão geral
      if (_abaSelecionada == comandaId) {
        _abaSelecionada = null;
      }
      
      // Recalcula produtos agrupados da visão geral (remove produtos dessa comanda)
      _recalcularProdutosAgrupadosVisaoGeral();
      
      debugPrint('✅ [MesaDetalhesProvider] Comanda $comandaId removida da listagem');
      debugPrint('   Comandas restantes: ${_comandasDaMesa.length}');
      debugPrint('   Produtos agrupados: ${_produtosAgrupados.length}');
      
      // NOTA: O evento mesaLiberada será disparado pelo método marcarVendaFinalizada()
      // quando ele verificar que não há mais comandas/pedidos
      // Este método apenas remove a comanda, não dispara eventos
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [MesaDetalhesProvider] Erro ao remover comanda da listagem: $e');
    }
  }

  /// Recalcula produtos agrupados da visão geral após remover uma comanda
  /// Processa apenas produtos das comandas do servidor (banco de dados)
  void _recalcularProdutosAgrupadosVisaoGeral() {
    try {
      // Agrupa produtos apenas das comandas restantes (do servidor)
      final produtosMap = <String, ProdutoAgrupado>{};
      
      for (final comanda in _comandasDaMesa) {
        for (final produto in comanda.produtos) {
          _agruparProdutoNoMapa(
            produtosMap,
            produto.produtoId,
            produto.produtoNome,
            produto.produtoVariacaoId,
            produto.produtoVariacaoNome,
            produto.precoUnitario,
            produto.quantidadeTotal,
            variacaoAtributosValores: produto.variacaoAtributosValores,
          );
        }
      }
      
      _produtosAgrupados = _mapaParaProdutosOrdenados(produtosMap);
    } catch (e) {
      debugPrint('❌ [MesaDetalhesProvider] Erro ao recalcular produtos agrupados: $e');
    }
  }

  /// Flag para indicar que a venda foi finalizada e mesa está limpa
  /// Usado para evitar chamadas desnecessárias ao servidor
  bool _vendaFinalizada = false;

  /// Marca venda como finalizada e recarrega dados da mesa
  /// Recarrega completamente os dados do servidor para verificar se ainda há vendas abertas
  /// Só libera a mesa se não houver nenhuma venda aberta após recarregar
  /// Independente da configuração de controle por comanda
  Future<void> marcarVendaFinalizada({String? comandaId, String? mesaId}) async {
    debugPrint('🚨 [MesaDetalhesProvider] Venda finalizada - comandaId: $comandaId, mesaId: $mesaId');
    debugPrint('🔄 [MesaDetalhesProvider] Recarregando dados da mesa para verificar se ainda há vendas abertas...');
    
    // Determina mesaId se não foi fornecido
    String? mesaIdParaVerificacao = mesaId;
    if (mesaIdParaVerificacao == null) {
      if (entidade.tipo == TipoEntidade.mesa) {
        mesaIdParaVerificacao = entidade.id;
      } else if (entidade.tipo == TipoEntidade.comanda) {
        mesaIdParaVerificacao = _vendaAtual?.mesaId;
        if (mesaIdParaVerificacao == null && _vendasPorComanda.isNotEmpty) {
          for (final venda in _vendasPorComanda.values) {
            if (venda?.mesaId != null) {
              mesaIdParaVerificacao = venda!.mesaId;
              break;
            }
          }
        }
        if (mesaIdParaVerificacao == null && _comandasDaMesa.isNotEmpty) {
          mesaIdParaVerificacao = _comandasDaMesa.first.venda?.mesaId;
        }
      }
    }
    
    // Recarrega completamente os dados da mesa do servidor
    // Isso garante que temos o estado real após a finalização da venda
    // Não remove nada localmente antes - o servidor já refletiu a finalização
    await loadProdutos(refresh: true);
    
    // Verifica se ainda há vendas/comandas/pedidos abertos após recarregar
    // Verifica TODAS as fontes possíveis de vendas abertas
    final aindaHaVendasAbertas = _comandasDaMesa.isNotEmpty || 
                                  temProdutosSemComanda ||
                                  _produtosAgrupados.isNotEmpty ||
                                  _pedidosPendentes > 0 ||
                                  _pedidosSincronizando > 0 ||
                                  _pedidosComErro > 0 ||
                                  _vendaAtual != null ||
                                  _vendasPorComanda.isNotEmpty;
    
    debugPrint('🔍 [MesaDetalhesProvider] Verificação após recarregar:');
    debugPrint('   Comandas: ${_comandasDaMesa.length}');
    debugPrint('   Produtos sem comanda: ${temProdutosSemComanda}');
    debugPrint('   Produtos agrupados: ${_produtosAgrupados.length}');
    debugPrint('   Pedidos pendentes: $_pedidosPendentes');
    debugPrint('   Pedidos sincronizando: $_pedidosSincronizando');
    debugPrint('   Pedidos com erro: $_pedidosComErro');
    debugPrint('   Venda atual: ${_vendaAtual != null}');
    debugPrint('   Vendas por comanda: ${_vendasPorComanda.length}');
    debugPrint('   Ainda há vendas abertas: $aindaHaVendasAbertas');
    
    // Só libera a mesa se não houver nenhuma venda aberta
    // Independente da configuração de controle por comanda
    if (!aindaHaVendasAbertas && mesaIdParaVerificacao != null) {
      debugPrint('✅ [MesaDetalhesProvider] Não há mais vendas abertas, liberando mesa $mesaIdParaVerificacao');
      _vendaFinalizada = true;
      _limparDadosMesa();
      
      // Dispara evento mesaLiberada
      AppEventBus.instance.dispararMesaLiberada(mesaId: mesaIdParaVerificacao);
    } else if (aindaHaVendasAbertas) {
      debugPrint('ℹ️ [MesaDetalhesProvider] Ainda há vendas abertas na mesa, não liberando');
      // Seleciona automaticamente a primeira aba disponível após recarregar
      _selecionarPrimeiraAbaDisponivel();
    }
  }

  /// Limpa todos os dados da mesa quando venda é finalizada
  /// Reseta produtos, comandas, vendas e deixa mesa livre (sem ir no servidor)
  void _limparDadosMesa() {
    try {
      debugPrint('🧹 [MesaDetalhesProvider] Limpando dados da mesa após venda finalizada');
      
      // Flag já foi setada por marcarVendaFinalizada() ou pelo listener
      // Não precisa setar novamente aqui (evita duplicação)
      
      // Limpa produtos
      _produtosAgrupados = [];
      _produtosPorComanda.clear();
      
      // Limpa comandas
      _comandasDaMesa = [];
      
      // Limpa vendas
      _vendaAtual = null;
      _vendasPorComanda.clear();
      
      // Reseta aba selecionada
      _abaSelecionada = null;
      
      // Atualiza status da mesa para livre
      _statusMesa = 'livre';
      
      // Limpa pedidos processados
      _pedidosProcessados.clear();
      
      // Reseta contadores
      _pedidosPendentes = 0;
      _pedidosSincronizando = 0;
      _pedidosComErro = 0;
      
      // Reseta flags de loading
      _isLoading = false;
      _carregandoProdutos = false;
      _carregandoComandas = false;
      _errorMessage = null;
      
      debugPrint('✅ [MesaDetalhesProvider] Dados da mesa limpos. Mesa agora está livre');
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [MesaDetalhesProvider] Erro ao limpar dados da mesa: $e');
    }
  }

  @override
  void dispose() {
    // Cancela todas as subscriptions de eventos
    for (final subscription in _eventBusSubscriptions) {
      subscription.cancel();
    }
    _eventBusSubscriptions.clear();
    super.dispose();
  }
}
