import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/modules/restaurante/mesa_list_item.dart';
import '../../data/models/modules/restaurante/mesa_filter.dart';
import '../../data/services/modules/restaurante/mesa_service.dart';
import '../../data/repositories/pedido_local_repository.dart';
import '../../data/models/local/pedido_local.dart';
import '../../data/models/local/sync_status_pedido.dart';
import '../../presentation/providers/services_provider.dart';
import '../../core/events/app_event_bus.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Status calculado de uma mesa (fonte única de verdade)
/// Agrega informações de todos os pedidos da mesa
class MesaStatusCalculado {
  final String mesaId;
  final String statusVisual; // 'livre', 'ocupada', etc.
  
  // Contadores por status
  final int pedidosPendentes;
  final int pedidosSincronizando;
  final int pedidosComErro;
  final int pedidosSincronizados;
  
  final DateTime? ultimaAtualizacao;
  final bool temPedidosRecemSincronizados;

  MesaStatusCalculado({
    required this.mesaId,
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
  
  /// Retorna se mesa tem pedidos que precisam atenção
  bool get temPedidosPendentesOuErro => pedidosPendentes > 0 || pedidosComErro > 0;
  
  /// Retorna se mesa está sincronizando
  bool get estaSincronizando => pedidosSincronizando > 0;
}

/// Provider centralizado para gerenciar estado de mesas
/// ÚNICA FONTE DE VERDADE para status de mesas
class MesasProvider extends ChangeNotifier {
  final MesaService mesaService;
  final PedidoLocalRepository pedidoRepo;
  final ServicesProvider servicesProvider;

  MesasProvider({
    required this.mesaService,
    required this.pedidoRepo,
    required this.servicesProvider,
  });

  // Estado de mesas do servidor
  List<MesaListItemDto> _mesas = [];
  List<MesaListItemDto> _filteredMesas = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  final int _pageSize = 1000;
  bool _hasMore = true;
  MesaListItemDto? _selectedMesa;

  // Estado calculado de cada mesa (fonte única de verdade)
  final Map<String, MesaStatusCalculado> _statusCalculadoPorMesa = {};
  
  // Listeners
  List<StreamSubscription<AppEvent>> _eventBusSubscriptions = [];
  Timer? _debounceTimer;
  final Set<String> _mesasPendentesAtualizacao = {};
  bool _isInitialized = false;

  // Getters
  List<MesaListItemDto> get mesas => _mesas;
  List<MesaListItemDto> get filteredMesas => _filteredMesas;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  MesaListItemDto? get selectedMesa => _selectedMesa;
  bool get hasMore => _hasMore;

  /// Obtém o status calculado de uma mesa (sempre atualizado)
  MesaStatusCalculado? getStatusCalculado(String mesaId) {
    return _statusCalculadoPorMesa[mesaId];
  }

  /// Obtém o status visual de uma mesa (usa status calculado se disponível)
  String getStatusVisualMesa(MesaListItemDto mesa) {
    final statusCalculado = _statusCalculadoPorMesa[mesa.id];
    if (statusCalculado != null) {
      return statusCalculado.statusVisual;
    }
    // Fallback: calcula na hora se não estiver em cache
    return _calcularStatusVisual(mesa.id);
  }

  /// Obtém número de pedidos pendentes de uma mesa
  int getPedidosPendentesCount(String mesaId) {
    return _statusCalculadoPorMesa[mesaId]?.pedidosPendentes ?? 0;
  }

  /// Inicializa o provider e configura todos os listeners
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ MesasProvider já está inicializado');
      return;
    }

    debugPrint('🚀 Inicializando MesasProvider...');
    
    try {
      // 1. Garante que a box está aberta
      await pedidoRepo.getAll();
      
      // 2. Configura listener de eventos de negócio (Event Bus)
      // AutoSyncManager é o único que escuta Hive e dispara eventos aqui
      _setupEventBusListener();
      
      // 3. Carrega mesas iniciais
      await loadMesas();
      
      // 4. Calcula status inicial de todas as mesas
      _recalcularStatusTodasMesas();
      
      _isInitialized = true;
      debugPrint('✅ MesasProvider inicializado com sucesso');
    } catch (e) {
      debugPrint('❌ Erro ao inicializar MesasProvider: $e');
      _errorMessage = 'Erro ao inicializar: ${e.toString()}';
      notifyListeners();
    }
  }


  /// Configura listener de eventos de negócio (Event Bus)
  /// Escuta TODOS os eventos relacionados a pedidos e mesas
  /// AutoSyncManager é o único responsável por escutar Hive e disparar eventos aqui
  void _setupEventBusListener() {
    final eventBus = AppEventBus.instance;
    
    // Escuta eventos de pedido criado
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoCriado).listen((evento) {
        if (evento.mesaId != null) {
          debugPrint('📢 [MesasProvider] Evento: Pedido ${evento.pedidoId} criado na mesa ${evento.mesaId}');
          _recalcularStatusMesa(evento.mesaId!);
        }
      }),
    );
    
    // Escuta eventos de pedido sincronizando
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoSincronizando).listen((evento) {
        if (evento.mesaId != null) {
          debugPrint('📢 [MesasProvider] Evento: Pedido ${evento.pedidoId} sincronizando na mesa ${evento.mesaId}');
          _recalcularStatusMesa(evento.mesaId!);
        }
      }),
    );
    
    // Escuta eventos de pedido sincronizado
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoSincronizado).listen((evento) {
        if (evento.mesaId != null) {
          debugPrint('📢 [MesasProvider] Evento: Pedido ${evento.pedidoId} sincronizado na mesa ${evento.mesaId}');
          
          // Recalcula status (pode não encontrar pedidos se foi enviado direto)
          _recalcularStatusMesa(evento.mesaId!);
          
          // Se não encontrou pedidos locais, o pedido foi enviado direto via API
          // Busca dados atualizados do servidor imediatamente para aquela mesa específica
          final statusCalculado = _statusCalculadoPorMesa[evento.mesaId!];
          if (statusCalculado == null || statusCalculado.totalPedidosLocais == 0) {
            debugPrint('🔄 [MesasProvider] Pedido enviado direto detectado, buscando dados do servidor para mesa ${evento.mesaId}');
            // Busca apenas aquela mesa específica do servidor e atualiza na lista
            _atualizarMesasDoServidor([evento.mesaId!]);
          } else {
            // Tem pedidos locais, agenda atualização normal (com debounce)
          _agendarAtualizacaoServidor(evento.mesaId!);
          }
        }
      }),
    );
    
    // Escuta eventos de pedido com erro
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoErro).listen((evento) {
        if (evento.mesaId != null) {
          debugPrint('📢 [MesasProvider] Evento: Pedido ${evento.pedidoId} com erro na mesa ${evento.mesaId}');
          _recalcularStatusMesa(evento.mesaId!);
        }
      }),
    );
    
    // Escuta eventos de pedido removido
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.pedidoRemovido).listen((evento) {
        if (evento.mesaId != null) {
          debugPrint('📢 [MesasProvider] Evento: Pedido ${evento.pedidoId} removido da mesa ${evento.mesaId}');
          _recalcularStatusMesa(evento.mesaId!);
        }
      }),
    );
    
    // Escuta eventos de mesa liberada
    // O MesaDetalhesProvider é responsável por toda a lógica de finalização e liberação
    // Este provider apenas atualiza o status visual para "livre" quando recebe o evento
    debugPrint('🔧 [MesasProvider] Configurando listener para evento mesaLiberada');
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.mesaLiberada).listen((evento) {
        debugPrint('🔔 [MesasProvider] Evento mesaLiberada recebido: mesaId=${evento.mesaId}');
        debugPrint('   Tipo evento: ${evento.tipo}');
        debugPrint('   Dados: ${evento.dados}');
        debugPrint('   Total mesas na lista: ${_mesas.length}');
        
        if (evento.mesaId != null) {
          debugPrint('📢 [MesasProvider] Processando liberação da mesa ${evento.mesaId}');
          
          // Atualiza status calculado para livre
          _statusCalculadoPorMesa[evento.mesaId!] = MesaStatusCalculado(
            mesaId: evento.mesaId!,
            statusVisual: 'livre',
            pedidosPendentes: 0,
            pedidosSincronizando: 0,
            pedidosComErro: 0,
            pedidosSincronizados: 0,
            ultimaAtualizacao: DateTime.now(),
            temPedidosRecemSincronizados: false,
          );
          debugPrint('✅ [MesasProvider] Status calculado atualizado para livre');
          
          // Atualiza também o objeto MesaListItemDto na lista _mesas
          final mesaIndex = _mesas.indexWhere((m) => m.id == evento.mesaId);
          debugPrint('   Índice da mesa na lista: $mesaIndex');
          
          if (mesaIndex != -1) {
            final mesaAntiga = _mesas[mesaIndex];
            debugPrint('   Mesa encontrada: ${mesaAntiga.numero}, status atual: ${mesaAntiga.status}');
            
            // Cria nova instância com status atualizado para "Livre"
            final mesaAtualizada = MesaListItemDto(
              id: mesaAntiga.id,
              numero: mesaAntiga.numero,
              descricao: mesaAntiga.descricao,
              status: 'Livre', // Atualiza status para Livre
              ativa: mesaAntiga.ativa,
              permiteReserva: mesaAntiga.permiteReserva,
              layoutNome: mesaAntiga.layoutNome,
              pedidoId: null, // Remove pedidoId quando mesa é liberada
              vendaAtualId: null, // Remove vendaAtualId quando mesa é liberada
              vendaAtual: null, // Remove vendaAtual quando mesa é liberada
            );
            _mesas[mesaIndex] = mesaAtualizada;
            debugPrint('✅ [MesasProvider] Mesa ${evento.mesaId} atualizada na lista _mesas');
            debugPrint('   Status antes: ${mesaAntiga.status}');
            debugPrint('   Status depois: Livre');
            
            // Atualiza também na lista filtrada se existir
            final filteredIndex = _filteredMesas.indexWhere((m) => m.id == evento.mesaId);
            if (filteredIndex != -1) {
              _filteredMesas[filteredIndex] = mesaAtualizada;
              debugPrint('✅ [MesasProvider] Mesa ${evento.mesaId} atualizada na lista _filteredMesas');
            } else {
              debugPrint('ℹ️ [MesasProvider] Mesa ${evento.mesaId} não encontrada na lista filtrada (pode não estar visível)');
            }
          } else {
            debugPrint('⚠️ [MesasProvider] Mesa ${evento.mesaId} não encontrada na lista _mesas');
            debugPrint('   IDs das mesas na lista: ${_mesas.map((m) => m.id).toList()}');
          }
          
          debugPrint('✅ [MesasProvider] Status da mesa ${evento.mesaId} atualizado para livre');
          
          notifyListeners();
          debugPrint('✅ [MesasProvider] notifyListeners() chamado - UI deve atualizar');
        } else {
          debugPrint('⚠️ [MesasProvider] Evento mesaLiberada recebido sem mesaId');
          debugPrint('   Dados do evento: ${evento.dados}');
        }
      }),
    );
    debugPrint('✅ [MesasProvider] Listener de mesaLiberada configurado');
    
    // Escuta eventos de status mudou
    // Não vai no servidor se a mesa está livre (venda foi finalizada)
    // porque o status já foi atualizado localmente
    _eventBusSubscriptions.add(
      eventBus.on(TipoEvento.statusMesaMudou).listen((evento) {
        if (evento.mesaId != null) {
          debugPrint('📢 [MesasProvider] Evento: Status da mesa ${evento.mesaId} mudou');
          // Verifica se a mesa está livre (sem pedidos locais)
          // Se estiver livre, não precisa ir no servidor porque já atualizamos localmente
          if (!Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
            debugPrint('ℹ️ [MesasProvider] Hive não está aberto, ignorando atualização');
            return;
          }
          
          final box = Hive.box<PedidoLocal>(PedidoLocalRepository.boxName);
          final pedidosLocais = box.values.where((p) => p.mesaId == evento.mesaId).toList();
          final temPedidosLocais = pedidosLocais.any((p) => 
            p.syncStatus != SyncStatusPedido.sincronizado
          );
          
          // Se não tem pedidos locais pendentes, mesa está livre (venda finalizada)
          // Não precisa ir no servidor
          if (!temPedidosLocais) {
            debugPrint('ℹ️ [MesasProvider] Mesa ${evento.mesaId} está livre (sem pedidos locais), não precisa ir no servidor');
            // Apenas recalcula status localmente
            _recalcularStatusMesa(evento.mesaId!);
            return;
          }
          
          // Tem pedidos locais, pode precisar atualizar do servidor
          _atualizarMesasDoServidor([evento.mesaId!]);
        }
      }),
    );
    
    debugPrint('✅ Listener do Event Bus configurado (escuta apenas eventos de negócio)');
  }

  /// Agenda atualização do servidor para uma mesa específica (com debounce)
  void _agendarAtualizacaoServidor(String mesaId) {
    _mesasPendentesAtualizacao.add(mesaId);
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 2000), () {
      final mesasParaAtualizar = _mesasPendentesAtualizacao.toList();
      _mesasPendentesAtualizacao.clear();
      
      if (mesasParaAtualizar.isEmpty) return;
      
      // Verifica se ainda há pedidos locais antes de atualizar do servidor
      // Só atualiza do servidor se não houver pedidos pendentes/sincronizando/erro
      bool podeAtualizar = true;
      for (final id in mesasParaAtualizar) {
        final status = _statusCalculadoPorMesa[id];
        if (status != null && status.totalPedidosLocais > 0) {
          podeAtualizar = false;
          debugPrint('⏳ Mesa $id ainda tem ${status.totalPedidosLocais} pedido(s) local(is), não atualizando do servidor');
          break;
        }
      }
      
      if (podeAtualizar) {
        debugPrint('🔄 Atualizando ${mesasParaAtualizar.length} mesa(s) do servidor...');
        _atualizarMesasDoServidor(mesasParaAtualizar);
      } else {
        // Tenta novamente após mais delay
        Future.delayed(const Duration(milliseconds: 2000), () {
          _agendarAtualizacaoServidor(mesaId);
        });
      }
    });
  }

  /// Recalcula status de uma mesa específica
  /// Lê todos os pedidos da mesa do Hive e calcula status baseado em regras de prioridade
  void _recalcularStatusMesa(String mesaId) {
    if (!Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
      debugPrint('⚠️ Box não está aberta, não é possível recalcular status');
      return;
    }

    final box = Hive.box<PedidoLocal>(PedidoLocalRepository.boxName);
    final pedidos = box.values.where((p) => p.mesaId == mesaId).toList();
    
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
    // Prioridade: pendente > sincronizando > erro > servidor
    String statusVisual;
    if (pedidosPendentes > 0) {
      // Tem pedidos pendentes → Mesa ocupada (pendente)
      statusVisual = 'ocupada';
    } else if (pedidosSincronizando > 0) {
      // Tem pedidos sincronizando → Mesa ocupada (sincronizando)
      statusVisual = 'ocupada';
    } else if (pedidosComErro > 0) {
      // Tem pedidos com erro → Mesa ocupada (com erro)
      statusVisual = 'ocupada';
    } else if (pedidosRecemSincronizados) {
      // Tem pedidos recém-sincronizados → Mantém ocupada temporariamente
      statusVisual = 'ocupada';
    } else {
      // Não tem pedidos locais pendentes/sincronizando/erro
      // Busca status do servidor
      final mesaIndex = _mesas.indexWhere((m) => m.id == mesaId);
      if (mesaIndex != -1) {
        statusVisual = _mesas[mesaIndex].status.toLowerCase();
      } else {
        // Mesa não encontrada na lista, mantém status anterior ou usa 'livre'
        final statusAnterior = _statusCalculadoPorMesa[mesaId];
        statusVisual = statusAnterior?.statusVisual ?? 'livre';
      }
    }
    
    // Atualiza status calculado com todos os contadores
    _statusCalculadoPorMesa[mesaId] = MesaStatusCalculado(
      mesaId: mesaId,
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
    
    debugPrint('✅ Status recalculado para mesa $mesaId: $statusVisual');
    debugPrint('   📊 Contadores: pendentes=$pedidosPendentes, sincronizando=$pedidosSincronizando, erros=$pedidosComErro, sincronizados=$pedidosSincronizados');
  }

  /// Recalcula status de todas as mesas
  void _recalcularStatusTodasMesas() {
    debugPrint('🔄 Recalculando status de ${_mesas.length} mesas...');
    for (final mesa in _mesas) {
      _recalcularStatusMesa(mesa.id);
    }
    debugPrint('✅ Status de todas as mesas recalculado');
  }

  /// Calcula status visual sem cache (fallback)
  String _calcularStatusVisual(String mesaId) {
    if (!Hive.isBoxOpen(PedidoLocalRepository.boxName)) {
      final mesaIndex = _mesas.indexWhere((m) => m.id == mesaId);
      if (mesaIndex != -1) {
        return _mesas[mesaIndex].status.toLowerCase();
      }
      return 'livre';
    }

    final box = Hive.box<PedidoLocal>(PedidoLocalRepository.boxName);
    final temPedidosPendentes = box.values.any((p) =>
      p.mesaId == mesaId &&
      (p.syncStatus == SyncStatusPedido.pendente || 
       p.syncStatus == SyncStatusPedido.sincronizando)
    );
    
    if (temPedidosPendentes) {
      return 'ocupada';
    }
    
    final mesaIndex = _mesas.indexWhere((m) => m.id == mesaId);
    if (mesaIndex != -1) {
      return _mesas[mesaIndex].status.toLowerCase();
    }
    return 'livre';
  }

  /// Atualiza mesas específicas do servidor
  Future<void> _atualizarMesasDoServidor(List<String> mesaIds) async {
    final Map<String, MesaListItemDto> mesasAtualizadas = {};
    
    // Busca todas em paralelo
    final futures = mesaIds.map((mesaId) async {
      try {
        debugPrint('📡 Buscando dados atualizados da mesa $mesaId do servidor...');
        final response = await mesaService.getMesaById(mesaId);
        if (response.success && response.data != null) {
          mesasAtualizadas[mesaId] = response.data!;
          debugPrint('✅ Mesa $mesaId atualizada: ${response.data!.numero} - Status: ${response.data!.status}');
        } else {
          debugPrint('⚠️ Erro ao buscar mesa $mesaId: ${response.message}');
        }
      } catch (e) {
        debugPrint('❌ Erro ao atualizar mesa $mesaId: $e');
      }
    });
    
    await Future.wait(futures);
    
    // Atualiza na lista
    bool houveAtualizacao = false;
    for (final entry in mesasAtualizadas.entries) {
      final index = _mesas.indexWhere((m) => m.id == entry.key);
      if (index != -1) {
        _mesas[index] = entry.value;
        houveAtualizacao = true;
        
        // Recalcula status completo após atualizar dados do servidor
        // Isso garante que o status seja calculado corretamente com dados atualizados
        _recalcularStatusMesa(entry.key);
      }
    }
    
    if (houveAtualizacao) {
      // Reaplica filtro e notifica listeners para atualizar UI
      filterMesas(''); 
      debugPrint('✅ [MesasProvider] Mesa(s) atualizada(s) do servidor e UI notificada');
    }
  }

  /// Define mesa selecionada
  void setSelectedMesa(MesaListItemDto? mesa) {
    if (_selectedMesa?.id != mesa?.id) {
      _selectedMesa = mesa;
      notifyListeners();
    }
  }

  /// Filtra mesas
  void filterMesas(String query) {
    final queryLower = query.toLowerCase().trim();
    if (queryLower.isEmpty) {
      _filteredMesas = _mesas;
    } else {
      _filteredMesas = _mesas.where((mesa) {
        final numero = mesa.numero.toLowerCase().trim();
        final descricao = (mesa.descricao ?? '').toLowerCase();
        final status = mesa.status.toLowerCase();
        
        if (numero.contains(queryLower) || numero == queryLower) {
          return true;
        }
        return descricao.contains(queryLower) || status.contains(queryLower);
      }).toList();
    }
    notifyListeners();
  }

  /// Carrega mesas do servidor
  Future<void> loadMesas({bool refresh = false}) async {
    if (refresh) {
      debugPrint('🔄 Refresh completo: resetando estado e recarregando mesas...');
      _currentPage = 1;
      _mesas = [];
      _hasMore = true;
      _errorMessage = null;
      _statusCalculadoPorMesa.clear(); // Limpa cache de status
      notifyListeners();
    }

    if (!_hasMore && !refresh) return;

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('📡 Buscando mesas do backend (page: $_currentPage, refresh: $refresh)...');
      final response = await mesaService.searchMesas(
        page: _currentPage,
        pageSize: _pageSize,
        filter: MesaFilterDto(ativa: true),
      );

      if (response.success && response.data != null) {
        final newMesas = response.data!.list;

        debugPrint('=== Mesas recebidas do backend ===');
        for (var mesa in newMesas.take(10)) {
          debugPrint('Mesa - ID: ${mesa.id}, Número: ${mesa.numero}, Status: ${mesa.status}');
        }
        debugPrint('Total de mesas: ${newMesas.length}');

        if (refresh) {
          _mesas = newMesas;
          debugPrint('🔄 Mesas atualizadas no estado (refresh: true)');
        } else {
          _mesas.addAll(newMesas);
        }
        _hasMore = response.data!.pagination.hasNext;
        _currentPage++;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();

        // Recalcula status de todas as mesas após carregar
        _recalcularStatusTodasMesas();
        
        filterMesas(''); // Reaplica filtro
      } else {
        _errorMessage = response.message ?? 'Erro ao carregar mesas';
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
        _errorMessage = 'Erro ao carregar mesas: ${e.toString()}';
      }
      _isLoading = false;
      notifyListeners();
      debugPrint('Erro ao carregar mesas: $e');
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
