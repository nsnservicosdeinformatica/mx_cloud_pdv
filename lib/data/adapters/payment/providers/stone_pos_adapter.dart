import '../../../../core/payment/payment_provider.dart';
import '../../../../core/payment/payment_ui_notifier.dart'; // 🆕 Import do sistema de notificação
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';

// Importação do SDK Stone
// NOTA: Em ouros flavor, este pacote NÃO estará disponível
// O código Dart será incluído no APK, mas as dependências nativas serão excluídas
// via build.gradle.kts, removendo as classes nativas que os adquirentes detectam
import 'package:stone_payments/stone_payments.dart';
import 'package:stone_payments/enums/type_transaction_enum.dart';
import 'mappers/stone_transaction_mapper.dart';

/// Provider de pagamento Stone POS (usa SDK Stone)
class StonePOSAdapter implements PaymentProvider {
  final Map<String, dynamic>? _settings;
  bool _initialized = false;
  bool _activated = false;
  StreamSubscription<String>? _messageSubscription;
  String? _lastMessage;
  
  StonePOSAdapter({Map<String, dynamic>? settings}) : _settings = settings;
  
  @override
  String get providerName => 'Stone';
  
  @override
  PaymentType get paymentType => PaymentType.pos;
  
  @override
  bool get isAvailable {
    // SDK Stone está disponível se o package foi instalado
    try {
      return true;
    } catch (e) {
      debugPrint('⚠️ Stone SDK não disponível: $e');
      return false;
    }
  }
  
  /// Stone POS requer interação do usuário (inserir/passar cartão)
  /// 
  /// **Por que true?**
  /// - Usuário precisa inserir ou aproximar cartão na máquina
  /// - SDK aguarda interação do usuário durante processamento
  /// - UI deve mostrar dialog "Aguardando cartão" durante esse tempo
  @override
  bool get requiresUserInteraction => true;
  
  @override
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      debugPrint('🔌 Inicializando Stone Payments SDK...');
      
      // Ativa a máquina Stone (deve ser feito uma vez no app)
      if (!_activated) {
        await _activateStone();
        _activated = true;
      }
      
      // Configura listener de mensagens (criado uma vez e mantido durante toda a vida do adapter)
      if (_messageSubscription == null) {
        _messageSubscription = StonePayments.onMessageListener((mensagem) {
          _lastMessage = mensagem;
          debugPrint('📢 [Stone SDK] Mensagem: $mensagem');
        });
        debugPrint('📢 Listener de mensagens Stone configurado');
      }
      
      _initialized = true;
      debugPrint('✅ Stone Payments SDK inicializado');
    } catch (e) {
      debugPrint('❌ Erro ao inicializar Stone Payments SDK: $e');
      rethrow;
    }
  }
  
  /// Ativa a máquina Stone (chamado uma vez no início do app)
  Future<void> _activateStone() async {
    try {
      final appName = _settings?['appName'] as String? ?? 'MX Cloud PDV';
      final stoneCode = _settings?['stoneCode'] as String? ?? '';
      
      if (stoneCode.isEmpty) {
        throw Exception('StoneCode não configurado');
      }
      
      debugPrint('🔌 Ativando Stone com StoneCode: $stoneCode');
      
      await StonePayments.activateStone(
        appName: appName,
        stoneCode: stoneCode,
        qrCodeProviderId: _settings?['qrCodeProviderId'] as String?,
        qrCodeAuthorization: _settings?['qrCodeAuthorization'] as String?,
      );
      
      debugPrint('✅ Stone ativada com sucesso');
    } catch (e) {
      debugPrint('❌ Erro ao ativar Stone: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> disconnect() async {
    if (!_initialized) return;
    
    try {
      _messageSubscription?.cancel();
      _messageSubscription = null;
      _initialized = false;
      debugPrint('🔌 Stone POS SDK desconectado');
    } catch (e) {
      debugPrint('⚠️ Erro ao desconectar Stone POS SDK: $e');
    }
  }
  
  @override
  Future<PaymentResult> processPayment({
    required double amount,
    required String vendaId,
    Map<String, dynamic>? additionalData,
    PaymentUINotifier? uiNotifier, // 🆕 Novo parâmetro para notificar UI
  }) async {
    if (!_initialized) {
      await initialize();
    }
    
    try {
      debugPrint('💳 Processando pagamento Stone SDK: R\$ ${amount.toStringAsFixed(2)}');
      
      // Verifica se o dispositivo está pronto
      if (!_activated) {
        debugPrint('⚠️ Stone não está ativada, tentando reativar...');
        await _activateStone();
        _activated = true;
      }
      
      // Determina tipo de transação
      final tipoTransacao = additionalData?['tipoTransacao'] as String? ?? 'credit';
      TypeTransactionEnum transactionType;
      switch (tipoTransacao.toLowerCase()) {
        case 'debit':
        case 'debito':
          transactionType = TypeTransactionEnum.debit;
          break;
        case 'pix':
          transactionType = TypeTransactionEnum.pix;
          break;
        default:
          transactionType = TypeTransactionEnum.credit;
      }
      
      debugPrint('💳 Tipo de transação: $transactionType');
      debugPrint('💳 Valor: R\$ ${amount.toStringAsFixed(2)}');
      debugPrint('💳 Parcelas: ${additionalData?['parcelas'] as int? ?? 1}');
      
      // Tenta abortar qualquer transação pendente antes de iniciar uma nova
      try {
        await abortPayment();
        debugPrint('🛑 Transações pendentes abortadas');
        // Aguarda um pouco para o terminal processar o abortamento
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        // Ignora erro se não houver transação pendente
        debugPrint('ℹ️ Nenhuma transação pendente para abortar: $e');
      }
      
      // Resume o listener se estiver pausado (seguindo padrão do exemplo Stone)
      if (_messageSubscription != null && _messageSubscription!.isPaused) {
        _messageSubscription!.resume();
        debugPrint('📢 Listener de mensagens retomado');
      }
      
      // Limpa última mensagem antes de iniciar nova transação
      _lastMessage = null;
      
      // 🆕 NOTIFICA UI: Mostrar dialog "Aguardando cartão"
      // Isso avisa a UI que o SDK está aguardando o usuário inserir/passar o cartão
      uiNotifier?.notify(PaymentUINotification.showWaitingCard(
        message: 'Aguardando cartão na máquina...\nMantenha o cartão próximo ao terminal.',
      ));
      debugPrint('📢 UI notificada: Mostrar dialog aguardando cartão');
      
      // Processa transação usando SDK Stone
      // Nota: Para pagamento por aproximação (NFC), o SDK automaticamente detecta
      // quando o cartão é aproximado. O usuário deve manter o cartão próximo ao terminal.
      // ⚠️ IMPORTANTE: Esta chamada BLOQUEIA até o cartão ser processado
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('💳 INICIANDO TRANSAÇÃO STONE');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('💰 Valor: R\$ ${amount.toStringAsFixed(2)}');
      debugPrint('📝 Tipo de transação: $transactionType');
      debugPrint('📦 Parcelas: ${additionalData?['parcelas'] as int? ?? 1}');
      debugPrint('🖨️ Imprimir recibo: ${additionalData?['imprimirRecibo'] as bool? ?? false}');
      debugPrint('📱 Aguardando aproximação do cartão...');
      debugPrint('💡 Mantenha o cartão próximo ao terminal até o processamento concluir');
      debugPrint('═══════════════════════════════════════════════════════════');
      
      final transaction = await StonePayments.transaction(
        value: amount,
        typeTransaction: transactionType,
        installment: additionalData?['parcelas'] as int? ?? 1,
        printReceipt: additionalData?['imprimirRecibo'] as bool? ?? false,
        onPixQrCode: (String qrCodeBase64) {
          // Callback para QR Code PIX (se necessário)
          debugPrint('📱 QR Code PIX recebido: ${qrCodeBase64.length} caracteres');
        },
      );
      
      // 🆕 NOTIFICA UI: Esconder dialog "Aguardando cartão"
      // Transação foi processada (sucesso ou falha), não precisa mais do dialog
      uiNotifier?.notify(PaymentUINotification.hideWaitingCard());
      debugPrint('📢 UI notificada: Esconder dialog aguardando cartão');
      
      if (transaction == null) {
        debugPrint('❌ Transação retornou null');
        debugPrint('📢 Última mensagem do SDK: $_lastMessage');
        // Pausa listener em caso de erro (seguindo padrão do exemplo)
        _messageSubscription?.pause();
        return PaymentResult(
          success: false,
          errorMessage: 'Não foi possível processar o pagamento. '
              'Mantenha o cartão próximo ao terminal até o processamento concluir.',
          metadata: {
            'lastMessage': _lastMessage,
          },
        );
      }
      
      // Log completo do retorno da Stone
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📋 RETORNO COMPLETO DA STONE - TRANSACTION OBJECT');
      debugPrint('═══════════════════════════════════════════════════════════');
      
      // Tenta usar toJson() se disponível (como no exemplo)
      try {
        final json = transaction.toJson();
        debugPrint('📄 JSON completo da transação:');
        debugPrint(json.toString());
      } catch (e) {
        debugPrint('⚠️ Não foi possível converter para JSON: $e');
        debugPrint('📄 Logando propriedades individuais:');
      }
      
      // Log de todas as propriedades disponíveis
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔑 PROPRIEDADES DA TRANSAÇÃO:');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📊 transactionStatus: ${transaction.transactionStatus}');
      debugPrint('🔑 initiatorTransactionKey: ${transaction.initiatorTransactionKey}');
      debugPrint('🔑 transactionReference: ${transaction.transactionReference}');
      debugPrint('🔑 acquirerTransactionKey: ${transaction.acquirerTransactionKey}');
      debugPrint('✅ authorizationCode: ${transaction.authorizationCode}');
      debugPrint('💳 cardBrand: ${transaction.cardBrand}');
      debugPrint('💳 cardBrandName: ${transaction.cardBrandName}');
      debugPrint('👤 cardHolderName: ${transaction.cardHolderName}');
      debugPrint('💳 cardHolderNumber: ${transaction.cardHolderNumber}');
      debugPrint('📅 date: ${transaction.date}');
      debugPrint('⏰ time: ${transaction.time}');
      debugPrint('💰 amount: ${transaction.amount}');
      debugPrint('📝 typeOfTransactionEnum: ${transaction.typeOfTransactionEnum}');
      debugPrint('⚠️ actionCode: ${transaction.actionCode}');
      
      // Tenta acessar outras propriedades que podem existir
      try {
        // Verifica se há outras propriedades usando reflection ou métodos adicionais
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('🔍 PROPRIEDADES ADICIONAIS (se disponíveis):');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        
        // Tenta acessar propriedades comuns que podem existir
        final transactionStr = transaction.toString();
        debugPrint('📝 toString(): $transactionStr');
        
      } catch (e) {
        debugPrint('⚠️ Erro ao acessar propriedades adicionais: $e');
      }
      
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📊 Status da transação: ${transaction.transactionStatus}');
      debugPrint('═══════════════════════════════════════════════════════════');
      
      // Verifica status da transação (seguindo padrão do exemplo: apenas APPROVED)
      if (transaction.transactionStatus == "APPROVED") {
        debugPrint('✅ Pagamento Stone aprovado');
        
        // Converte dados da Stone para formato padrão
        final transactionData = StoneTransactionMapper.fromStoneTransaction(transaction);
        
        return PaymentResult(
          success: true,
          transactionId: transaction.initiatorTransactionKey ?? 
                         transaction.transactionReference ?? 
                         'STONE-${DateTime.now().millisecondsSinceEpoch}',
          transactionData: transactionData,
          metadata: {
            'provider': 'stone_pos',
            // Mantém metadata para compatibilidade, mas transactionData é a fonte principal
            'acquirerTransactionKey': transaction.acquirerTransactionKey,
            'authorizationCode': transaction.authorizationCode,
            'cardBrand': transaction.cardBrand,
            'cardBrandName': transaction.cardBrandName,
            'cardHolderName': transaction.cardHolderName,
            'cardHolderNumber': transaction.cardHolderNumber,
            'date': transaction.date,
            'time': transaction.time,
            'amount': transaction.amount,
            'transactionStatus': transaction.transactionStatus,
            'typeOfTransactionEnum': transaction.typeOfTransactionEnum,
          },
        );
      } else {
        debugPrint('═══════════════════════════════════════════════════════════');
        debugPrint('❌ TRANSAÇÃO NÃO APROVADA - LOG COMPLETO');
        debugPrint('═══════════════════════════════════════════════════════════');
        
        // Tenta usar toJson() se disponível
        try {
          final json = transaction.toJson();
          debugPrint('📄 JSON completo da transação (não aprovada):');
          debugPrint(json.toString());
        } catch (e) {
          debugPrint('⚠️ Não foi possível converter para JSON: $e');
        }
        
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('🔑 PROPRIEDADES DA TRANSAÇÃO (NÃO APROVADA):');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('📊 transactionStatus: ${transaction.transactionStatus}');
        debugPrint('⚠️ actionCode: ${transaction.actionCode}');
        debugPrint('🔑 initiatorTransactionKey: ${transaction.initiatorTransactionKey}');
        debugPrint('🔑 transactionReference: ${transaction.transactionReference}');
        debugPrint('🔑 acquirerTransactionKey: ${transaction.acquirerTransactionKey}');
        debugPrint('✅ authorizationCode: ${transaction.authorizationCode}');
        debugPrint('💳 cardBrand: ${transaction.cardBrand}');
        debugPrint('💳 cardBrandName: ${transaction.cardBrandName}');
        debugPrint('👤 cardHolderName: ${transaction.cardHolderName}');
        debugPrint('💳 cardHolderNumber: ${transaction.cardHolderNumber}');
        debugPrint('📅 date: ${transaction.date}');
        debugPrint('⏰ time: ${transaction.time}');
        debugPrint('💰 amount: ${transaction.amount}');
        debugPrint('📝 typeOfTransactionEnum: ${transaction.typeOfTransactionEnum}');
        debugPrint('═══════════════════════════════════════════════════════════');
        
        // Converte dados da Stone para formato padrão (mesmo em caso de erro)
        final transactionData = StoneTransactionMapper.fromStoneTransaction(transaction);
        
        return PaymentResult(
          success: false,
          errorMessage: 'Transação não aprovada: ${transaction.transactionStatus}',
          transactionData: transactionData,
          metadata: {
            'transactionStatus': transaction.transactionStatus,
            'actionCode': transaction.actionCode,
            'initiatorTransactionKey': transaction.initiatorTransactionKey,
            'acquirerTransactionKey': transaction.acquirerTransactionKey,
            'authorizationCode': transaction.authorizationCode,
            'cardBrand': transaction.cardBrand,
            'cardBrandName': transaction.cardBrandName,
            'cardHolderName': transaction.cardHolderName,
            'cardHolderNumber': transaction.cardHolderNumber,
            'date': transaction.date,
            'time': transaction.time,
            'amount': transaction.amount,
            'typeOfTransactionEnum': transaction.typeOfTransactionEnum?.toString(),
          },
        );
      }
    } catch (e) {
      // 🆕 NOTIFICA UI: Esconder dialog "Aguardando cartão" em caso de erro
      // Importante: sempre esconder o dialog, mesmo em caso de erro
      uiNotifier?.notify(PaymentUINotification.hideWaitingCard());
      debugPrint('📢 UI notificada: Esconder dialog aguardando cartão (erro)');
      
      // Pausa listener em caso de erro (seguindo padrão do exemplo Stone)
      _messageSubscription?.pause();
      
      debugPrint('❌ Erro ao processar pagamento Stone: $e');
      debugPrint('❌ Tipo do erro: ${e.runtimeType}');
      if (_lastMessage != null) {
        debugPrint('📢 Última mensagem do SDK antes do erro: $_lastMessage');
      }
      
      // Trata PlatformException especificamente para obter mais detalhes
      String errorMessage = 'Erro ao processar pagamento';
      String? errorCode;
      String? errorDetails;
      
      if (e is PlatformException) {
        errorCode = e.code;
        errorDetails = e.message;
        final detailsStr = e.details?.toString() ?? '';
        
        debugPrint('❌ PlatformException - Code: $errorCode');
        debugPrint('❌ PlatformException - Message: $errorDetails');
        debugPrint('❌ PlatformException - Details: $detailsStr');
        
        // Combina todas as informações disponíveis para análise
        final allErrorInfo = [
          errorCode ?? '',
          errorDetails ?? '',
          detailsStr,
        ].where((s) => s.isNotEmpty).join(' ').toUpperCase();
        
        debugPrint('❌ Todas as informações do erro: $allErrorInfo');
        
        // Mensagens de erro mais amigáveis baseadas no código e detalhes
        switch (errorCode) {
          case 'Error':
            // Erro genérico do SDK Stone - tenta obter mais informações dos detalhes
            // Verifica todas as fontes de informação
            if (allErrorInfo.contains('CANCELLED') || allErrorInfo.contains('CANCEL')) {
              errorMessage = 'Pagamento cancelado pelo usuário';
            } else if (allErrorInfo.contains('TIMEOUT') || allErrorInfo.contains('TIME_OUT')) {
              errorMessage = 'Tempo de leitura do cartão esgotado. Aproxime o cartão novamente.';
            } else if (allErrorInfo.contains('NFC') || allErrorInfo.contains('NOT_ENABLED')) {
              errorMessage = 'NFC não habilitado ou não disponível. Verifique as configurações do dispositivo.';
            } else if (allErrorInfo.contains('CARD') || allErrorInfo.contains('READ_ERROR')) {
              errorMessage = 'Erro ao ler o cartão. Verifique se o cartão está próximo ao terminal.';
            } else if (allErrorInfo.contains('DEVICE') || allErrorInfo.contains('NOT_READY')) {
              errorMessage = 'Terminal não está pronto. Aguarde alguns instantes e tente novamente.';
            } else if (allErrorInfo.contains('NETWORK') || allErrorInfo.contains('CONNECTION')) {
              errorMessage = 'Erro de conexão. Verifique a conexão do terminal e tente novamente.';
            } else {
              // Erro genérico sem detalhes específicos
              // Como a luz do terminal acendeu e o cartão foi aproximado, significa que:
              // - O terminal está funcionando
              // - O cartão foi detectado
              // - Mas houve um problema durante o processamento/autorização
              
              // Verifica se há mensagem do SDK que indica que o cartão foi aproximado
              final cartaoAproximado = _lastMessage != null && 
                  (_lastMessage!.toLowerCase().contains('cartão') || 
                   _lastMessage!.toLowerCase().contains('card') ||
                   _lastMessage!.toLowerCase().contains('aproximado') ||
                   _lastMessage!.toLowerCase().contains('detectado'));
              
              if (cartaoAproximado) {
                errorMessage = 'Cartão detectado, mas houve problema durante o processamento.\n\n'
                    'Possíveis causas:\n'
                    '• Cartão sem saldo/sem limite\n'
                    '• Problema de comunicação com a operadora\n'
                    '• Cartão bloqueado ou inválido\n'
                    '• Terminal sem conexão\n\n'
                    'Verifique o cartão e tente novamente.';
              } else {
                errorMessage = 'Erro ao processar pagamento por aproximação.\n\n'
                    'O terminal iniciou a leitura, mas houve um problema durante o processamento.\n\n'
                    'Tente novamente:\n'
                    '• Mantenha o cartão próximo ao terminal por mais tempo\n'
                    '• Não remova o cartão até o processamento concluir\n'
                    '• Verifique se o cartão está funcionando\n'
                    '• Aguarde alguns segundos antes de tentar novamente';
              }
            }
            break;
          case 'CANCELLED':
          case 'USER_CANCELLED':
            errorMessage = 'Pagamento cancelado pelo usuário';
            break;
          case 'TIMEOUT':
            errorMessage = 'Tempo de leitura do cartão esgotado. Aproxime o cartão novamente.';
            break;
          case 'NFC_NOT_AVAILABLE':
          case 'NFC_DISABLED':
            errorMessage = 'NFC não habilitado ou não disponível. Verifique as configurações do dispositivo.';
            break;
          case 'DEVICE_NOT_READY':
            errorMessage = 'Terminal não está pronto. Aguarde alguns instantes e tente novamente.';
            break;
          default:
            errorMessage = errorDetails ?? errorCode ?? 'Erro ao processar pagamento';
        }
      } else {
        // Para outros tipos de erro, usa a mensagem padrão
        final errorStr = e.toString();
        if (errorStr.contains('cancel') || errorStr.contains('CANCEL')) {
          errorMessage = 'Pagamento cancelado';
        } else if (errorStr.contains('timeout') || errorStr.contains('TIMEOUT')) {
          errorMessage = 'Tempo de leitura do cartão esgotado. Aproxime o cartão novamente.';
        } else {
          errorMessage = 'Erro ao processar pagamento: ${e.toString()}';
        }
      }
      
      return PaymentResult(
        success: false,
        errorMessage: errorMessage,
        metadata: {
          'errorCode': errorCode,
          'errorDetails': errorDetails,
          'errorType': e.runtimeType.toString(),
        },
      );
    }
  }
  
  /// Aborta uma transação em andamento
  Future<String?> abortPayment() async {
    try {
      final result = await StonePayments.abortPayment();
      debugPrint('🛑 Pagamento abortado: $result');
      return result;
    } catch (e) {
      debugPrint('❌ Erro ao abortar pagamento: $e');
      return null;
    }
  }
  
  /// Cancela uma transação aprovada
  Future<Map<String, dynamic>?> cancelPayment({
    required String initiatorTransactionKey,
    bool printReceipt = true,
  }) async {
    try {
      final result = await StonePayments.cancelPayment(
        initiatorTransactionKey: initiatorTransactionKey,
        printReceipt: printReceipt,
      );
      debugPrint('🔄 Pagamento cancelado: ${result?.transactionStatus}');
      // Converte Transaction para Map se necessário
      return result != null ? {
        'initiatorTransactionKey': result.initiatorTransactionKey,
        'transactionStatus': result.transactionStatus,
        'authorizationCode': result.authorizationCode,
      } : null;
    } catch (e) {
      debugPrint('❌ Erro ao cancelar pagamento: $e');
      return null;
    }
  }
  
  /// Verifica status da máquina POS
  Future<bool> checkStatus() async {
    if (!_initialized) return false;
    
    try {
      // Stone Payments não tem método direto de verificação
      // A verificação é feita tentando uma operação
      // Por enquanto retorna true se inicializado
      return _initialized && _activated;
    } catch (e) {
      return false;
    }
  }
  
}
