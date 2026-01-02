import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Detecta o flavor atual do build
class FlavorConfig {
  static String? _cachedFlavor;
  static PackageInfo? _packageInfo;
  
  /// Inicializa o PackageInfo (deve ser chamado no início do app)
  static Future<void> initialize() async {
    if (_packageInfo == null) {
      _packageInfo = await PackageInfo.fromPlatform();
    }
  }
  
  /// Retorna o flavor atual (mobile, stoneP2, etc.)
  /// ATENÇÃO: Este método pode retornar 'mobile' como padrão se não conseguir detectar
  /// Use detectFlavorAsync() para detecção mais confiável
  static String get currentFlavor {
    if (_cachedFlavor != null) return _cachedFlavor!;
    
    // Tenta ler do ambiente de build (--dart-define=FLAVOR=stoneP2)
    const flavorEnv = String.fromEnvironment('FLAVOR');
    if (flavorEnv.isNotEmpty) {
      _cachedFlavor = flavorEnv;
      return _cachedFlavor!;
    }
    
    // Tenta detectar pelo applicationId se já foi inicializado
    if (_packageInfo != null) {
      final flavor = _detectFlavorFromApplicationId(_packageInfo!.packageName);
      if (flavor != null) {
        _cachedFlavor = flavor;
        return _cachedFlavor!;
      }
    }
    
    // Fallback: mobile (será atualizado quando detectFlavorAsync() for chamado)
    _cachedFlavor = 'mobile';
    return _cachedFlavor!;
  }
  
  /// Detecta flavor pelo applicationId
  static String? _detectFlavorFromApplicationId(String applicationId) {
    if (applicationId.contains('.stone.p2')) {
      return 'stoneP2';
    } else if (applicationId.contains('.mobile')) {
      return 'mobile';
    }
    return null;
  }
  
  /// Carrega flavor de forma assíncrona (mais confiável)
  static Future<String> detectFlavorAsync() async {
    if (_cachedFlavor != null) return _cachedFlavor!;
    
    // 1. Tenta ler do ambiente de build (--dart-define=FLAVOR=stoneP2)
    const flavorEnv = String.fromEnvironment('FLAVOR');
    if (flavorEnv.isNotEmpty) {
      _cachedFlavor = flavorEnv;
      debugPrint('✅ Flavor detectado via --dart-define: $flavorEnv');
      return _cachedFlavor!;
    }
    
    // 2. Detecta pelo applicationId (mais confiável)
    await initialize();
    if (_packageInfo != null) {
      final flavor = _detectFlavorFromApplicationId(_packageInfo!.packageName);
      if (flavor != null) {
        _cachedFlavor = flavor;
        debugPrint('✅ Flavor detectado via applicationId (${_packageInfo!.packageName}): $flavor');
        return _cachedFlavor!;
      }
    }
    
    // 3. Fallback: tenta detectar pelo arquivo de config disponível
    // Prioriza stoneP2 primeiro (máquinas POS são mais específicas)
    final flavors = ['stoneP2', 'mobile'];
    
    for (final flavor in flavors) {
      try {
        await rootBundle.loadString('assets/config/payment_$flavor.json');
        _cachedFlavor = flavor;
        debugPrint('✅ Flavor detectado via assets: $flavor');
        return _cachedFlavor!;
      } catch (e) {
        continue;
      }
    }
    
    // Fallback final: mobile
    _cachedFlavor = 'mobile';
    debugPrint('⚠️ Flavor não detectado, usando padrão: mobile');
    return _cachedFlavor!;
  }
  
  /// Verifica se é um flavor específico
  static bool isFlavor(String flavor) {
    return currentFlavor.toLowerCase() == flavor.toLowerCase();
  }
  
  /// Verifica se é mobile
  static bool get isMobile => isFlavor('mobile');
  
  /// Verifica se é Stone P2
  static bool get isStoneP2 => isFlavor('stoneP2') || isFlavor('stonep2');
}

