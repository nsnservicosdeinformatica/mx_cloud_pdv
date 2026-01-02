import 'package:flutter/foundation.dart';
import '../../data/services/core/auth_service.dart';
import '../../data/services/modules/restaurante/mesa_service.dart';
import '../../data/services/modules/restaurante/comanda_service.dart';
import '../../data/services/modules/restaurante/configuracao_restaurante_service.dart';
import '../../data/models/modules/restaurante/configuracao_restaurante_dto.dart';
import '../../data/services/core/produto_service.dart';
import '../../data/services/core/pedido_service.dart';
import '../../data/services/core/exibicao_produto_service.dart';
import '../../data/services/core/venda_service.dart';
import '../../data/services/core/nota_fiscal_service.dart';
import '../../data/services/sync/sync_service.dart';
import '../../data/services/sync/auto_sync_manager.dart';
import '../../data/repositories/produto_local_repository.dart';
import '../../data/repositories/exibicao_produto_local_repository.dart';
import '../../data/repositories/pedido_local_repository.dart';
import '../../data/repositories/mesa_local_repository.dart';
import '../../data/repositories/comanda_local_repository.dart';
import '../../data/repositories/configuracao_restaurante_local_repository.dart';
import 'sync_provider.dart';

/// Provider para serviços compartilhados
/// Garante que todos os serviços usem o mesmo ApiClient do AuthService
class ServicesProvider extends ChangeNotifier {
  final AuthService _authService;
  late final MesaService _mesaService;
  late final ComandaService _comandaService;
  late final ConfiguracaoRestauranteService _configuracaoRestauranteService;
  late final ProdutoService _produtoService;
  late final PedidoService _pedidoService;
  late final ExibicaoProdutoService _exibicaoProdutoService;
  late final VendaService _vendaService;
  late final NotaFiscalService _notaFiscalService;

  /// Serviço de autenticação
  AuthService get authService => _authService;

  /// Serviço de mesas
  MesaService get mesaService => _mesaService;

  /// Serviço de comandas
  ComandaService get comandaService => _comandaService;

  /// Serviço de configuração do restaurante
  ConfiguracaoRestauranteService get configuracaoRestauranteService => _configuracaoRestauranteService;

  /// Serviço de produtos
  ProdutoService get produtoService => _produtoService;

  /// Serviço de pedidos
  PedidoService get pedidoService => _pedidoService;

  /// Serviço de exibição de produtos
  ExibicaoProdutoService get exibicaoProdutoService => _exibicaoProdutoService;
  
  /// Serviço de vendas
  VendaService get vendaService => _vendaService;
  
  /// Serviço de notas fiscais
  NotaFiscalService get notaFiscalService => _notaFiscalService;

  // Repositories locais
  late final ProdutoLocalRepository _produtoLocalRepo;
  late final ExibicaoProdutoLocalRepository _exibicaoLocalRepo;
  late final PedidoLocalRepository _pedidoLocalRepo;
  late final MesaLocalRepository _mesaLocalRepo;
  late final ComandaLocalRepository _comandaLocalRepo;
  late final ConfiguracaoRestauranteLocalRepository _configuracaoRestauranteLocalRepo;

  // Serviços de sincronização
  late final SyncService _syncService;
  late final SyncProvider _syncProvider;
  late final AutoSyncManager _autoSyncManager;

  // Cache de configuração do restaurante
  ConfiguracaoRestauranteDto? _configuracaoRestaurante;
  bool _configuracaoRestauranteCarregada = false;

  ServicesProvider(this._authService) {
    // Inicializar repositories locais primeiro
    _produtoLocalRepo = ProdutoLocalRepository();
    _exibicaoLocalRepo = ExibicaoProdutoLocalRepository();
    _pedidoLocalRepo = PedidoLocalRepository();
    _mesaLocalRepo = MesaLocalRepository();
    _comandaLocalRepo = ComandaLocalRepository();
    _configuracaoRestauranteLocalRepo = ConfiguracaoRestauranteLocalRepository();
    
    // Usa o mesmo ApiClient do AuthService para garantir que o token seja compartilhado
    // Passa repositórios locais para suporte offline
    _mesaService = MesaService(
      apiClient: _authService.apiClient,
      mesaLocalRepo: _mesaLocalRepo,
    );
    _comandaService = ComandaService(
      apiClient: _authService.apiClient,
      comandaLocalRepo: _comandaLocalRepo,
    );
    _configuracaoRestauranteService = ConfiguracaoRestauranteService(apiClient: _authService.apiClient);
    _produtoService = ProdutoService(apiClient: _authService.apiClient);
    _pedidoService = PedidoService(apiClient: _authService.apiClient);
    _exibicaoProdutoService = ExibicaoProdutoService(apiClient: _authService.apiClient);
    _vendaService = VendaService(apiClient: _authService.apiClient);
    _notaFiscalService = NotaFiscalService(_authService.apiClient);
    
    // Criar serviços de sincronização
    _syncService = SyncService(
      apiClient: _authService.apiClient,
      produtoRepo: _produtoLocalRepo,
      exibicaoRepo: _exibicaoLocalRepo,
      pedidoRepo: _pedidoLocalRepo,
      mesaRepo: _mesaLocalRepo,
      comandaRepo: _comandaLocalRepo,
      pedidoService: _pedidoService,
      configuracaoRestauranteService: _configuracaoRestauranteService,
    );
    
    // Criar provider de sincronização
    _syncProvider = SyncProvider(
      syncService: _syncService,
      produtoRepo: _produtoLocalRepo,
      exibicaoRepo: _exibicaoLocalRepo,
    );
    
    // Criar gerenciador de sincronização automática
    _autoSyncManager = AutoSyncManager(
      syncService: _syncService,
      pedidoRepo: _pedidoLocalRepo,
    );
    
    debugPrint('ServicesProvider criado com AuthService: ${_authService.hashCode}');
    debugPrint('ApiClient usado: ${_authService.apiClient.hashCode}');
  }

  /// Inicializa repositories (abre boxes do Hive)
  /// Deve ser chamado após a inicialização do Hive
  /// IMPORTANTE: Carrega configuração do restaurante na inicialização
  Future<void> initRepositories() async {
    await _produtoLocalRepo.init();
    await _exibicaoLocalRepo.init();
    await _mesaLocalRepo.init();
    await _comandaLocalRepo.init();
    await _configuracaoRestauranteLocalRepo.init();
    
    // Carrega configuração do restaurante na inicialização
    // Primeiro tenta carregar do local, depois busca do servidor e sobrescreve
    await _carregarConfiguracaoRestauranteNaInicializacao();
    
    // Inicializa sincronização automática após abrir repositories
    await _autoSyncManager.initialize();
  }

  /// Repository de produtos local
  ProdutoLocalRepository get produtoLocalRepo => _produtoLocalRepo;

  /// Repository de exibição local
  ExibicaoProdutoLocalRepository get exibicaoLocalRepo => _exibicaoLocalRepo;

  /// Repository de mesas local
  MesaLocalRepository get mesaLocalRepo => _mesaLocalRepo;

  /// Repository de comandas local
  ComandaLocalRepository get comandaLocalRepo => _comandaLocalRepo;

  /// Serviço de sincronização
  SyncService get syncService => _syncService;

  /// Provider de sincronização
  SyncProvider get syncProvider => _syncProvider;
  
  /// Gerenciador de sincronização automática
  AutoSyncManager get autoSyncManager => _autoSyncManager;

  // === CONFIGURAÇÃO DO RESTAURANTE ===

  /// Configuração do restaurante (cacheada em memória e persistida localmente)
  ConfiguracaoRestauranteDto? get configuracaoRestaurante => _configuracaoRestaurante;

  /// Indica se a configuração já foi carregada (mesmo que seja null)
  bool get configuracaoRestauranteCarregada => _configuracaoRestauranteCarregada;

  /// Carrega configuração na inicialização do sistema
  /// Primeiro carrega do local (se existir), depois busca do servidor e sobrescreve
  Future<void> _carregarConfiguracaoRestauranteNaInicializacao() async {
    debugPrint('📋 Inicializando configuração do restaurante...');
    
    // Primeiro tenta carregar do local (persistido)
    final configLocal = _configuracaoRestauranteLocalRepo.carregar();
    if (configLocal != null) {
      _configuracaoRestaurante = configLocal;
      _configuracaoRestauranteCarregada = true;
      debugPrint('✅ Configuração carregada do armazenamento local');
      notifyListeners();
    }
    
    // SEMPRE busca do servidor na inicialização e sobrescreve o que tiver local
    try {
      debugPrint('📋 Buscando configuração do servidor na inicialização...');
      final response = await _configuracaoRestauranteService.getConfiguracao();
      
      if (response.success && response.data != null) {
        _configuracaoRestaurante = response.data;
        _configuracaoRestauranteCarregada = true;
        
        // Salva localmente para uso futuro
        await _configuracaoRestauranteLocalRepo.salvar(response.data!);
        
        debugPrint('✅ Configuração carregada do servidor e salva localmente: TipoControleVenda=${_configuracaoRestaurante!.tipoControleVenda} (${_configuracaoRestaurante!.controlePorMesa ? "PorMesa" : "PorComanda"})');
        
        notifyListeners();
      } else {
        debugPrint('⚠️ Configuração não encontrada no servidor (null)');
        // Se não encontrou no servidor mas tinha local, mantém a local
        if (configLocal == null) {
          _configuracaoRestauranteCarregada = true;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao buscar configuração do servidor na inicialização: $e');
      // Se deu erro mas tinha local, mantém a local
      if (configLocal != null) {
        debugPrint('ℹ️ Mantendo configuração local devido ao erro');
      } else {
        _configuracaoRestauranteCarregada = true;
        notifyListeners();
      }
    }
  }

  /// Carrega a configuração do restaurante do servidor
  /// IMPORTANTE: Este método não deve ser usado durante execução normal
  /// Use apenas se necessário forçar atualização (ex: após mudança de empresa)
  /// Na inicialização, use _carregarConfiguracaoRestauranteNaInicializacao()
  Future<void> carregarConfiguracaoRestaurante({bool forceRefresh = false}) async {
    // Durante execução normal, usa sempre a configuração persistida localmente
    // Não busca do servidor a menos que forceRefresh = true
    if (!forceRefresh) {
      debugPrint('📋 Usando configuração persistida localmente (não busca do servidor)');
      
      // Se ainda não carregou do local, carrega agora
      if (!_configuracaoRestauranteCarregada) {
        final configLocal = _configuracaoRestauranteLocalRepo.carregar();
        if (configLocal != null) {
          _configuracaoRestaurante = configLocal;
          _configuracaoRestauranteCarregada = true;
          debugPrint('✅ Configuração carregada do armazenamento local');
          notifyListeners();
        } else {
          _configuracaoRestauranteCarregada = true;
          notifyListeners();
        }
      }
      return;
    }

    // Se forceRefresh = true, busca do servidor e atualiza local
    try {
      debugPrint('📋 Forçando atualização da configuração do servidor...');
      final response = await _configuracaoRestauranteService.getConfiguracao();
      
      if (response.success && response.data != null) {
        _configuracaoRestaurante = response.data;
        _configuracaoRestauranteCarregada = true;
        
        // Salva localmente
        await _configuracaoRestauranteLocalRepo.salvar(response.data!);
        
        debugPrint('✅ Configuração atualizada do servidor e salva localmente');
        notifyListeners();
      } else {
        debugPrint('⚠️ Configuração não encontrada no servidor');
      }
    } catch (e) {
      debugPrint('❌ Erro ao atualizar configuração do servidor: $e');
    }
  }

  /// Limpa o cache da configuração (útil quando muda de empresa ou faz logout)
  void limparConfiguracaoRestaurante() {
    _configuracaoRestaurante = null;
    _configuracaoRestauranteCarregada = false;
    // Limpa também do armazenamento local
    _configuracaoRestauranteLocalRepo.limpar();
    notifyListeners();
  }
}

