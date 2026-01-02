import 'package:flutter/foundation.dart';
import '../../core/payment/payment_service.dart';
import '../../core/payment/payment_provider.dart';
import '../../core/payment/payment_ui_notifier.dart';
import '../../core/payment/payment_transaction_data.dart'; // 🆕 Import do PaymentTransactionData
import '../../core/payment/payment_flow_state.dart'; // 🆕 Import dos estados
import '../../core/payment/payment_flow_state_machine.dart'; // 🆕 Import da State Machine
import '../../core/payment/nota_fiscal_status.dart'; // 🆕 Import do NotaFiscalStatus
import '../../core/printing/nfce_print_data.dart'; // 🆕 Import do NfcePrintData
import '../../core/printing/print_provider.dart'; // 🆕 Import do PrintResult
import '../../data/models/core/api_response.dart'; // 🆕 Import do ApiResponse
import '../../data/models/core/vendas/venda_dto.dart'; // 🆕 Import do VendaDto
import '../../data/services/core/venda_service.dart'; // 🆕 Import do VendaService

/// Provider para gerenciar estado do fluxo de pagamento
/// 
/// **Responsabilidades:**
/// 1. Gerencia estado para UI reagir (via ChangeNotifier)
/// 2. Recebe notificações de providers (via PaymentUINotifier)
/// 3. Expõe métodos simples para UI chamar
/// 4. Orquestra chamadas ao PaymentService
/// 
/// **Como funciona:**
/// - UI chama métodos do Provider (ex: processPayment)
/// - Provider chama PaymentService
/// - PaymentService chama Provider (StonePOSAdapter)
/// - Provider (StonePOSAdapter) notifica via uiNotifier
/// - PaymentFlowProvider recebe notificação e atualiza estado
/// - PaymentFlowProvider chama notifyListeners()
/// - UI (Consumer) detecta mudança e atualiza automaticamente
/// 
/// **Exemplo de uso na UI:**
/// ```dart
/// Consumer<PaymentFlowProvider>(
///   builder: (context, provider, child) {
///     if (provider.showWaitingCardDialog) {
///       return _buildWaitingCardDialog();
///     }
///     return PaymentForm();
///   },
/// )
/// ```
class PaymentFlowProvider extends ChangeNotifier implements PaymentUINotifier {
  final PaymentService _paymentService;
  
  // 🆕 State Machine para gerenciar estados
  final PaymentFlowStateMachine _stateMachine = PaymentFlowStateMachine();
  
  // ========== ESTADO INTERNO ==========
  
  /// Se deve mostrar dialog "Aguardando cartão"
  bool _showWaitingCardDialog = false;
  
  /// Mensagem do dialog "Aguardando cartão"
  String _waitingCardMessage = 'Aguardando cartão...';
  
  /// Mensagem de erro (se houver)
  String? _errorMessage;
  
  /// Último resultado de pagamento
  PaymentResult? _lastResult;
  
  /// 🆕 Dados da venda finalizada (para passar notaFiscalId para impressão)
  Map<String, dynamic>? _vendaFinalizadaData;
  
  /// 🆕 Venda atualizada após registro de pagamento (pode ser venda agrupada se múltiplas vendas)
  VendaDto? _vendaAtualizadaAposPagamento;
  
  /// 🆕 Status detalhado da nota fiscal
  NotaFiscalStatus? _notaFiscalStatus;
  
  /// 🆕 Número de tentativas de emissão de nota fiscal
  int _tentativasEmissao = 0;
  
  /// 🆕 Número máximo de tentativas de emissão
  static const int MAX_TENTATIVAS_EMISSAO = 3;
  
  /// 🆕 Intervalo entre tentativas (em segundos)
  static const int INTERVALO_TENTATIVAS_SEGUNDOS = 2;
  
  // ========== GETTERS (para UI consumir) ==========
  
  /// 🆕 Estado atual da State Machine
  PaymentFlowState get currentState => _stateMachine.currentState;
  
  /// 🆕 Se está processando (qualquer operação)
  bool get isProcessing => _stateMachine.isProcessing;
  
  /// 🆕 Se está em estado de sucesso
  bool get isSuccess => _stateMachine.isSuccess;
  
  /// 🆕 Se está em estado de erro
  bool get isError => _stateMachine.isError;
  
  /// 🆕 Se pode processar pagamento
  bool get canProcessPayment => _stateMachine.canProcessPayment();
  
  /// 🆕 Se pode concluir venda
  bool get canConcludeSale => _stateMachine.canConcludeSale();
  
  /// 🆕 Se pode fazer retry
  bool get canRetry => _stateMachine.canRetry();
  
  /// 🆕 Venda atualizada após registro de pagamento (exposta para UI)
  VendaDto? get vendaAtualizadaAposPagamento => _vendaAtualizadaAposPagamento;
  
  /// Se deve mostrar dialog "Aguardando cartão"
  bool get showWaitingCardDialog => _showWaitingCardDialog;
  
  /// Mensagem do dialog "Aguardando cartão"
  String get waitingCardMessage => _waitingCardMessage;
  
  /// Mensagem de erro (se houver)
  String? get errorMessage => _errorMessage;
  
  /// Último resultado de pagamento
  PaymentResult? get lastResult => _lastResult;
  
  /// 🆕 Dados da venda finalizada (para passar notaFiscalId para impressão)
  Map<String, dynamic>? get vendaFinalizadaData => _vendaFinalizadaData;
  
  /// 🆕 Status detalhado da nota fiscal
  NotaFiscalStatus? get notaFiscalStatus => _notaFiscalStatus;
  
  /// 🆕 Número de tentativas de emissão realizadas
  int get tentativasEmissao => _tentativasEmissao;
  
  /// 🆕 Descrição do estado atual (útil para debug/UI)
  String get stateDescription => currentState.description;
  
  /// 🆕 Mensagem amigável para o usuário baseada no estado atual
  String get userMessage {
    switch (currentState) {
      case PaymentFlowState.registeringPayment:
        return 'Registrando pagamento no servidor...';
      case PaymentFlowState.concludingSale:
        return 'Concluindo venda...';
      case PaymentFlowState.creatingInvoice:
        return 'Criando nota fiscal...';
      case PaymentFlowState.sendingToSefaz:
        return 'Enviando para SEFAZ...';
      case PaymentFlowState.printingInvoice:
        return 'Imprimindo nota fiscal...';
      case PaymentFlowState.completed:
        return 'Venda concluída com sucesso!';
      case PaymentFlowState.completionFailed:
        return 'Erro ao concluir venda';
      case PaymentFlowState.invoiceFailed:
        return 'Erro ao emitir nota fiscal';
      case PaymentFlowState.printFailed:
        return 'Erro ao imprimir nota fiscal';
      default:
        return '';
    }
  }
  
  // ========== CONSTRUTOR ==========
  
  PaymentFlowProvider(this._paymentService);
  
  // ========== MÉTODOS PÚBLICOS (para UI chamar) ==========
  
  /// Processa um pagamento
  /// 
  /// **Parâmetros:**
  /// - [providerKey] - Chave do provider (ex: 'stone_pos', 'cash')
  /// - [amount] - Valor a ser pago
  /// - [vendaId] - ID da venda
  /// - [additionalData] - Dados adicionais específicos do provider
  /// 
  /// **Retorna:**
  /// - `true` se pagamento foi processado com sucesso
  /// - `false` se houve erro (verificar errorMessage)
  /// 
  /// **Como funciona:**
  /// 1. Valida se pode processar (via State Machine)
  /// 2. Transiciona para processingPayment
  /// 3. Chama PaymentService.processPayment() passando this como uiNotifier
  /// 4. PaymentService repassa this para provider
  /// 5. Provider notifica via notify() quando necessário
  /// 6. Transiciona para paymentProcessed ou paymentFailed
  /// 7. Notifica UI sobre mudança de estado
  Future<bool> processPayment({
    required String providerKey,
    required double amount,
    required String vendaId,
    Map<String, dynamic>? additionalData,
  }) async {
    debugPrint('💳 [PaymentFlowProvider] ========== INICIANDO PAGAMENTO ==========');
    debugPrint('💳 Estado atual: ${currentState.description}');
    debugPrint('💳 canProcessPayment: $canProcessPayment');
    debugPrint('💳 Provider: $providerKey, Valor: R\$ ${amount.toStringAsFixed(2)}');
    debugPrint('💳 Histórico de estados: ${_stateMachine.stateHistory.map((s) => s.description).join(" → ")}');
    
    // 🆕 1. Valida se pode processar (via State Machine)
    if (!canProcessPayment) {
      debugPrint('❌ [PaymentFlowProvider] ========== ERRO: NÃO PODE PROCESSAR ==========');
      debugPrint('❌ Estado atual: ${currentState.description}');
      debugPrint('❌ Estados permitidos: idle, paymentMethodSelected');
      debugPrint('❌ Histórico: ${_stateMachine.stateHistory.map((s) => s.description).join(" → ")}');
      debugPrint('❌ ===========================================');
      
      // 🆕 Se não pode processar, tenta resetar automaticamente (última tentativa)
      if (currentState != PaymentFlowState.idle) {
        debugPrint('⚠️ [PaymentFlowProvider] Tentando reset automático...');
        reset();
        if (canProcessPayment) {
          debugPrint('✅ [PaymentFlowProvider] Reset automático bem-sucedido, continuando...');
        } else {
          _errorMessage = 'Não é possível processar pagamento no estado atual (${currentState.description}). Tente novamente.';
          notifyListeners();
          return false;
        }
      } else {
        _errorMessage = 'Não é possível processar pagamento no estado atual (${currentState.description})';
        notifyListeners();
        return false;
      }
    }
    
    // 🆕 2. Limpa estado anterior
    _errorMessage = null;
    _lastResult = null;
    _showWaitingCardDialog = false;
    
    // 🆕 3. Transiciona para processingPayment
    if (!_stateMachine.transitionTo(PaymentFlowState.processingPayment)) {
      debugPrint('❌ [PaymentFlowProvider] Falha ao transicionar para processingPayment');
      _errorMessage = 'Erro ao iniciar processamento';
      notifyListeners();
      return false;
    }
    notifyListeners(); // UI atualiza (mostra loading)
    debugPrint('📢 [PaymentFlowProvider] Estado: ${currentState.description}');
    
    try {
      // 4. Chama PaymentService passando this como uiNotifier
      debugPrint('💳 [PaymentFlowProvider] Chamando PaymentService.processPayment()...');
      final result = await _paymentService.processPayment(
        providerKey: providerKey,
        amount: amount,
        vendaId: vendaId,
        additionalData: additionalData,
        uiNotifier: this, // 🎯 Passa this como notificador
      );
      
      // 🆕 5. Atualiza resultado e transiciona baseado no resultado
      _lastResult = result;
      
      if (!result.success) {
        // Transiciona para paymentFailed
        _stateMachine.transitionTo(PaymentFlowState.paymentFailed);
        _errorMessage = result.errorMessage ?? 'Erro desconhecido ao processar pagamento';
        debugPrint('❌ [PaymentFlowProvider] Pagamento falhou: $_errorMessage');
      } else {
        // Transiciona para paymentProcessed
        _stateMachine.transitionTo(PaymentFlowState.paymentProcessed);
        debugPrint('✅ [PaymentFlowProvider] Pagamento processado com sucesso');
        
        // 🆕 NOTA: O registro no servidor deve ser feito pela UI chamando registerPayment()
        // Isso permite que a UI prepare os dados necessários (produtos, etc.)
        // O provider fica em paymentProcessed aguardando o registro
        
        debugPrint('🔄 [PaymentFlowProvider] Estado: paymentProcessed - aguardando registro no servidor');
      }
      
      // 6. Notifica UI sobre mudança de estado
      notifyListeners(); // UI atualiza (esconde loading, mostra resultado)
      debugPrint('📢 [PaymentFlowProvider] Estado: ${currentState.description}');
      
      return result.success;
      
    } catch (e, stackTrace) {
      debugPrint('❌ [PaymentFlowProvider] Exceção ao processar pagamento: $e');
      debugPrint('❌ [PaymentFlowProvider] Stack trace: $stackTrace');
      
      // 🆕 Transiciona para paymentFailed
      _stateMachine.transitionTo(PaymentFlowState.paymentFailed);
      _errorMessage = e.toString();
      _showWaitingCardDialog = false; // Garante que dialog seja escondido
      
      // Notifica UI sobre erro
      notifyListeners(); // UI atualiza (esconde loading, mostra erro)
      debugPrint('📢 [PaymentFlowProvider] Estado: ${currentState.description}');
      
      return false;
    }
  }
  
  /// 🆕 Registra pagamento no servidor
  /// 
  /// **Parâmetros:**
  /// - [vendaService] - Serviço de vendas para registrar pagamento
  /// - [vendaId] - ID da venda
  /// - [valor] - Valor do pagamento
  /// - [formaPagamento] - Forma de pagamento (ex: "Dinheiro", "Cartão Crédito")
  /// - [tipoFormaPagamento] - Tipo de forma de pagamento (1=Dinheiro, 2=Crédito, 3=Débito)
  /// - [bandeiraCartao] - Bandeira do cartão (se aplicável)
  /// - [identificadorTransacao] - ID da transação (se aplicável)
  /// - [produtos] - Lista de produtos para nota fiscal parcial (opcional)
  /// - [transactionData] - Dados padronizados da transação (opcional)
  /// 
  /// **Retorna:**
  /// - `true` se pagamento foi registrado com sucesso
  /// - `false` se houve erro (verificar errorMessage)
  /// 
  /// **Fluxo:**
  /// 1. Valida se está em paymentProcessed
  /// 2. Transiciona para registeringPayment
  /// 3. Chama vendaService.registrarPagamento()
  /// 4. Se sucesso: verifica saldo e transiciona para readyToComplete ou idle
  /// 5. Se falha: transiciona para paymentFailed
  Future<bool> registerPayment({
    required VendaService vendaService,
    String? vendaId, // Opcional: para compatibilidade
    List<String>? vendaIds, // Lista de IDs para pagamento múltiplo
    required double valor,
    required String formaPagamento,
    required int tipoFormaPagamento,
    String? bandeiraCartao,
    String? identificadorTransacao,
    List<Map<String, dynamic>>? produtos,
    PaymentTransactionData? transactionData,
    String? clienteCPF,
  }) async {
    debugPrint('📤 [PaymentFlowProvider] ========== REGISTRANDO PAGAMENTO ==========');
    debugPrint('📤 Estado atual: ${currentState.description}');
    
    // Valida se está em paymentProcessed
    if (currentState != PaymentFlowState.paymentProcessed) {
      debugPrint('❌ [PaymentFlowProvider] Não pode registrar pagamento no estado: ${currentState.description}');
      _errorMessage = 'Não é possível registrar pagamento no estado atual';
      notifyListeners();
      return false;
    }
    
    // Limpa erro anterior
    _errorMessage = null;
    
    // Transiciona para registeringPayment
    if (!_stateMachine.transitionTo(PaymentFlowState.registeringPayment)) {
      debugPrint('❌ [PaymentFlowProvider] Falha ao transicionar para registeringPayment');
      _errorMessage = 'Erro ao iniciar registro';
      notifyListeners();
      return false;
    }
    notifyListeners(); // UI atualiza (mostra "Registrando pagamento...")
    debugPrint('📢 [PaymentFlowProvider] Estado: ${currentState.description}');
    
    try {
      // Determinar IDs a usar
      final idsParaUsar = vendaIds ?? (vendaId != null ? [vendaId] : null);
      
      if (idsParaUsar == null || idsParaUsar.isEmpty) {
        _errorMessage = 'Deve ser fornecido vendaId ou vendaIds';
        _stateMachine.transitionTo(PaymentFlowState.paymentFailed);
        notifyListeners();
        return false;
      }
      
      // Chama serviço de vendas
      debugPrint('📤 [PaymentFlowProvider] Chamando vendaService.registrarPagamento()...');
      debugPrint('📤 IDs de vendas: ${idsParaUsar.join(", ")}');
      
      final response = await vendaService.registrarPagamento(
        vendaId: idsParaUsar.length == 1 ? idsParaUsar.first : null,
        vendaIds: idsParaUsar.length > 1 ? idsParaUsar : null,
        valor: valor,
        formaPagamento: formaPagamento,
        tipoFormaPagamento: tipoFormaPagamento,
        bandeiraCartao: bandeiraCartao,
        identificadorTransacao: identificadorTransacao,
        produtos: produtos,
        transactionData: _lastResult?.transactionData,
        clienteCPF: clienteCPF,
      );
      
      if (!response.success) {
        // Transiciona para paymentFailed
        _stateMachine.transitionTo(PaymentFlowState.paymentFailed);
        _errorMessage = response.message.isNotEmpty ? response.message : 'Erro ao registrar pagamento no servidor';
        notifyListeners();
        debugPrint('❌ [PaymentFlowProvider] Falha ao registrar pagamento: $_errorMessage');
        debugPrint('📢 [PaymentFlowProvider] Estado: ${currentState.description}');
        return false;
      }
      
      debugPrint('✅ [PaymentFlowProvider] Pagamento registrado com sucesso');
      
      // Busca venda atualizada para verificar saldo
      // Se múltiplas vendas, usa o ID da venda retornada (agrupada)
      final vendaIdParaBuscar = response.data?.id ?? (idsParaUsar.length == 1 ? idsParaUsar.first : null);
      
      if (vendaIdParaBuscar == null) {
        // Se não conseguiu obter ID, assume que pode continuar
        _stateMachine.transitionTo(PaymentFlowState.idle);
        notifyListeners();
        return true;
      }
      
      final vendaResponse = await vendaService.getVendaById(vendaIdParaBuscar);
      if (vendaResponse.success && vendaResponse.data != null) {
        final vendaAtualizada = vendaResponse.data!;
        // 🆕 Armazena venda atualizada para expor via getter
        _vendaAtualizadaAposPagamento = vendaAtualizada;
        
        final saldoRestante = vendaAtualizada.saldoRestante;
        final saldoZerou = saldoRestante <= 0.01;
        
        if (saldoZerou) {
          // Saldo zerou, transiciona para readyToComplete
          _stateMachine.transitionTo(PaymentFlowState.readyToComplete);
          debugPrint('💰 [PaymentFlowProvider] Saldo zerou! Pronto para concluir');
        } else {
          // Ainda há saldo, volta para idle para permitir mais pagamentos
          _stateMachine.transitionTo(PaymentFlowState.idle);
          debugPrint('💰 [PaymentFlowProvider] Ainda há saldo. Permitindo mais pagamentos');
        }
      } else {
        // Se não conseguiu buscar venda, assume que pode continuar
        _stateMachine.transitionTo(PaymentFlowState.idle);
      }
      
      notifyListeners();
      debugPrint('📢 [PaymentFlowProvider] Estado: ${currentState.description}');
      return true;
      
    } catch (e, stackTrace) {
      debugPrint('❌ [PaymentFlowProvider] Exceção ao registrar pagamento: $e');
      debugPrint('❌ [PaymentFlowProvider] Stack trace: $stackTrace');
      
      // Transiciona para paymentFailed
      _stateMachine.transitionTo(PaymentFlowState.paymentFailed);
      _errorMessage = e.toString();
      notifyListeners();
      debugPrint('📢 [PaymentFlowProvider] Estado: ${currentState.description}');
      return false;
    }
  }
  
  /// 🆕 Marca que o saldo zerou e está pronto para concluir
  /// 
  /// Deve ser chamado pela UI após verificar que o saldo zerou.
  /// Pode ser chamado de `paymentProcessed` ou `idle`.
  void markReadyToComplete() {
    debugPrint('🔄 [PaymentFlowProvider] ========== MARK READY TO COMPLETE ==========');
    debugPrint('🔄 Estado atual: ${currentState.description}');
    debugPrint('🔄 canConcludeSale antes: $canConcludeSale');
    
    // Permite transição de paymentProcessed ou idle para readyToComplete
    if (_stateMachine.transitionTo(PaymentFlowState.readyToComplete)) {
      debugPrint('✅ [PaymentFlowProvider] Pronto para concluir venda');
      debugPrint('🔄 Estado após: ${currentState.description}');
      debugPrint('🔄 canConcludeSale após: $canConcludeSale');
      debugPrint('🔄 ===========================================');
      notifyListeners();
    } else {
      debugPrint('❌ [PaymentFlowProvider] Falha ao transicionar para readyToComplete');
      debugPrint('❌ Estado atual: ${currentState.description}');
      debugPrint('❌ ===========================================');
    }
  }
  
  /// 🆕 Conclui a venda (emite nota fiscal final)
  /// 
  /// **Parâmetros:**
  /// - [concluirVendaCallback] - Função que chama o serviço de vendas para concluir a venda
  /// - [vendaId] - ID da venda a ser concluída
  /// 
  /// **Retorna:**
  /// - `true` se venda foi concluída com sucesso
  /// - `false` se houve erro (verificar errorMessage)
  /// 
  /// **Fluxo:**
  /// 1. Transiciona para concludingSale
  /// 2. Chama concluirVendaCallback()
  /// 3. Se sucesso: transiciona para saleCompleted
  /// 4. Se tem nota fiscal: transiciona para creatingInvoice (emissão automática)
  /// 5. Se falha: transiciona para completionFailed
  Future<bool> concludeSale({
    required String vendaId,
    required Future<ApiResponse<VendaDto>> Function(String) concluirVendaCallback,
    required Future<ApiResponse<VendaDto>> Function(String) getVendaCallback,
  }) async {
    debugPrint('🏁 [PaymentFlowProvider] Iniciando conclusão de venda');
    debugPrint('🏁 Estado atual: ${currentState.description}');
    
    // Valida se pode concluir
    if (!canConcludeSale) {
      debugPrint('❌ [PaymentFlowProvider] Não pode concluir venda no estado: ${currentState.description}');
      _errorMessage = 'Não é possível concluir venda no estado atual';
      notifyListeners();
      return false;
    }
    
    // Limpa estado anterior
    _errorMessage = null;
    
    // Transiciona para concludingSale
    if (!_stateMachine.transitionTo(PaymentFlowState.concludingSale)) {
      debugPrint('❌ [PaymentFlowProvider] Falha ao transicionar para concludingSale');
      _errorMessage = 'Erro ao iniciar conclusão';
      notifyListeners();
      return false;
    }
    notifyListeners(); // UI atualiza (mostra "Concluindo venda...")
    debugPrint('📢 [PaymentFlowProvider] Estado: ${currentState.description}');
    
    try {
      // Chama serviço de venda
      debugPrint('🏁 [PaymentFlowProvider] Chamando concluirVendaCallback()...');
      final response = await concluirVendaCallback(vendaId);
      
      if (response.success && response.data != null) {
        final vendaFinalizada = response.data!;
        debugPrint('✅ [PaymentFlowProvider] Venda concluída com sucesso');
        
        // Transiciona para saleCompleted
        _stateMachine.transitionTo(PaymentFlowState.saleCompleted);
        notifyListeners();
        debugPrint('📢 [PaymentFlowProvider] Estado: ${currentState.description}');
        
        // Se tem nota fiscal, verifica status com retentativas
        if (vendaFinalizada.notaFiscal != null) {
          final notaFiscalId = vendaFinalizada.notaFiscal!.id;
          
          // 🆕 Guarda dados da venda finalizada para UI usar
          _vendaFinalizadaData = {
            'notaFiscalId': notaFiscalId,
            'vendaFinalizada': vendaFinalizada,
          };
          
          // 🆕 Verifica se nota já foi autorizada na resposta
          if (vendaFinalizada.notaFiscal!.foiAutorizada) {
            debugPrint('✅ [PaymentFlowProvider] Nota fiscal já autorizada na conclusão!');
            _notaFiscalStatus = NotaFiscalStatus.fromVendaNotaFiscal(
              notaFiscalId: notaFiscalId,
              chaveAcesso: vendaFinalizada.notaFiscal!.chaveAcesso,
              protocoloAutorizacao: vendaFinalizada.notaFiscal!.protocoloAutorizacao,
              foiAutorizada: true,
              dataAutorizacao: vendaFinalizada.notaFiscal!.dataAutorizacao,
            );
            _stateMachine.transitionTo(PaymentFlowState.invoiceAuthorized);
            notifyListeners();
            return true;
          }
          
          // 🆕 Se nota existe mas não foi autorizada, faz polling para verificar status
          // A nota já foi criada pelo backend, apenas aguardamos autorização da SEFAZ
          debugPrint('📄 [PaymentFlowProvider] Nota fiscal criada pelo backend, verificando status com retentativas...');
          final success = await emitInvoiceWithRetry(
            vendaId: vendaId, // ✅ Passa vendaId, não notaFiscalId
            getVendaCallback: getVendaCallback, // ✅ Usa callback correto para buscar venda
          );
          
          if (success) {
            // Nota autorizada, pode imprimir
            return true;
          } else {
            // Falhou após retentativas
            return false;
          }
        } else {
          // Sem nota fiscal, transiciona para completed
          _stateMachine.transitionTo(PaymentFlowState.completed);
          notifyListeners();
          debugPrint('📢 [PaymentFlowProvider] Estado: ${currentState.description}');
          return true;
        }
      } else {
        // Transiciona para completionFailed
        _stateMachine.transitionTo(PaymentFlowState.completionFailed);
        _errorMessage = response.message.isNotEmpty ? response.message : 'Erro ao concluir venda';
        notifyListeners();
        debugPrint('❌ [PaymentFlowProvider] Falha ao concluir venda: $_errorMessage');
        debugPrint('📢 [PaymentFlowProvider] Estado: ${currentState.description}');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [PaymentFlowProvider] Exceção ao concluir venda: $e');
      debugPrint('❌ [PaymentFlowProvider] Stack trace: $stackTrace');
      
      // Transiciona para completionFailed
      _stateMachine.transitionTo(PaymentFlowState.completionFailed);
      _errorMessage = e.toString();
      notifyListeners();
      debugPrint('📢 [PaymentFlowProvider] Estado: ${currentState.description}');
      return false;
    }
  }
  
  /// 🆕 Verifica status da nota fiscal com retentativas automáticas
  /// 
  /// **Nota:** A nota fiscal já é criada pelo backend quando a venda é concluída.
  /// Este método apenas faz polling para verificar se ela foi autorizada pela SEFAZ.
  /// 
  /// **Parâmetros:**
  /// - [vendaId] - ID da venda (para buscar e verificar status da nota fiscal)
  /// - [getVendaCallback] - Função para buscar venda atualizada e verificar status da nota
  /// 
  /// **Retorna:**
  /// - `true` se nota foi autorizada com sucesso
  /// - `false` se houve erro após todas as tentativas (verificar errorMessage)
  /// 
  /// **Fluxo:**
  /// 1. Faz polling da venda para verificar status da nota (já criada pelo backend)
  /// 2. Se autorizada: transiciona para invoiceAuthorized
  /// 3. Se ainda não autorizada: tenta novamente (até MAX_TENTATIVAS_EMISSAO)
  /// 4. Se erro: transiciona para invoiceFailed
  Future<bool> emitInvoiceWithRetry({
    required String vendaId, // ✅ Muda de notaFiscalId para vendaId
    required Future<ApiResponse<VendaDto>> Function(String) getVendaCallback,
  }) async {
    debugPrint('📄 [PaymentFlowProvider] ========== EMITINDO NOTA COM RETENTATIVAS ==========');
    debugPrint('📄 Venda ID: $vendaId');
    
    _tentativasEmissao = 0;
    _notaFiscalStatus = null;
    
    while (_tentativasEmissao < MAX_TENTATIVAS_EMISSAO) {
      _tentativasEmissao++;
      
      debugPrint('📄 [PaymentFlowProvider] Tentativa $_tentativasEmissao/$MAX_TENTATIVAS_EMISSAO');
      
      // Transiciona para creatingInvoice na primeira tentativa
      if (_tentativasEmissao == 1) {
        if (!_stateMachine.transitionTo(PaymentFlowState.creatingInvoice)) {
          debugPrint('❌ [PaymentFlowProvider] Falha ao transicionar para creatingInvoice');
          _errorMessage = 'Erro ao iniciar emissão';
          notifyListeners();
          return false;
        }
        notifyListeners();
      } else {
        // Retentativa: mantém em sendingToSefaz (não tenta voltar para creatingInvoice)
        debugPrint('🔄 [PaymentFlowProvider] Retentando verificação...');
        // Se estiver em invoiceFailed, volta para sendingToSefaz
        if (currentState == PaymentFlowState.invoiceFailed) {
          _stateMachine.transitionTo(PaymentFlowState.sendingToSefaz);
        }
        // Se já estiver em sendingToSefaz, mantém (não precisa transicionar)
        notifyListeners();
      }
      
      // Aguarda um pouco antes de verificar (para dar tempo do backend processar)
      if (_tentativasEmissao > 1) {
        await Future.delayed(Duration(seconds: INTERVALO_TENTATIVAS_SEGUNDOS));
      }
      
      // Transiciona para sendingToSefaz apenas se ainda não estiver
      if (currentState != PaymentFlowState.sendingToSefaz) {
        _stateMachine.transitionTo(PaymentFlowState.sendingToSefaz);
        notifyListeners();
      }
      
      try {
        // Busca venda atualizada para verificar status da nota
        debugPrint('📄 [PaymentFlowProvider] Buscando status da nota fiscal...');
        final vendaResponse = await getVendaCallback(vendaId); // ✅ Usa vendaId, não notaFiscalId
        
        if (!vendaResponse.success || vendaResponse.data == null) {
          debugPrint('⚠️ [PaymentFlowProvider] Erro ao buscar venda: ${vendaResponse.message}');
          
          if (_tentativasEmissao >= MAX_TENTATIVAS_EMISSAO) {
            _stateMachine.transitionTo(PaymentFlowState.invoiceFailed);
            _notaFiscalStatus = NotaFiscalStatus.error(
              notaFiscalId: '', // Nota não disponível em caso de erro
              erro: vendaResponse.message.isNotEmpty ? vendaResponse.message : 'Erro ao buscar status da nota fiscal',
              tentativas: _tentativasEmissao,
            );
            _errorMessage = 'Erro ao buscar status da nota fiscal após $_tentativasEmissao tentativas';
            notifyListeners();
            return false;
          }
          continue; // Tenta novamente
        }
        
        final venda = vendaResponse.data!;
        final notaFiscal = venda.notaFiscal;
        
        if (notaFiscal == null) {
          debugPrint('⚠️ [PaymentFlowProvider] Nota fiscal ainda não foi criada');
          
          if (_tentativasEmissao >= MAX_TENTATIVAS_EMISSAO) {
            _stateMachine.transitionTo(PaymentFlowState.invoiceFailed);
            _notaFiscalStatus = NotaFiscalStatus.error(
              notaFiscalId: '', // Nota ainda não foi criada
              erro: 'Nota fiscal não foi criada após $_tentativasEmissao tentativas',
              tentativas: _tentativasEmissao,
            );
            _errorMessage = 'Nota fiscal não foi criada após múltiplas tentativas';
            notifyListeners();
            return false;
          }
          continue; // Tenta novamente
        }
        
        // Atualiza status da nota
        final foiAutorizada = notaFiscal.foiAutorizada;
        _notaFiscalStatus = NotaFiscalStatus.fromVendaNotaFiscal(
          notaFiscalId: notaFiscal.id,
          chaveAcesso: notaFiscal.chaveAcesso,
          protocoloAutorizacao: notaFiscal.protocoloAutorizacao,
          foiAutorizada: foiAutorizada,
          motivoRejeicao: notaFiscal.erroIntegracao, // Usa erroIntegracao como motivo de rejeição
          dataAutorizacao: notaFiscal.dataAutorizacao,
          tentativas: _tentativasEmissao,
        );
        
        // Verifica se foi autorizada
        if (foiAutorizada) {
          // ✅ Sucesso!
          debugPrint('✅ [PaymentFlowProvider] Nota fiscal autorizada!');
          _stateMachine.transitionTo(PaymentFlowState.invoiceAuthorized);
          notifyListeners();
          return true;
        } else {
          // ❌ Rejeitada ou pendente
          final motivoRejeicao = notaFiscal.erroIntegracao ?? 'Aguardando processamento';
          debugPrint('❌ [PaymentFlowProvider] Nota fiscal não autorizada: $motivoRejeicao');
          
          if (_tentativasEmissao >= MAX_TENTATIVAS_EMISSAO) {
            _stateMachine.transitionTo(PaymentFlowState.invoiceFailed);
            _errorMessage = 'Nota fiscal não autorizada: $motivoRejeicao';
            notifyListeners();
            return false;
          }
          
          // Aguarda antes de retentar
          await Future.delayed(Duration(seconds: INTERVALO_TENTATIVAS_SEGUNDOS));
          continue; // Tenta novamente
        }
        
      } catch (e, stackTrace) {
        debugPrint('❌ [PaymentFlowProvider] Exceção ao verificar status da nota: $e');
        debugPrint('❌ [PaymentFlowProvider] Stack trace: $stackTrace');
        
        if (_tentativasEmissao >= MAX_TENTATIVAS_EMISSAO) {
          _stateMachine.transitionTo(PaymentFlowState.invoiceFailed);
          _notaFiscalStatus = NotaFiscalStatus.error(
            notaFiscalId: '', // Não temos ID da nota em caso de exceção
            erro: e.toString(),
            tentativas: _tentativasEmissao,
          );
          _errorMessage = 'Erro ao verificar status da nota fiscal: ${e.toString()}';
          notifyListeners();
          return false;
        }
        
        // Aguarda antes de retentar
        await Future.delayed(Duration(seconds: INTERVALO_TENTATIVAS_SEGUNDOS));
        continue; // Tenta novamente
      }
    }
    
    // Se chegou aqui, esgotou todas as tentativas
    _stateMachine.transitionTo(PaymentFlowState.invoiceFailed);
    _errorMessage = 'Falha ao emitir nota fiscal após $_tentativasEmissao tentativas';
    notifyListeners();
    return false;
  }
  
  /// 🆕 Imprime nota fiscal
  /// 
  /// **Parâmetros:**
  /// - [printNfceCallback] - Função que chama o serviço de impressão
  /// - [notaFiscalId] - ID da nota fiscal a ser impressa
  /// - [getDadosCallback] - Função para buscar dados da nota fiscal (opcional)
  /// 
  /// **Retorna:**
  /// - `true` se impressão foi bem-sucedida
  /// - `false` se houve erro (verificar errorMessage)
  /// 
  /// **Fluxo:**
  /// 1. Transiciona para printingInvoice
  /// 2. Busca dados da nota fiscal (se necessário)
  /// 3. Chama printNfceCallback()
  /// 4. Se sucesso: transiciona para printSuccess → completed
  /// 5. Se falha: transiciona para printFailed
  Future<bool> printInvoice({
    required Future<PrintResult> Function(NfcePrintData) printNfceCallback,
    required String notaFiscalId,
    required Future<ApiResponse<NfcePrintData?>> Function(String) getDadosCallback,
  }) async {
    debugPrint('🖨️ [PaymentFlowProvider] Iniciando impressão de nota fiscal');
    debugPrint('🖨️ Estado atual: ${currentState.description}');
    
    // Valida se pode imprimir
    if (currentState != PaymentFlowState.invoiceAuthorized && 
        currentState != PaymentFlowState.printFailed) {
      debugPrint('❌ [PaymentFlowProvider] Não pode imprimir no estado: ${currentState.description}');
      _errorMessage = 'Não é possível imprimir no estado atual';
      notifyListeners();
      return false;
    }
    
    // Limpa estado anterior
    _errorMessage = null;
    
    // Transiciona para printingInvoice
    if (!_stateMachine.transitionTo(PaymentFlowState.printingInvoice)) {
      debugPrint('❌ [PaymentFlowProvider] Falha ao transicionar para printingInvoice');
      _errorMessage = 'Erro ao iniciar impressão';
      notifyListeners();
      return false;
    }
    notifyListeners(); // UI atualiza (mostra "Imprimindo...")
    debugPrint('📢 [PaymentFlowProvider] Estado: ${currentState.description}');
    
    try {
      // Busca dados da nota fiscal (obrigatório)
      debugPrint('🖨️ [PaymentFlowProvider] Buscando dados da nota fiscal...');
      final dadosResponse = await getDadosCallback(notaFiscalId);
      if (!dadosResponse.success || dadosResponse.data == null) {
        _stateMachine.transitionTo(PaymentFlowState.printFailed);
        _errorMessage = dadosResponse.message.isNotEmpty ? dadosResponse.message : 'Erro ao buscar dados da nota fiscal';
        notifyListeners();
        return false;
      }
      final dadosNfce = dadosResponse.data!;
      
      // Chama serviço de impressão
      debugPrint('🖨️ [PaymentFlowProvider] Chamando printNfceCallback()...');
      final printResult = await printNfceCallback(dadosNfce);
      
      if (printResult.success) {
        debugPrint('✅ [PaymentFlowProvider] Nota fiscal impressa com sucesso');
        
        // Transiciona para printSuccess
        _stateMachine.transitionTo(PaymentFlowState.printSuccess);
        notifyListeners();
        debugPrint('📢 [PaymentFlowProvider] Estado: ${currentState.description}');
        
        // Transiciona para completed
        _stateMachine.transitionTo(PaymentFlowState.completed);
        notifyListeners();
        debugPrint('📢 [PaymentFlowProvider] Estado: ${currentState.description}');
        
        return true;
      } else {
        // Transiciona para printFailed
        _stateMachine.transitionTo(PaymentFlowState.printFailed);
        _errorMessage = printResult.errorMessage ?? 'Erro ao imprimir nota fiscal';
        notifyListeners();
        debugPrint('❌ [PaymentFlowProvider] Falha ao imprimir: $_errorMessage');
        debugPrint('📢 [PaymentFlowProvider] Estado: ${currentState.description}');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [PaymentFlowProvider] Exceção ao imprimir: $e');
      debugPrint('❌ [PaymentFlowProvider] Stack trace: $stackTrace');
      
      // Transiciona para printFailed
      _stateMachine.transitionTo(PaymentFlowState.printFailed);
      _errorMessage = e.toString();
      notifyListeners();
      debugPrint('📢 [PaymentFlowProvider] Estado: ${currentState.description}');
      return false;
    }
  }
  
  /// 🆕 Faz retry da última operação que falhou
  Future<bool> retry() async {
    if (!canRetry) {
      debugPrint('❌ [PaymentFlowProvider] Não pode fazer retry no estado: ${currentState.description}');
      return false;
    }
    
    debugPrint('🔄 [PaymentFlowProvider] Fazendo retry...');
    
    // Baseado no estado atual, decide qual operação retry
    switch (currentState) {
      case PaymentFlowState.paymentFailed:
        // Retry do pagamento - volta para processingPayment
        // A UI deve chamar processPayment novamente
        _stateMachine.transitionTo(PaymentFlowState.idle);
        notifyListeners();
        return true;
      
      case PaymentFlowState.completionFailed:
        // Retry da conclusão - volta para readyToComplete para permitir nova tentativa
        // A UI deve chamar concludeSale novamente
        // Como não há transição direta, vamos para idle e depois readyToComplete
        // Mas na prática, a UI deve verificar se ainda pode concluir (saldo zerou)
        _stateMachine.transitionTo(PaymentFlowState.idle);
        // Limpa erro para permitir nova tentativa
        _errorMessage = null;
        notifyListeners();
        return true;
      
      case PaymentFlowState.invoiceFailed:
        // Retry da emissão - volta para saleCompleted para permitir nova tentativa
        // A UI deve chamar emitInvoice novamente
        // Como não há transição direta, vamos para saleCompleted
        if (!_stateMachine.transitionTo(PaymentFlowState.saleCompleted)) {
          // Se não conseguir, tenta via idle
          _stateMachine.transitionTo(PaymentFlowState.idle);
        }
        _errorMessage = null;
        notifyListeners();
        return true;
      
      case PaymentFlowState.printFailed:
        // Retry da impressão - volta para invoiceAuthorized para permitir nova tentativa
        // A UI deve chamar printInvoice novamente
        if (!_stateMachine.transitionTo(PaymentFlowState.invoiceAuthorized)) {
          // Se não conseguir, tenta via saleCompleted
          if (!_stateMachine.transitionTo(PaymentFlowState.saleCompleted)) {
            _stateMachine.transitionTo(PaymentFlowState.idle);
          }
        }
        _errorMessage = null;
        notifyListeners();
        return true;
      
      default:
        return false;
    }
  }
  
  /// 🆕 Reseta o fluxo para estado inicial
  /// 
  /// Deve ser chamado quando:
  /// - Abre uma nova tela de pagamento
  /// - Cancela uma venda
  /// - Finaliza um fluxo e quer começar outro
  void reset() {
    debugPrint('🔄 [PaymentFlowProvider] ========== RESETANDO FLUXO ==========');
    debugPrint('🔄 Estado antes do reset: ${currentState.description}');
    
    _stateMachine.reset();
    _errorMessage = null;
    _lastResult = null;
    _vendaFinalizadaData = null; // 🆕 Limpa dados da venda finalizada
    _vendaAtualizadaAposPagamento = null; // 🆕 Limpa venda atualizada
    _notaFiscalStatus = null; // 🆕 Limpa status da nota fiscal
    _tentativasEmissao = 0; // 🆕 Reseta tentativas
    _showWaitingCardDialog = false;
    
    debugPrint('🔄 Estado após reset: ${currentState.description}');
    debugPrint('🔄 canProcessPayment: $canProcessPayment');
    debugPrint('🔄 ===========================================');
    
    notifyListeners();
  }
  
  /// 🆕 Cancela o fluxo atual
  void cancel() {
    debugPrint('🚫 [PaymentFlowProvider] Cancelando fluxo');
    _stateMachine.cancel();
    _showWaitingCardDialog = false;
    notifyListeners();
  }
  
  /// 🆕 Prepara o fluxo para uma venda pendente
  /// 
  /// Deve ser chamado quando uma venda pendente é detectada e o usuário escolhe continuar.
  /// Reseta o estado e prepara para processar pagamentos da venda pendente.
  void prepareForPendingSale() {
    debugPrint('📋 [PaymentFlowProvider] Preparando para venda pendente');
    reset(); // Reseta para estado inicial
    // Estado já está em idle após reset, pronto para processar pagamentos
  }
  
  /// 🆕 Cancela venda pendente
  /// 
  /// Deve ser chamado quando o usuário escolhe cancelar uma venda pendente.
  /// Reseta completamente o fluxo e limpa todos os dados.
  void cancelPendingSale() {
    debugPrint('🚫 [PaymentFlowProvider] Cancelando venda pendente');
    reset(); // Reseta completamente
    // Estado volta para idle, pronto para nova venda
  }
  
  /// Limpa estado de erro
  /// 
  /// Útil quando UI quer limpar mensagem de erro sem processar novo pagamento
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners(); // UI atualiza (esconde erro)
      debugPrint('📢 [PaymentFlowProvider] Erro limpo');
    }
  }
  
  // ========== IMPLEMENTAÇÃO DE PaymentUINotifier ==========
  
  /// Recebe notificações de providers sobre eventos de UI
  /// 
  /// **Quando é chamado:**
  /// - Provider (ex: StonePOSAdapter) chama `uiNotifier?.notify(...)`
  /// - PaymentService repassa this como uiNotifier
  /// - Provider chama este método quando precisa notificar UI
  /// 
  /// **O que faz:**
  /// - Atualiza estado interno baseado no tipo de notificação
  /// - Chama notifyListeners() para UI atualizar
  /// 
  /// **Exemplo:**
  /// ```dart
  /// // No StonePOSAdapter:
  /// uiNotifier?.notify(PaymentUINotification.showWaitingCard());
  /// 
  /// // Este método é chamado:
  /// notify(notification) {
  ///   _showWaitingCardDialog = true;
  ///   notifyListeners(); // UI mostra dialog
  /// }
  /// ```
  @override
  void notify(PaymentUINotification notification) {
    debugPrint('📢 [PaymentFlowProvider] Notificação recebida: ${notification.type}');
    
    switch (notification.type) {
      case PaymentUINotificationType.showWaitingCard:
        // Provider quer mostrar dialog "Aguardando cartão"
        _showWaitingCardDialog = true;
        _waitingCardMessage = notification.message ?? 'Aguardando cartão...';
        notifyListeners(); // UI atualiza (mostra dialog)
        debugPrint('📢 [PaymentFlowProvider] Dialog aguardando cartão: MOSTRAR');
        break;
        
      case PaymentUINotificationType.hideWaitingCard:
        // Provider quer esconder dialog "Aguardando cartão"
        _showWaitingCardDialog = false;
        notifyListeners(); // UI atualiza (esconde dialog)
        debugPrint('📢 [PaymentFlowProvider] Dialog aguardando cartão: ESCONDER');
        break;
        
      case PaymentUINotificationType.showMessage:
        // Provider quer mostrar mensagem genérica
        // Por enquanto apenas logamos, mas pode ser usado para toasts/snackbars
        debugPrint('📢 [PaymentFlowProvider] Mensagem: ${notification.message}');
        // TODO: Pode adicionar estado para mensagens se necessário
        break;
        
      case PaymentUINotificationType.showError:
        // Provider quer mostrar erro
        _errorMessage = notification.message ?? 'Erro desconhecido';
        notifyListeners(); // UI atualiza (mostra erro)
        debugPrint('📢 [PaymentFlowProvider] Erro: $_errorMessage');
        break;
    }
  }
}

