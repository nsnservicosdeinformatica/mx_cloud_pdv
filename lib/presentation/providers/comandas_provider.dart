import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/modules/restaurante/comanda_list_item.dart';
import '../../data/models/modules/restaurante/comanda_filter.dart';
import '../../data/services/modules/restaurante/comanda_service.dart';
import '../../data/repositories/pedido_local_repository.dart';
import '../../data/models/local/pedido_local.dart';
import '../../data/models/local/sync_status_pedido.dart';
import '../../presentation/providers/services_provider.dart';
import '../../core/events/app_event_bus.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Status calculado de uma comanda (fonte única de verdade)
/// Agrega informações de todos os pedidos da comanda
class ComandaStatusCalculado {
  final String comandaId;
  final String statusVisual; // 'livre', 'em uso', etc.
  
  // Contadores por status
  final int pedidosPendentes;
  final int pedidosSincronizando;
  final int pedidosComErro;
  final int pedidosSincronizados;
  
  final DateTime? ultimaAtualizacao;
  final bool temPedidosRecemSincronizados;

  ComandaStatusCalculado({
    required this.comandaId,
    required this.statusVisual,
    required this.pedidosPendentes,
    this.pedidosSincronizando = 0,
    this.pedidosComErro = 0,
    this.pedidosSincronizados = 0,
    this.ultimaAtualizacao,
    this.temPedidosRecemSincronizados = false,
  });
  
  /// Retorna total de pedidos locais (pendentes + sincronizando + erros)
  int get totalPedidosLocais => pedidosPendentes + pedidosSincronizando + pedidosComErro;
  
  /// Retorna se comanda tem pedidos que precisam atenção
  bool get temPedidosPendentesOuErro => pedidosPendentes > 0 || pedidosComErro > 0;
  
  /// Retorna se comanda está sincronizando
  bool get estaSincronizando => pedidosSincronizando > 0;
}

/// Provider centralizado para gerenciar estado de comandas
/// ÚNICA FONTE DE VERDADE para status de comandas
class ComandasProvider extends ChangeNotifier {
  final ComandaService comandaService;
  final PedidoLocalRepository pedidoRepo;
  final ServicesProvider servicesProvider;

  ComandasProvider({
    required this.comandaService,
    required this.pedidoRepo,
    required this.servicesProvider,
  });

  // Estado de comandas do servidor
  List<ComandaListItemDto> _comandas = [];
  List<ComandaListItemDto> _filteredComandas = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  final int _pageSize = 1000;
  bool _hasMore = true;
  ComandaListItemDto? _selectedComanda;

  // Estado calculado de cada comanda (fonte única de verdade)
  final Map<String, ComandaStatusCalculado> _statusCalculadoPorComanda = {};
  
  // Listeners
  List<StreamSubscription<AppEvent>> _eventBusSubscriptions = [];
  Timer? _debounceTimer;
  final Set<String> _comandasPendentesAtualizacao = {};
  bool _isInitialized = false;

  // Getters
  List<ComandaListItemDto> get comandas => _comandas;
  List<ComandaListItemDto> get filteredComandas => _filteredComandas;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ComandaListItemDto? get selectedComanda => _selectedComanda;
  bool get hasMore => _hasMore;

  /// Obtém o status calculado de uma comanda (sempre atualizado)
  ComandaStatusCalculado? getStatusCalculado(String comandaId) {
    return _statusCalculadoPorComanda[comandaId];
  }

  /// Obtém o status visual de uma comanda (usa status calculado se disponível)
  String getStatusVisualComanda(ComandaListItemDto comanda) {
    final statusCalculado = _statusCalculadoPorComanda[comanda.id];
    if (statusCalculado != null) {
      return statusCalculado.statusVisual;
    }
    // Fallback: usa status do servidor ou calcula na hora
    return _calcularStatusVisual(comanda.id, comanda);
  }

  /// Obtém número de pedidos pendentes de uma comanda
  int getPedidosPendentesCount(String comandaId) {
    return _statusCalculadoPorComanda[comandaId]?.pedidosPendentes ?? 0;
  }

  /// Inicializa o provider e configura todos os listeners
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ ComandasProvider já está inicializado');
      return;
    }

    debugPrint('🚀 Inicializando ComandasProvider...');
    
    try {
      // 1. Garante que a box está aberta
      await pedidoRepo.getAll();
      
      // 2. Configura listener de eventos de negócio (Event Bus)
      _setupEventBusListener();
      
      // 3. Carrega comandas iniciais
      await loadComandas();
      
      // 4. Calcula status inicial de todas as comandas
      _recalcularStatusTodasComandas();
      
      // 5. Seleciona automaticamente comanda com pedidos pendentes
      _selecionarComandaComPedidosPendentes();
      
      _isInitialized = true;
      debugPrint('✅ ComandasProvider inicializado com sucesso');
    } catch (e) {
      debugPrint('❌ Erro ao inicializar ComandasProvider: $e');
      _errorMessage = 'Erro ao inicializar: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Configura listener de eventos de negócio (Event Bus)
  /// Escuta TODOS os eventos relacionados a pedidos e comandas
  void _setupEventBusListener() {
    final eventBus = AppEventBus.instance;
    
    // Escuta eventos de pedido criado
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoCriado).listen((evento) {
        if (evento.comandaId != null) {
          debugPrint('📢 [ComandasProvider] Evento: Pedido ${evento.pedidoId} criado na comanda ${evento.comandaId}');
          _recalcularStatusComanda(evento.comandaId!);
        }
      }),
    );
    
    // Escuta eventos de pedido sincronizando
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoSincronizando).listen((evento) {
        if (evento.comandaId != null) {
          debugPrint('📢 [ComandasProvider] Evento: Pedido ${evento.pedidoId} sincronizando na comanda ${evento.comandaId}');
          _recalcularStatusComanda(evento.comandaId!);
        }
      }),
    );
    
    // Escuta eventos de pedido sincronizado
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoSincronizado).listen((evento) {
        if (evento.comandaId != null) {
          debugPrint('📢 [ComandasProvider] Evento: Pedido ${evento.pedidoId} sincronizado na comanda ${evento.comandaId}');
          _recalcularStatusComanda(evento.comandaId!);
          _agendarAtualizacaoServidor(evento.comandaId!);
        }
      }),
    );
    
    // Escuta eventos de pedido com erro
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoErro).listen((evento) {
        if (evento.comandaId != null) {
          debugPrint('📢 [ComandasProvider] Evento: Pedido ${evento.pedidoId} com erro na comanda ${evento.comandaId}');
          _recalcularStatusComanda(evento.comandaId!);
        }
      }),
    );
    
    // Escuta eventos de pedido removido
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoRemovido).listen((evento) {
        if (evento.comandaId != null) {
          debugPrint('📢 [ComandasProvider] Evento: Pedido ${evento.pedidoId} removido da comanda ${evento.comandaId}');
          _recalcularStatusComanda(evento.comandaId!);
        }
      }),
    );
    
    debugPrint('✅ Listener do Event Bus configurado para comandas');
  }

  /// Agenda atualização do servidor para uma comanda específica (com debounce)
  void _agendarAtualizacaoServidor(String comandaId) {
    _comandasPendentesAtualizacao.add(comandaId);
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 2000), () {
      final comandasParaAtualizar = _comandasPendentesAtualizacao.toList();
      _comandasPendentesAtualizacao.clear();
      
      if (comandasParaAtualizar.isEmpty) return;
      
      // Verifica se ainda há pedidos locais antes de atualizar do servidor
      bool podeAtualizar = true;
      for (final id in comandasParaAtualizar) {
        final status = _statusCalculadoPorComanda[id];
        if (status != null && status.totalPedidosLocais > 0) {
          podeAtualizar = false;
          debugPrint('⏳ Comanda $id ainda tem ${status.totalPedidosLocais} pedido(s) local(is), não atualizando do servidor');
          break;
        }
      }
      
      if (podeAtualizar) {
        debugPrint('🔄 Atualizando ${comandasParaAtualizar.length} comanda(s) do servidor...');
        _atualizarComandasDoServidor(comandasParaAtualizar);
      }
    });
  }

  /// Recalcula status de uma comanda específica
  /// Lê todos os pedidos da comanda do Hive e calcula status baseado em regras de prioridade
  void _recalcularStatusComanda(String comandaId) {
    if (!Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
      debugPrint('⚠️ Box não está aberta, não é possível recalcular status');
      return;
    }

    final box = Hive.box<PedidoLocal>(PedidoLocalRepository.boxName);
    final pedidos = box.values.where((p) => p.comandaId == comandaId).toList();
    
    // Conta pedidos por status
    final pedidosPendentes = pedidos.where((p) => 
      p.syncStatus == SyncStatusPedido.pendente
    ).length;
    
    final pedidosSincronizando = pedidos.where((p) => 
      p.syncStatus == SyncStatusPedido.sincronizando
    ).length;
    
    final pedidosComErro = pedidos.where((p) => 
      p.syncStatus == SyncStatusPedido.erro
    ).length;
    
    final pedidosSincronizados = pedidos.where((p) => 
      p.syncStatus == SyncStatusPedido.sincronizado
    ).length;
    
    // Verifica pedidos recém-sincronizados (últimos 10 segundos)
    final pedidosRecemSincronizados = pedidos.where((p) =>
      p.syncStatus == SyncStatusPedido.sincronizado &&
      p.syncedAt != null &&
      DateTime.now().difference(p.syncedAt!).inSeconds < 10
    ).isNotEmpty;
    
    // Determina status visual baseado em regras de prioridade
    // Prioridade: pedidos locais > status do servidor
    String statusVisual;
    final comandaIndex = _comandas.indexWhere((c) => c.id == comandaId);
    final comanda = comandaIndex != -1 ? _comandas[comandaIndex] : null;
    
    if (pedidosPendentes > 0 || pedidosSincronizando > 0 || pedidosComErro > 0) {
      // Tem pedidos locais → Comanda em uso
      statusVisual = 'em uso';
    } else if (pedidosRecemSincronizados) {
      // Tem pedidos recém-sincronizados → Mantém em uso temporariamente
      statusVisual = 'em uso';
    } else if (comanda != null) {
      // Usa status do servidor
      statusVisual = comanda.status.toLowerCase();
    } else {
      // Fallback: usa status anterior ou 'livre'
      final statusAnterior = _statusCalculadoPorComanda[comandaId];
      statusVisual = statusAnterior?.statusVisual ?? 'livre';
    }
    
    // Atualiza status calculado com todos os contadores
    _statusCalculadoPorComanda[comandaId] = ComandaStatusCalculado(
      comandaId: comandaId,
      statusVisual: statusVisual,
      pedidosPendentes: pedidosPendentes,
      pedidosSincronizando: pedidosSincronizando,
      pedidosComErro: pedidosComErro,
      pedidosSincronizados: pedidosSincronizados,
      ultimaAtualizacao: DateTime.now(),
      temPedidosRecemSincronizados: pedidosRecemSincronizados,
    );
    
    // Notifica listeners (UI será atualizada)
    notifyListeners();
    
    debugPrint('✅ Status recalculado para comanda $comandaId: $statusVisual');
    debugPrint('   📊 Contadores: pendentes=$pedidosPendentes, sincronizando=$pedidosSincronizando, erros=$pedidosComErro, sincronizados=$pedidosSincronizados');
  }

  /// Recalcula status de todas as comandas
  void _recalcularStatusTodasComandas() {
    debugPrint('🔄 Recalculando status de ${_comandas.length} comandas...');
    for (final comanda in _comandas) {
      _recalcularStatusComanda(comanda.id);
    }
    debugPrint('✅ Status de todas as comandas recalculado');
  }

  /// Calcula status visual sem cache (fallback)
  String _calcularStatusVisual(String comandaId, ComandaListItemDto? comanda) {
    if (comanda != null) {
      return comanda.status.toLowerCase();
    }
    
    if (!Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
      return 'livre';
    }

    final box = Hive.box<PedidoLocal>(PedidoLocalRepository.boxName);
    final temPedidosPendentes = box.values.any((p) =>
      p.comandaId == comandaId &&
      (p.syncStatus == SyncStatusPedido.pendente || 
       p.syncStatus == SyncStatusPedido.sincronizando)
    );
    
    return temPedidosPendentes ? 'em uso' : 'livre';
  }

  /// Atualiza comandas específicas do servidor
  Future<void> _atualizarComandasDoServidor(List<String> comandaIds) async {
    // Por enquanto, apenas recarrega todas as comandas
    // Pode ser otimizado no futuro para buscar apenas as específicas
    await loadComandas(refresh: true);
  }

  /// Seleciona automaticamente a comanda que tem pedidos pendentes (mais recente)
  void _selecionarComandaComPedidosPendentes() {
    if (!Hive.isBoxOpen(PedidoLocalRepository.boxName) || _comandas.isEmpty) {
      return;
    }

    try {
      final box = Hive.box<PedidoLocal>(PedidoLocalRepository.boxName);
      final pedidosPendentes = box.values
          .where((p) => 
              p.comandaId != null && 
              p.comandaId!.isNotEmpty &&
              p.syncStatus != SyncStatusPedido.sincronizado)
          .toList();

      if (pedidosPendentes.isEmpty) {
        return;
      }

      // Ordena por data de criação (mais recente primeiro)
      pedidosPendentes.sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
      
      // Pega a comanda do pedido mais recente
      final comandaIdMaisRecente = pedidosPendentes.first.comandaId!;
      
      // Busca a comanda na lista
      try {
        final comanda = _comandas.firstWhere(
          (c) => c.id == comandaIdMaisRecente,
        );
        
        _selectedComanda = comanda;
        notifyListeners();
        debugPrint('✅ Comanda ${comanda.numero} selecionada automaticamente (tem pedidos pendentes)');
      } catch (e) {
        debugPrint('⚠️ Comanda $comandaIdMaisRecente não encontrada na lista: $e');
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao selecionar comanda com pedidos pendentes: $e');
    }
  }

  /// Define comanda selecionada
  void setSelectedComanda(ComandaListItemDto? comanda) {
    if (_selectedComanda?.id != comanda?.id) {
      _selectedComanda = comanda;
      notifyListeners();
    }
  }

  /// Seleciona comanda por ID
  void selecionarComandaPorId(String comandaId) {
    try {
      final comanda = _comandas.firstWhere(
        (c) => c.id == comandaId,
      );
      setSelectedComanda(comanda);
    } catch (e) {
      debugPrint('⚠️ Comanda $comandaId não encontrada na lista: $e');
    }
  }

  /// Filtra comandas
  void filterComandas(String query) {
    final queryLower = query.toLowerCase().trim();
    if (queryLower.isEmpty) {
      _filteredComandas = _comandas;
    } else {
      _filteredComandas = _comandas.where((comanda) {
        final numero = comanda.numero.toLowerCase().trim();
        final codigoBarras = (comanda.codigoBarras ?? '').toLowerCase();
        final descricao = (comanda.descricao ?? '').toLowerCase();
        final status = comanda.status.toLowerCase();
        
        return numero.contains(queryLower) || 
               codigoBarras.contains(queryLower) ||
               descricao.contains(queryLower) || 
               status.contains(queryLower);
      }).toList();
    }
    notifyListeners();
  }

  /// Carrega comandas do servidor
  Future<void> loadComandas({bool refresh = false}) async {
    if (refresh) {
      debugPrint('🔄 Refresh completo: resetando estado e recarregando comandas...');
      _currentPage = 1;
      _comandas = [];
      _hasMore = true;
      _errorMessage = null;
      _statusCalculadoPorComanda.clear(); // Limpa cache de status
      notifyListeners();
    }

    if (!_hasMore && !refresh) return;

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('📡 Buscando comandas do backend (page: $_currentPage, refresh: $refresh)...');
      final response = await comandaService.searchComandas(
        page: _currentPage,
        pageSize: _pageSize,
        filter: ComandaFilterDto(ativa: true), // Apenas comandas ativas
      );

      if (response.success && response.data != null) {
        final newComandas = response.data!.list;

        debugPrint('=== Comandas recebidas do backend ===');
        for (var comanda in newComandas.take(10)) {
          debugPrint('Comanda - ID: ${comanda.id}, Número: ${comanda.numero}, Status: ${comanda.status}');
        }
        debugPrint('Total de comandas: ${newComandas.length}');

        if (refresh) {
          _comandas = newComandas;
          debugPrint('🔄 Comandas atualizadas no estado (refresh: true)');
        } else {
          _comandas.addAll(newComandas);
        }
        _hasMore = response.data!.pagination.hasNext;
        _currentPage++;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();

        // Recalcula status de todas as comandas após carregar
        _recalcularStatusTodasComandas();
        
        filterComandas(''); // Reaplica filtro
        
        // Se não há comanda selecionada, tenta selecionar automaticamente
        if (_selectedComanda == null) {
          _selecionarComandaComPedidosPendentes();
        }
      } else {
        _errorMessage = response.message.isNotEmpty
            ? response.message
            : 'Erro ao carregar comandas';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      // Detecta erros de conexão e cria mensagem amigável
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
        _errorMessage = 'Erro ao carregar comandas: ${e.toString()}';
      }
      _isLoading = false;
      notifyListeners();
      debugPrint('Erro ao carregar comandas: $e');
      if (e is Error) {
        debugPrint('Stack trace: ${e.stackTrace}');
      }
    }
  }

  @override
  void dispose() {
    for (final subscription in _eventBusSubscriptions) {
      subscription.cancel();
    }
    _eventBusSubscriptions.clear();
    _debounceTimer?.cancel();
    super.dispose();
  }
}

