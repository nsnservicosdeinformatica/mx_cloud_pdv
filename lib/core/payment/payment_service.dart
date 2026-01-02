import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'payment_config.dart';
import 'payment_provider.dart';
import 'payment_method_option.dart';
import 'payment_ui_notifier.dart'; // 🆕 Import do sistema de notificação
import '../../data/adapters/payment/payment_provider_registry.dart';

/// Serviço principal de pagamento
class PaymentService {
  PaymentConfig? _config;
  static PaymentService? _instance;
  
  static Future<PaymentService> getInstance() async {
    _instance ??= PaymentService._();
    await _instance!._initialize();
    return _instance!;
  }
  
  PaymentService._();
  
  Future<void> _initialize() async {
    // Carrega configuração
    _config = await PaymentConfig.load();
    
    debugPrint('💳 Payment Service inicializado');
    debugPrint('📱 Providers disponíveis: ${_config!.availableProviders}');
    
    // Registra providers baseado na configuração
    await PaymentProviderRegistry.registerAll(_config!);
  }
  
  /// Retorna métodos de pagamento disponíveis para este dispositivo
  List<PaymentMethodOption> getAvailablePaymentMethods() {
    if (_config == null) {
      return [PaymentMethodOption.cash()];
    }
    
    final methods = <PaymentMethodOption>[];
    
    // Dinheiro sempre disponível
    if (_config!.canUseProvider('cash')) {
      methods.add(PaymentMethodOption.cash());
    }
    
    // Stone POS SDK - Crédito (se disponível)
    if (_config!.canUseProvider('stone_pos')) {
      methods.add(PaymentMethodOption(
        type: PaymentType.pos,
        label: 'Cartão Crédito',
        icon: Icons.credit_card,
        color: Colors.blue.shade700,
        providerKey: 'stone_pos',
      ));
      
      // Stone POS SDK - Débito (se disponível)
      methods.add(PaymentMethodOption(
        type: PaymentType.pos,
        label: 'Cartão Débito',
        icon: Icons.credit_card,
        color: Colors.blue.shade600,
        providerKey: 'stone_pos',
      ));
    }
    
    // Adicionar outros providers conforme necessário
    
    return methods;
  }
  
  /// Obtém um provider específico
  Future<PaymentProvider?> getProvider(String providerKey) async {
    final settings = _config?.providerSettings?[providerKey];
    final provider = PaymentProviderRegistry.getProvider(providerKey, settings: settings);
    
    if (provider != null && !provider.isAvailable) {
      debugPrint('⚠️ Provider $providerKey não está disponível');
      return null;
    }
    
    return provider;
  }
  
  /// Processa um pagamento
  /// 
  /// **Parâmetros:**
  /// - [providerKey] - Chave do provider (ex: 'stone_pos', 'cash')
  /// - [amount] - Valor a ser pago
  /// - [vendaId] - ID da venda
  /// - [additionalData] - Dados adicionais específicos do provider
  /// - [uiNotifier] - Notificador opcional para comunicar com UI
  /// 
  /// **Sobre uiNotifier:**
  /// - Se fornecido, será passado para o provider
  /// - PaymentService pode também usar para notificações gerais
  /// - Providers que requerem interação do usuário devem usar para
  ///   notificar UI sobre eventos (ex: mostrar/esconder dialogs)
  /// 
  /// **Fluxo:**
  /// 1. Obtém provider do registry
  /// 2. Inicializa provider
  /// 3. Se provider requer interação, pode notificar UI antecipadamente
  /// 4. Chama provider.processPayment() passando uiNotifier
  /// 5. Retorna resultado
  Future<PaymentResult> processPayment({
    required String providerKey,
    required double amount,
    required String vendaId,
    Map<String, dynamic>? additionalData,
    PaymentUINotifier? uiNotifier, // 🆕 Novo parâmetro opcional
  }) async {
    debugPrint('💳 [PaymentService] Iniciando processamento de pagamento');
    debugPrint('💳 Provider: $providerKey, Valor: R\$ ${amount.toStringAsFixed(2)}');
    
    // 1. Obtém provider do registry
    final provider = await getProvider(providerKey);
    
    if (provider == null) {
      debugPrint('❌ [PaymentService] Provider $providerKey não disponível');
      return PaymentResult(
        success: false,
        errorMessage: 'Provider $providerKey não disponível',
      );
    }
    
    debugPrint('✅ [PaymentService] Provider obtido: ${provider.providerName}');
    debugPrint('📋 [PaymentService] Provider requer interação: ${provider.requiresUserInteraction}');
    
    // 2. Inicializa provider se necessário
    try {
      debugPrint('🔧 [PaymentService] Inicializando provider...');
      await provider.initialize();
      debugPrint('✅ [PaymentService] Provider inicializado');
    } catch (e) {
      debugPrint('❌ [PaymentService] Erro ao inicializar provider: $e');
      return PaymentResult(
        success: false,
        errorMessage: 'Erro ao inicializar provider: ${e.toString()}',
      );
    }
    
    // 3. Se provider requer interação do usuário, pode notificar UI antecipadamente
    // (opcional - alguns providers preferem notificar internamente)
    // Aqui apenas logamos, mas o provider é quem decide quando notificar
    if (provider.requiresUserInteraction) {
      debugPrint('👤 [PaymentService] Provider requer interação do usuário');
      debugPrint('👤 [PaymentService] Provider será responsável por notificar UI');
    }
    
    // 4. Processa pagamento passando uiNotifier para o provider
    // O provider decide quando e como notificar UI
    debugPrint('💳 [PaymentService] Chamando provider.processPayment()...');
    try {
      final result = await provider.processPayment(
        amount: amount,
        vendaId: vendaId,
        additionalData: additionalData,
        uiNotifier: uiNotifier, // 🆕 Passa notificador para provider
      );
      
      if (result.success) {
        debugPrint('✅ [PaymentService] Pagamento processado com sucesso');
      } else {
        debugPrint('❌ [PaymentService] Pagamento falhou: ${result.errorMessage}');
      }
      
      return result;
      
    } catch (e, stackTrace) {
      debugPrint('❌ [PaymentService] Exceção ao processar pagamento: $e');
      debugPrint('❌ [PaymentService] Stack trace: $stackTrace');
      
      // Em caso de exceção, garante que dialog seja escondido (se estava mostrando)
      if (provider.requiresUserInteraction) {
        uiNotifier?.notify(PaymentUINotification.hideWaitingCard());
        debugPrint('📢 [PaymentService] UI notificada: Esconder dialog (exceção)');
      }
      
      return PaymentResult(
        success: false,
        errorMessage: 'Erro ao processar pagamento: ${e.toString()}',
      );
    }
  }
  
}

