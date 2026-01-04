import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/services/sync/sync_service.dart';
import '../../data/repositories/produto_local_repository.dart';
import '../../data/repositories/exibicao_produto_local_repository.dart';

class SyncProvider extends ChangeNotifier {
  final SyncService _syncService;
  final ProdutoLocalRepository _produtoRepo;
  final ExibicaoProdutoLocalRepository _exibicaoRepo;

  bool _isSyncing = false;
  SyncProgress? _currentProgress;
  SyncResult? _lastResult;
  DateTime? _ultimaSincronizacao;
  int _totalProdutos = 0;
  int _totalGrupos = 0;

  SyncProvider({
    required SyncService syncService,
    required ProdutoLocalRepository produtoRepo,
    required ExibicaoProdutoLocalRepository exibicaoRepo,
  })  : _syncService = syncService,
        _produtoRepo = produtoRepo,
        _exibicaoRepo = exibicaoRepo {
    _carregarEstado();
  }

  /// Inicia sincronização
  Future<void> sincronizar({bool forcar = false}) async {
    if (_isSyncing) return;

    _isSyncing = true;
    _currentProgress = null; // Limpa progresso anterior
    notifyListeners();

    try {
      final result = await _syncService.sincronizarCompleto(
        forcar: forcar,
        onProgress: (progress) {
          _currentProgress = progress;
          notifyListeners();
        },
      );

      _lastResult = result;

      if (result.sucesso) {
        // Atualiza a data da última sincronização apenas se foi bem-sucedida
        // A data já foi salva pelo SyncService, então buscamos do serviço
        _ultimaSincronizacao = await _syncService.obterUltimaSincronizacao() ?? DateTime.now();
        await _atualizarEstatisticas();
      } else {
        // Erro na sincronização - não atualiza a data
      }
    } catch (e) {
      _lastResult = SyncResult(
        sucesso: false,
        erro: e.toString(),
      );
    } finally {
      _isSyncing = false;
      _currentProgress = null;
      notifyListeners();
    }
  }

  /// Verifica se precisa sincronizar
  Future<bool> verificarSePrecisaSincronizar() async {
    return await _syncService.precisaSincronizar();
  }

  /// Atualiza estatísticas locais
  Future<void> _atualizarEstatisticas() async {
    _totalProdutos = _produtoRepo.contar();
    _totalGrupos = _exibicaoRepo.buscarCategoriasRaiz().length;
    notifyListeners();
  }

  /// Carrega estado inicial
  Future<void> _carregarEstado() async {
    _ultimaSincronizacao = await _obterUltimaSincronizacao();
    await _atualizarEstatisticas();
    notifyListeners();
  }

  /// Obtém última sincronização dos metadados
  Future<DateTime?> _obterUltimaSincronizacao() async {
    try {
      final box = await Hive.openBox('sincronizacao_metadados');
      // Prioriza a sincronização geral
      final geral = box.get('ultima_sincronizacao_geral') as String?;
      if (geral != null) {
        return DateTime.parse(geral);
      }
      // Fallback para produtos
      final produtos = box.get('ultima_sincronizacao_produtos') as String?;
      if (produtos != null) {
        return DateTime.parse(produtos);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Getters
  bool get isSyncing => _isSyncing;
  SyncProgress? get currentProgress => _currentProgress;
  SyncResult? get lastResult => _lastResult;
  DateTime? get ultimaSincronizacao => _ultimaSincronizacao;
  int get totalProdutos => _totalProdutos;
  int get totalGrupos => _totalGrupos;
}

