import 'package:flutter/foundation.dart';
import 'print_config.dart';
import 'print_data.dart';
import 'nfce_print_data.dart';
import 'print_provider.dart';
import '../../data/adapters/printing/print_provider_registry.dart';

/// Serviço principal de impressão
class PrintService {
  PrintConfig? _config;
  static PrintService? _instance;
  
  static Future<PrintService> getInstance() async {
    _instance ??= PrintService._();
    await _instance!._initialize();
    return _instance!;
  }
  
  PrintService._();
  
  Future<void> _initialize() async {
    // Carrega configuração
    _config = await PrintConfig.load();
    
    debugPrint('🖨️ Print Service inicializado');
    debugPrint('📱 Providers disponíveis: ${_config!.supportedProviders}');
    
    // Registra providers baseado na configuração
    await PrintProviderRegistry.registerAll(_config!);
  }
  
  /// Obtém um provider específico
  Future<PrintProvider?> getProvider(String providerKey) async {
    final settings = _config?.providerSettings?[providerKey];
    final provider = PrintProviderRegistry.getProvider(providerKey, settings: settings);
    
    if (provider != null && !provider.isAvailable) {
      debugPrint('⚠️ Provider $providerKey não está disponível');
      return null;
    }
    
    return provider;
  }
  
  /// Imprime um documento
  Future<PrintResult> printDocument({
    required DocumentType documentType,
    required PrintData data,
    String? providerKey,
    OutputStrategy? outputStrategy,
  }) async {
    // Determina provider e estratégia de saída
    final docConfig = _config?.getConfigFor(documentType);
    if (docConfig == null) {
      return PrintResult(
        success: false,
        errorMessage: 'Configuração não encontrada para $documentType',
      );
    }
    
    final finalProviderKey = providerKey ?? docConfig.providerKey ?? _config?.defaultProvider;
    if (finalProviderKey == null) {
      return PrintResult(
        success: false,
        errorMessage: 'Provider não especificado',
      );
    }
    
    final finalOutputStrategy = outputStrategy ?? docConfig.defaultOutput;
    
    // Obtém provider
    final provider = await getProvider(finalProviderKey);
    if (provider == null) {
      return PrintResult(
        success: false,
        errorMessage: 'Provider $finalProviderKey não disponível',
      );
    }
    
    // Inicializa se necessário
    try {
      await provider.initialize();
    } catch (e) {
      return PrintResult(
        success: false,
        errorMessage: 'Erro ao inicializar provider: ${e.toString()}',
      );
    }
    
    // Processa impressão baseado no tipo de documento
    switch (documentType) {
      case DocumentType.comandaConferencia:
      case DocumentType.parcialVenda:
        return await provider.printComanda(data);
      case DocumentType.orcamento:
      case DocumentType.cupomFiscal:
      case DocumentType.recibo:
        // TODO: Implementar outros tipos de documento
        return PrintResult(
          success: false,
          errorMessage: 'Tipo de documento $documentType ainda não implementado',
        );
      case DocumentType.nfce:
        // NFC-e requer NfcePrintData, não PrintData
        return PrintResult(
          success: false,
          errorMessage: 'Use printNfce() diretamente com NfcePrintData',
        );
    }
  }
  
  /// Verifica se um tipo de documento pode ser impresso
  bool canPrint(DocumentType documentType) {
    final docConfig = _config?.getConfigFor(documentType);
    return docConfig != null && docConfig.availableOutputs.isNotEmpty;
  }
  
  /// Retorna estratégias de saída disponíveis para um tipo de documento
  List<OutputStrategy> getAvailableOutputs(DocumentType documentType) {
    final docConfig = _config?.getConfigFor(documentType);
    return docConfig?.availableOutputs ?? [];
  }
  
  /// Imprime uma NFC-e
  Future<PrintResult> printNfce({
    required NfcePrintData data,
    String? providerKey,
    OutputStrategy? outputStrategy,
  }) async {
    // Determina provider e estratégia de saída
    final docConfig = _config?.getConfigFor(DocumentType.nfce);
    if (docConfig == null) {
      return PrintResult(
        success: false,
        errorMessage: 'Configuração não encontrada para NFC-e',
      );
    }
    
    final finalProviderKey = providerKey ?? docConfig.providerKey ?? _config?.defaultProvider;
    if (finalProviderKey == null) {
      return PrintResult(
        success: false,
        errorMessage: 'Provider não especificado',
      );
    }
    
    // Obtém provider
    final provider = await getProvider(finalProviderKey);
    if (provider == null) {
      return PrintResult(
        success: false,
        errorMessage: 'Provider $finalProviderKey não disponível',
      );
    }
    
    // Inicializa se necessário
    try {
      await provider.initialize();
    } catch (e) {
      return PrintResult(
        success: false,
        errorMessage: 'Erro ao inicializar provider: ${e.toString()}',
      );
    }
    
    // Chama método printNfce do provider
    return await provider.printNfce(data);
  }
}

