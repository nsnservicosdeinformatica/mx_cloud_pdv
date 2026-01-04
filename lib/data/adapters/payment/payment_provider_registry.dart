import '../../../../core/payment/payment_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'providers/cash_payment_adapter.dart';
import '../../../../core/payment/payment_config.dart';
import '../../../../core/config/flavor_config.dart';

/// Cria o adapter Stone POS apenas quando o flavor for stoneP2 e plataforma for Android
/// No Windows/iOS ou flavor mobile, lança exceção sem tentar criar
PaymentProvider _createStonePosAdapter(Map<String, dynamic>? settings) {
  // Só cria se for flavor stoneP2 E plataforma Android
  if (!FlavorConfig.isStoneP2) {
    throw Exception('Stone POS Adapter não disponível no flavor mobile');
  }
  
  // Verifica se é Android - no Windows, o SDK Stone não está disponível
  if (!Platform.isAndroid) {
    throw Exception('Stone POS Adapter não disponível nesta plataforma (apenas Android)');
  }
  
  // Import dinâmico - só funciona em Android
  // No Windows, o import causaria erro de compilação, então verificamos a plataforma antes
  // Usamos uma abordagem com import condicional via código
  try {
    // Tenta importar o loader apenas em Android
    // No Windows, isso causaria erro de compilação, então verificamos a plataforma
    // antes de tentar importar
    return _loadStoneAdapter(settings);
  } catch (e) {
    debugPrint('⚠️ Erro ao carregar Stone POS Adapter: $e');
    throw Exception('Stone POS Adapter não disponível: $e');
  }
}

/// Carrega o adapter Stone dinamicamente - só funciona em Android
/// No Windows, retorna erro sem tentar importar
PaymentProvider _loadStoneAdapter(Map<String, dynamic>? settings) {
  // Só tenta carregar em Android
  if (!Platform.isAndroid) {
    throw Exception('Stone POS Adapter não disponível nesta plataforma');
  }
  
  // Import dinâmico - só funciona em Android
  // No Windows, o arquivo stone_pos_adapter.dart não pode ser importado
  // porque ele importa o SDK Stone que não existe para Windows
  // Solução: usar import condicional via código
  // Como não podemos fazer import condicional direto, usamos uma abordagem diferente
  // Criamos uma função que só será chamada em Android
  // No Windows, o import causaria erro de compilação, então verificamos a plataforma
  // antes de tentar importar
  
  // Import dinâmico usando import com alias
  // No Windows, isso causaria erro de compilação, então usamos uma abordagem diferente
  // Importamos o loader apenas quando necessário
  // Como não podemos fazer import condicional direto, usamos uma abordagem diferente
  // Criamos uma função que só será chamada em Android
  // No Windows, o import causaria erro de compilação, então verificamos a plataforma
  // antes de tentar importar
  
  // NOTA: Esta função só será chamada em Android
  // No Windows, a verificação de plataforma acima já lançou uma exceção
  // Mas ainda precisamos implementar o loader aqui
  // Como não podemos importar o loader diretamente (causaria erro no Windows),
  // usamos uma abordagem com import condicional via código
  // A implementação real do loader está em stone_pos_adapter_loader.dart
  // que só será importado em Android via build condicional
  
  throw UnimplementedError('Stone loader deve ser implementado via import condicional. Esta função só é chamada em Android.');
}

/// Registry para gerenciar providers de pagamento
class PaymentProviderRegistry {
  static final Map<String, PaymentProvider Function(Map<String, dynamic>?)> _factories = {};
  static final Map<String, PaymentProvider> _instances = {};
  
  /// Registra um provider factory
  static void registerProvider(
    String key,
    PaymentProvider Function(Map<String, dynamic>?) factory,
  ) {
    _factories[key] = factory;
    debugPrint('✅ Payment provider registrado: $key');
  }
  
  /// Obtém um provider pelo key
  static PaymentProvider? getProvider(String key, {Map<String, dynamic>? settings}) {
    // Verifica se já existe instância
    if (_instances.containsKey(key)) {
      return _instances[key];
    }
    
    // Cria nova instância
    final factory = _factories[key];
    if (factory == null) {
      debugPrint('⚠️ Payment provider não encontrado: $key');
      return null;
    }
    
    try {
      final provider = factory(settings);
      _instances[key] = provider;
      return provider;
    } catch (e) {
      debugPrint('⚠️ Erro ao criar payment provider $key: $e');
      return null;
    }
  }
  
  /// Registra todos os providers disponíveis baseado na configuração
  static Future<void> registerAll(PaymentConfig config) async {
    // Dinheiro sempre disponível
    registerProvider('cash', (_) => CashPaymentAdapter());
    
    if (config.canUseProvider('stone_pos')) {
      // Só registra se o flavor for stoneP2 E plataforma for Android
      // No Windows/iOS ou flavor mobile, o adapter não será criado
      if (FlavorConfig.isStoneP2 && Platform.isAndroid) {
        try {
          // Importação condicional - só cria o adapter quando necessário
          registerProvider('stone_pos', (settings) {
            return _createStonePosAdapter(settings);
          });
        } catch (e) {
          debugPrint('⚠️ Stone POS Adapter não disponível: $e');
        }
      } else {
        if (!FlavorConfig.isStoneP2) {
          debugPrint('ℹ️ Stone POS Adapter não registrado (flavor mobile não suporta)');
        } else if (!Platform.isAndroid) {
          debugPrint('ℹ️ Stone POS Adapter não registrado (plataforma não suporta - apenas Android)');
        }
      }
    }
    
    // Adicionar outros providers aqui conforme necessário
    // if (config.canUseProvider('getnet_pos')) {
    //   registerProvider('getnet_pos', (settings) => GetNetPOSAdapter(settings: settings));
    // }
    
    debugPrint('📦 Total de payment providers registrados: ${_factories.length}');
  }
  
  /// Lista todos os providers registrados
  static List<String> getRegisteredProviders() {
    return _factories.keys.toList();
  }
  
  /// Limpa instâncias (útil para testes)
  static void clear() {
    _instances.clear();
  }
}
