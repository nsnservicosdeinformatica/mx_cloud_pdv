import '../../../../core/payment/payment_provider.dart';
import 'package:flutter/foundation.dart';
import 'providers/cash_payment_adapter.dart';
import '../../../../core/payment/payment_config.dart';
import '../../../../core/config/flavor_config.dart';

// Importa os loaders - no flavor mobile, as dependências nativas serão excluídas pelo Gradle
// O código Dart será compilado, mas as classes nativas não estarão disponíveis
import 'providers/stone_pos_adapter_loader.dart' as stone_loader;

/// Cria o adapter Stone POS apenas quando o flavor for stoneP2
/// No flavor mobile, lança exceção sem tentar criar
PaymentProvider _createStonePosAdapter(Map<String, dynamic>? settings) {
  // Só cria se for flavor stoneP2
  if (!FlavorConfig.isStoneP2) {
    throw Exception('Stone POS Adapter não disponível no flavor mobile');
  }
  
  // Usa o loader para criar o adapter
  // No flavor mobile, isso nunca será chamado devido à verificação acima
  final loader = stone_loader.createStonePosAdapterLoader();
  return loader(settings);
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
    
    final provider = factory(settings);
    _instances[key] = provider;
    return provider;
  }
  
  /// Registra todos os providers disponíveis baseado na configuração
  static Future<void> registerAll(PaymentConfig config) async {
    // Dinheiro sempre disponível
    registerProvider('cash', (_) => CashPaymentAdapter());
    
    if (config.canUseProvider('stone_pos')) {
      // Só registra se o flavor for stoneP2
      // No flavor mobile, o adapter não será criado, evitando importar o SDK Stone
      if (FlavorConfig.isStoneP2) {
        try {
          // Importação condicional - só cria o adapter quando necessário
          registerProvider('stone_pos', (settings) {
            return _createStonePosAdapter(settings);
          });
        } catch (e) {
          debugPrint('⚠️ Stone POS Adapter não disponível no flavor atual: $e');
        }
      } else {
        debugPrint('ℹ️ Stone POS Adapter não registrado (flavor mobile não suporta)');
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
