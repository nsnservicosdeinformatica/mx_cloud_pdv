import '../../../../core/printing/print_provider.dart';
import '../../../../core/printing/print_data.dart';
import '../../../../core/printing/nfce_print_data.dart';
import 'package:flutter/foundation.dart';
import 'package:stone_payments/stone_payments.dart';
import 'package:stone_payments/models/item_print_model.dart';
import 'package:stone_payments/enums/item_print_type_enum.dart';
import 'package:stone_payments/enums/type_owner_print_enum.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

/// Provider de impressão Stone Thermal (usa SDK Stone Payments para impressão)
/// 
/// A Stone também oferece impressão através do mesmo SDK
class StoneThermalAdapter implements PrintProvider {
  final Map<String, dynamic>? _settings;
  bool _initialized = false;
  
  // Imagem base64 para o cabeçalho da comanda
  // IMPORTANTE: Substitua a string abaixo com a imagem base64 completa fornecida pelo usuário
  // A imagem será exibida no topo da comanda impressa
  static const String _logoBase64 = 'iVBORw0KGgoAAAA...'; // Substitua com a imagem base64 completa
  
  StoneThermalAdapter({Map<String, dynamic>? settings}) : _settings = settings;
  
  @override
  String get providerName => 'Stone Thermal';
  
  @override
  PrintType get printType => PrintType.thermal;
  
  @override
  bool get isAvailable {
    try {
      return true; // Verificar se SDK está disponível
    } catch (e) {
      return false;
    }
  }
  
  @override
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      debugPrint('🔌 Inicializando Stone Thermal Printer...');
      
      // Stone usa o mesmo SDK de pagamento para impressão
      // Precisa ativar o SDK antes de usar qualquer funcionalidade
      // Se já estiver ativado (por exemplo, pelo StonePOSAdapter), não será erro
      final activated = await _activateStone();
      
      // Aguarda um pouco para garantir que o SDK está pronto
      await Future.delayed(const Duration(milliseconds: 200));
      
      if (!activated) {
        debugPrint('⚠️ [Print] Não foi possível ativar Stone na inicialização, mas continuando...');
      }
      
      _initialized = true;
      debugPrint('✅ Stone Thermal Printer inicializada');
    } catch (e) {
      // Se o erro for que já está ativado, não é crítico
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('koin') || errorStr.contains('already') || errorStr.contains('já')) {
        debugPrint('ℹ️ [Print] SDK já está ativado, continuando...');
        // Aguarda um pouco mesmo quando já está ativado
        await Future.delayed(const Duration(milliseconds: 200));
        _initialized = true;
      } else {
        debugPrint('❌ Erro ao inicializar Stone Thermal Printer: $e');
        // Não relança o erro - permite que a impressão tente mesmo assim
        // Se o SDK não estiver ativado, o erro aparecerá na impressão
        // Aguarda um pouco antes de marcar como inicializado
        await Future.delayed(const Duration(milliseconds: 200));
        _initialized = true; // Marca como inicializado para não tentar novamente
      }
    }
  }
  
  /// Ativa a máquina Stone (necessário para usar SDK)
  /// Retorna true se ativado com sucesso, false se já estava ativado ou erro não crítico
  Future<bool> _activateStone() async {
    try {
      final appName = _settings?['appName'] as String? ?? 'MX Cloud PDV';
      final stoneCode = _settings?['stoneCode'] as String? ?? '';
      
      if (stoneCode.isEmpty) {
        debugPrint('⚠️ [Print] StoneCode não configurado nas settings');
        // Tenta usar o mesmo código do adapter de pagamento se disponível
        // Por enquanto, lança exceção
        throw Exception('StoneCode não configurado');
      }
      
      debugPrint('🔌 [Print] Ativando Stone com StoneCode: $stoneCode');
      
      final result = await StonePayments.activateStone(
        appName: appName,
        stoneCode: stoneCode,
        qrCodeProviderId: _settings?['qrCodeProviderId'] as String?,
        qrCodeAuthorization: _settings?['qrCodeAuthorization'] as String?,
      );
      
      debugPrint('✅ [Print] Stone ativada com sucesso: $result');
      return true;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      // Se já estiver ativado ou Koin já iniciado, não é erro crítico
      if (errorStr.contains('already') || 
          errorStr.contains('já') || 
          errorStr.contains('koin') ||
          errorStr.contains('started')) {
        debugPrint('ℹ️ [Print] Stone já está ativada ou SDK já inicializado');
        return true; // Considera sucesso se já estava ativado
      }
      
      debugPrint('❌ [Print] Erro ao ativar Stone: $e');
      // Para impressão, vamos tentar mesmo assim (pode estar ativado pelo adapter de pagamento)
      // Se falhar na impressão, o erro será tratado lá
      return false;
    }
  }
  
  @override
  Future<void> disconnect() async {
    if (!_initialized) return;
    
    _initialized = false;
    debugPrint('🔌 Stone Thermal Printer desconectada');
  }
  
  @override
  Future<PrintResult> printComanda(PrintData data) async {
    // Garante que o SDK está inicializado e ativado
    if (!_initialized) {
      await initialize();
      // Aguarda um pouco mais na primeira inicialização para garantir que o SDK está completamente pronto
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    // Verifica se o SDK está realmente ativado antes de imprimir
    // Na primeira impressão, é importante garantir que está ativado
    bool activationVerified = false;
    int attempts = 0;
    const maxAttempts = 3;
    
    while (!activationVerified && attempts < maxAttempts) {
      try {
        final activated = await _activateStone();
        if (activated) {
          activationVerified = true;
          debugPrint('✅ [Print] SDK ativado e verificado (tentativa ${attempts + 1})');
        } else {
          // Se retornou false mas não lançou exceção, pode ser que já esteja ativado
          // por outro componente. Na primeira tentativa, aguarda um pouco e tenta novamente
          attempts++;
          if (attempts < maxAttempts) {
            debugPrint('⚠️ [Print] Ativação retornou false, aguardando e tentando novamente... (tentativa ${attempts + 1}/$maxAttempts)');
            await Future.delayed(const Duration(milliseconds: 300));
          } else {
            // Na última tentativa, assume que pode estar funcionando mesmo retornando false
            // (pode estar ativado por outro adapter)
            debugPrint('ℹ️ [Print] Ativação retornou false após $maxAttempts tentativas, mas continuando (pode estar ativado por outro componente)');
            activationVerified = true; // Continua mesmo assim
          }
        }
    } catch (e) {
        final errorStr = e.toString().toLowerCase();
        // Se já estiver ativado, considera sucesso
        if (errorStr.contains('already') || 
            errorStr.contains('já') || 
            errorStr.contains('koin') ||
            errorStr.contains('started')) {
          activationVerified = true;
          debugPrint('ℹ️ [Print] SDK já estava ativado');
        } else {
          attempts++;
          if (attempts < maxAttempts) {
            debugPrint('⚠️ [Print] Erro ao verificar ativação, tentando novamente... (tentativa ${attempts + 1}/$maxAttempts): $e');
            await Future.delayed(const Duration(milliseconds: 300));
          } else {
            // Na última tentativa, mesmo com erro, continua (pode estar funcionando)
            debugPrint('⚠️ [Print] Não foi possível verificar ativação após $maxAttempts tentativas, mas continuando (pode estar ativado por outro componente)');
            activationVerified = true; // Continua mesmo assim para não bloquear
          }
        }
      }
    }
    
    // Aguarda um pouco mais para garantir que tudo está pronto
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      debugPrint('🖨️ Imprimindo comanda na Stone Thermal usando SDK...');
      
      // Constrói lista de itens para impressão usando ItemPrintModel
      final items = <ItemPrintModel>[];
      
      // ========== CABEÇALHO COM IMAGEM ==========
      // Espaço inicial
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      // Imagem do logo (se disponível)
      try {
        if (_logoBase64.isNotEmpty && _logoBase64 != 'iVBORw0KGgoAAAA...') {
          // O SDK da Stone espera a string base64 diretamente no campo data
          items.add(ItemPrintModel(
            type: ItemPrintTypeEnum.image,
            data: _logoBase64,
          ));
          // Espaço após imagem
          items.add(const ItemPrintModel(
            type: ItemPrintTypeEnum.text,
            data: '',
          ));
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao processar imagem base64: $e');
        // Continua a impressão mesmo se a imagem falhar
      }
      
      // Linha separadora superior
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '════════════════════════════════',
      ));
      
      // Título centralizado e destacado
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: _centerText(data.header.title, 32),
      ));
      
      // Subtítulo (se houver)
      if (data.header.subtitle != null && data.header.subtitle!.isNotEmpty) {
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: _centerText(data.header.subtitle!, 32),
        ));
      }
      
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      // Linha separadora
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '────────────────────────────────',
      ));
      
      // ========== INFORMAÇÕES DA COMANDA ==========
      // Data e hora formatadas
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: _formatDateTime(data.header.dateTime),
      ));
      
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      // Informações da mesa/comanda/cliente
      if (data.entityInfo.mesaNome != null) {
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: 'Mesa: ${data.entityInfo.mesaNome}',
        ));
      } else if (data.entityInfo.comandaCodigo != null) {
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: 'Comanda: ${data.entityInfo.comandaCodigo}',
        ));
      }
      
      if (data.entityInfo.clienteNome.isNotEmpty) {
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: 'Cliente: ${data.entityInfo.clienteNome}',
      ));
      }
      
      // Linha separadora
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '────────────────────────────────',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      // ========== ITENS ==========
      // Cabeçalho da tabela de itens
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: 'ITENS DO PEDIDO',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '────────────────────────────────',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      // Lista de itens formatada
      for (var i = 0; i < data.items.length; i++) {
        final item = data.items[i];
        
        // Número do item
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '${i + 1}. ${item.produtoNome}',
        ));
        
        // Variação se houver
        if (item.produtoVariacaoNome != null && item.produtoVariacaoNome!.isNotEmpty) {
          items.add(ItemPrintModel(
            type: ItemPrintTypeEnum.text,
            data: '   Variação: ${item.produtoVariacaoNome}',
          ));
        }
        
        // Quantidade e valores formatados
        final qtdStr = item.quantidade.toStringAsFixed(0);
        final unitStr = _formatCurrency(item.precoUnitario);
        final totalStr = _formatCurrency(item.valorTotal);
        
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '   Qtd: $qtdStr  |  Unit: $unitStr',
        ));
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '   Total: $totalStr',
        ));
        
        // Componentes removidos
        if (item.componentesRemovidos.isNotEmpty) {
          items.add(ItemPrintModel(
            type: ItemPrintTypeEnum.text,
            data: '   Sem: ${item.componentesRemovidos.join(', ')}',
          ));
        }
        
        // Espaço entre itens
        if (i < data.items.length - 1) {
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '',
        ));
      }
      }
      
      // Linha separadora antes dos totais
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '────────────────────────────────',
      ));
      
      // ========== TOTAIS ==========
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      // Subtotal
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: _alignRight('Subtotal:', _formatCurrency(data.totals.subtotal), 32),
      ));
      
      // Desconto
      if (data.totals.descontoTotal > 0) {
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: _alignRight('Desconto:', _formatCurrency(-data.totals.descontoTotal), 32),
        ));
      }
      
      // Acréscimo
      if (data.totals.acrescimoTotal > 0) {
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: _alignRight('Acréscimo:', _formatCurrency(data.totals.acrescimoTotal), 32),
        ));
      }
      
      // Impostos
      if (data.totals.impostosTotal > 0) {
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: _alignRight('Impostos:', _formatCurrency(data.totals.impostosTotal), 32),
        ));
      }
      
      // Linha separadora antes do total
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '────────────────────────────────',
      ));
      
      // Total destacado
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: _alignRight('TOTAL:', _formatCurrency(data.totals.valorTotal), 32),
      ));
      
      // Linha separadora após total
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '════════════════════════════════',
      ));
      
      // ========== RODAPÉ ==========
      if (data.footer.message != null && data.footer.message!.isNotEmpty) {
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '',
        ));
        
        // Quebra mensagem do rodapé em linhas e formata
        final footerLines = data.footer.message!.split('\n');
        for (final line in footerLines) {
          if (line.trim().isNotEmpty) {
            // Quebra linhas longas
            final wrappedLines = _wrapText(line.trim(), 32);
            for (final wrappedLine in wrappedLines) {
            items.add(ItemPrintModel(
              type: ItemPrintTypeEnum.text,
                data: wrappedLine,
            ));
            }
          }
        }
      }
      
      // Linha final
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '════════════════════════════════',
      ));
      
      // Espaços finais para cortar papel
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      debugPrint('🖨️ Enviando ${items.length} itens para impressão Stone SDK...');
      
      // Imprime usando SDK da Stone
      final result = await StonePayments.print(items);
      
      if (result != null && result.isNotEmpty) {
        debugPrint('✅ Impressão concluída: $result');
        return PrintResult(
          success: true,
          printJobId: 'STONE-SDK-${DateTime.now().millisecondsSinceEpoch}',
        );
      } else {
        debugPrint('⚠️ Impressão retornou resultado vazio');
        return PrintResult(
          success: true, // Considera sucesso mesmo sem retorno explícito
          printJobId: 'STONE-SDK-${DateTime.now().millisecondsSinceEpoch}',
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao imprimir comanda Stone: $e');
      return PrintResult(
        success: false,
        errorMessage: 'Erro ao imprimir: ${e.toString()}',
      );
    }
  }
  
  @override
  Future<PrintResult> printNfce(NfcePrintData data) async {
    // Garante que o SDK está inicializado e ativado
    if (!_initialized) {
      await initialize();
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    // Verifica se o SDK está realmente ativado antes de imprimir
    bool activationVerified = false;
    int attempts = 0;
    const maxAttempts = 3;
    
    while (!activationVerified && attempts < maxAttempts) {
      try {
        final activated = await _activateStone();
        if (activated) {
          activationVerified = true;
          debugPrint('✅ [Print NFC-e] SDK ativado e verificado (tentativa ${attempts + 1})');
        } else {
          attempts++;
          if (attempts < maxAttempts) {
            debugPrint('⚠️ [Print NFC-e] Ativação retornou false, aguardando e tentando novamente... (tentativa ${attempts + 1}/$maxAttempts)');
            await Future.delayed(const Duration(milliseconds: 300));
          } else {
            debugPrint('ℹ️ [Print NFC-e] Ativação retornou false após $maxAttempts tentativas, mas continuando');
            activationVerified = true;
          }
        }
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('already') || 
            errorStr.contains('já') || 
            errorStr.contains('koin') ||
            errorStr.contains('started')) {
          activationVerified = true;
          debugPrint('ℹ️ [Print NFC-e] SDK já estava ativado');
        } else {
          attempts++;
          if (attempts < maxAttempts) {
            debugPrint('⚠️ [Print NFC-e] Erro ao verificar ativação, tentando novamente... (tentativa ${attempts + 1}/$maxAttempts): $e');
            await Future.delayed(const Duration(milliseconds: 300));
          } else {
            debugPrint('⚠️ [Print NFC-e] Não foi possível verificar ativação após $maxAttempts tentativas, mas continuando');
            activationVerified = true;
          }
        }
      }
    }
    
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      debugPrint('🖨️ Imprimindo NFC-e na Stone Thermal usando SDK...');
      
      // Constrói lista de itens para impressão usando ItemPrintModel
      final items = <ItemPrintModel>[];
      
      // ========== CABEÇALHO ==========
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      // Razão Social
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: _centerText(data.empresaRazaoSocial, 32),
      ));
      
      // Nome Fantasia (se houver)
      if (data.empresaNomeFantasia != null && data.empresaNomeFantasia!.isNotEmpty) {
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: _centerText(data.empresaNomeFantasia!, 32),
        ));
      }
      
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      // CNPJ
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: _centerText('CNPJ: ${_formatCNPJ(data.empresaCnpj)}', 32),
      ));
      
      // Inscrição Estadual
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: _centerText('IE: ${data.empresaInscricaoEstadual}', 32),
      ));
      
      // Endereço (se houver)
      if (data.empresaEnderecoCompleto != null && data.empresaEnderecoCompleto!.isNotEmpty) {
        final enderecoLinhas = _wrapText(data.empresaEnderecoCompleto!, 32);
        for (final linha in enderecoLinhas) {
          items.add(ItemPrintModel(
            type: ItemPrintTypeEnum.text,
            data: _centerText(linha, 32),
          ));
        }
      }
      
      // Linha separadora
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '────────────────────────────────',
      ));
      
      // ========== DADOS DA NOTA FISCAL ==========
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: _centerText('DANFE NFC-e', 32),
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      // Número e Série
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: _centerText('Nº ${data.numero}  Série ${data.serie}', 32),
      ));
      
      // Chave de Acesso (formatada em grupos de 4)
      if (data.chaveAcesso.isNotEmpty) {
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '',
        ));
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: _centerText('Chave de Acesso:', 32),
        ));
        
        final chaveFormatada = _formatarChaveAcesso(data.chaveAcesso);
        final chaveLinhas = _wrapText(chaveFormatada, 32);
        for (final linha in chaveLinhas) {
          items.add(ItemPrintModel(
            type: ItemPrintTypeEnum.text,
            data: _centerText(linha, 32),
          ));
        }
      }
      
      // Data de Emissão
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: _centerText('Emissão: ${_formatDateTime(data.dataEmissao)}', 32),
      ));
      
      // Data de Autorização (se houver)
      if (data.dataAutorizacao != null) {
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: _centerText('Autorização: ${_formatDateTime(data.dataAutorizacao!)}', 32),
        ));
      }
      
      // Protocolo (se houver)
      if (data.protocoloAutorizacao != null && data.protocoloAutorizacao!.isNotEmpty) {
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: _centerText('Protocolo: ${data.protocoloAutorizacao}', 32),
        ));
      }
      
      // Linha separadora
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '────────────────────────────────',
      ));
      
      // ========== DADOS DO CLIENTE (se informado) ==========
      if (data.clienteNome != null && data.clienteNome!.isNotEmpty) {
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '',
        ));
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: 'CONSUMIDOR',
        ));
        
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: 'Nome: ${data.clienteNome}',
        ));
        
        if (data.clienteCPF != null && data.clienteCPF!.isNotEmpty) {
          items.add(ItemPrintModel(
            type: ItemPrintTypeEnum.text,
            data: 'CPF: ${_formatCPF(data.clienteCPF!)}',
          ));
        }
        
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '',
        ));
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '────────────────────────────────',
        ));
      }
      
      // ========== ITENS ==========
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: 'ITENS',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      for (var i = 0; i < data.itens.length; i++) {
        final item = data.itens[i];
        
        // Descrição do produto
        final descLinhas = _wrapText(item.descricao, 32);
        for (final linha in descLinhas) {
          items.add(ItemPrintModel(
            type: ItemPrintTypeEnum.text,
            data: linha,
          ));
        }
        
        // Código, NCM, CFOP
        var codigoInfo = 'Cód: ${item.codigo}';
        if (item.ncm != null && item.ncm!.isNotEmpty) {
          codigoInfo += '  NCM: ${item.ncm}';
        }
        if (item.cfop != null && item.cfop!.isNotEmpty) {
          codigoInfo += '  CFOP: ${item.cfop}';
        }
        final codigoLinhas = _wrapText(codigoInfo, 32);
        for (final linha in codigoLinhas) {
          items.add(ItemPrintModel(
            type: ItemPrintTypeEnum.text,
            data: linha,
          ));
        }
        
        // Quantidade e valores
        final qtdStr = item.quantidade.toStringAsFixed(2);
        final unitStr = _formatCurrency(item.valorUnitario);
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '$qtdStr ${item.unidade} x $unitStr',
        ));
        
        // Valor total do item
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: 'R\$ ${_formatCurrency(item.valorTotal)}',
        ));
        
        // Espaço entre itens
        if (i < data.itens.length - 1) {
          items.add(const ItemPrintModel(
            type: ItemPrintTypeEnum.text,
            data: '',
          ));
        }
      }
      
      // Linha separadora antes dos totais
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '────────────────────────────────',
      ));
      
      // ========== TOTAIS ==========
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: 'TOTAIS',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: 'Subtotal: ${_formatCurrency(data.valorTotalProdutos)}',
      ));
      
      if (data.valorTotalDesconto > 0) {
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: 'Desconto: ${_formatCurrency(data.valorTotalDesconto)}',
        ));
      }
      
      if (data.valorTotalImpostos > 0) {
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: 'Impostos: ${_formatCurrency(data.valorTotalImpostos)}',
        ));
      }
      
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: 'TOTAL: ${_formatCurrency(data.valorTotalNota)}',
      ));
      
      // ========== FORMAS DE PAGAMENTO ==========
      if (data.pagamentos.isNotEmpty) {
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '',
        ));
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: 'FORMA DE PAGAMENTO',
        ));
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '',
        ));
        
        for (final pagamento in data.pagamentos) {
          items.add(ItemPrintModel(
            type: ItemPrintTypeEnum.text,
            data: '${pagamento.formaPagamento}: ${_formatCurrency(pagamento.valor)}',
          ));
        }
      }
      
      // ========== QR CODE ==========
      if (data.qrCodeTexto != null && data.qrCodeTexto!.isNotEmpty) {
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '',
        ));
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '',
        ));
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: _centerText('Consulte pela Chave de Acesso em:', 32),
        ));
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '',
        ));
        
        // Gerar QR Code como imagem base64
        try {
          debugPrint('🔲 ========== INÍCIO PROCESSAMENTO QR CODE ==========');
          debugPrint('🔲 QR Code texto recebido: ${data.qrCodeTexto!.length} caracteres');
          debugPrint('🔲 QR Code texto (primeiros 100 chars): ${data.qrCodeTexto!.substring(0, data.qrCodeTexto!.length > 100 ? 100 : data.qrCodeTexto!.length)}...');
          
          final qrCodeImage = await _gerarQrCodeImagem(data.qrCodeTexto!);
          
          if (qrCodeImage != null && qrCodeImage.isNotEmpty) {
            debugPrint('✅ QR Code base64 gerado com sucesso!');
            debugPrint('🔲 Tamanho do base64: ${qrCodeImage.length} caracteres');
            debugPrint('🔲 Criando ItemPrintModel com type: ItemPrintTypeEnum.image...');
            
            // Adicionar linha em branco antes do QR Code para espaçamento
            items.add(const ItemPrintModel(
              type: ItemPrintTypeEnum.text,
              data: '',
            ));
            
            // Criar ItemPrintModel com tipo image e base64
            final qrCodeItem = ItemPrintModel(
              type: ItemPrintTypeEnum.image,
              data: qrCodeImage,
            );
            
            debugPrint('🔲 ItemPrintModel criado, adicionando à lista de impressão...');
            debugPrint('🔲 Tipo do item: ${qrCodeItem.type}');
            debugPrint('🔲 Tamanho do data: ${qrCodeItem.data.length} caracteres');
            debugPrint('🔲 Primeiros 50 chars do data: ${qrCodeItem.data.substring(0, qrCodeItem.data.length > 50 ? 50 : qrCodeItem.data.length)}...');
            
            items.add(qrCodeItem);
            
            // Adicionar linha em branco depois do QR Code para espaçamento
            items.add(const ItemPrintModel(
              type: ItemPrintTypeEnum.text,
              data: '',
            ));
            
            debugPrint('✅ QR Code ItemPrintModel adicionado à lista de impressão (centralizado)!');
            debugPrint('🔲 Total de itens na lista: ${items.length}');
            debugPrint('🔲 ========== FIM PROCESSAMENTO QR CODE ==========');
          } else {
            debugPrint('⚠️ QR Code base64 é null ou vazio - usando fallback texto');
            // Fallback: imprime QR Code como texto
            _adicionarQrCodeComoTexto(items, data.qrCodeTexto!);
          }
        } catch (e, stackTrace) {
          debugPrint('❌ ========== ERRO NO PROCESSAMENTO QR CODE ==========');
          debugPrint('❌ Erro: $e');
          debugPrint('❌ Stack trace: $stackTrace');
          debugPrint('❌ Usando fallback texto...');
          // Fallback: imprime QR Code como texto
          _adicionarQrCodeComoTexto(items, data.qrCodeTexto!);
        }
        
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '',
        ));
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: _centerText('NFC-e pode ser consultada em:', 32),
        ));
        
        // URL de consulta
        if (data.urlConsultaChave != null && data.urlConsultaChave!.isNotEmpty) {
          final urlLinhas = _wrapText(data.urlConsultaChave!, 32);
          for (final linha in urlLinhas) {
            items.add(ItemPrintModel(
              type: ItemPrintTypeEnum.text,
              data: _centerText(linha, 32),
            ));
          }
        }
      }
      
      // ========== INFORMAÇÕES ADICIONAIS ==========
      if (data.informacoesAdicionais != null && data.informacoesAdicionais!.isNotEmpty) {
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '',
        ));
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '',
        ));
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: 'INFORMAÇÕES ADICIONAIS',
        ));
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '',
        ));
        
        final infoLinhas = _wrapText(data.informacoesAdicionais!, 32);
        for (final linha in infoLinhas) {
          items.add(ItemPrintModel(
            type: ItemPrintTypeEnum.text,
            data: linha,
          ));
        }
      }
      
      // ========== RODAPÉ ==========
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: _centerText('Documento Auxiliar da Nota Fiscal de', 32),
      ));
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: _centerText('Consumidor Eletrônica', 32),
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: _centerText('Este documento não substitui a consulta', 32),
      ));
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: _centerText('pela Chave de Acesso', 32),
      ));
      
      // Linha final
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '════════════════════════════════',
      ));
      
      // Espaços finais para cortar papel
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      debugPrint('🖨️ ========== ENVIANDO PARA IMPRESSÃO ==========');
      debugPrint('🖨️ Total de itens na lista: ${items.length}');
      
      // Verificar se há QR Code na lista
      int qrCodeCount = 0;
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        if (item.type == ItemPrintTypeEnum.image) {
          qrCodeCount++;
          debugPrint('🖨️ Item $i: TIPO=IMAGE, tamanho data=${item.data.length} chars');
          debugPrint('🖨️ Item $i: Primeiros 50 chars=${item.data.substring(0, item.data.length > 50 ? 50 : item.data.length)}...');
        }
      }
      
      if (qrCodeCount > 0) {
        debugPrint('✅ QR Code encontrado na lista! Total de imagens: $qrCodeCount');
      } else {
        debugPrint('⚠️ NENHUM QR Code encontrado na lista de impressão!');
      }
      
      debugPrint('🖨️ Enviando ${items.length} itens para impressão NFC-e Stone SDK...');
      
      // Imprime usando SDK da Stone
      final result = await StonePayments.print(items);
      
      debugPrint('🖨️ Resultado da impressão: $result');
      debugPrint('🖨️ ===========================================');
      
      if (result != null && result.isNotEmpty) {
        debugPrint('✅ Impressão NFC-e concluída: $result');
        return PrintResult(
          success: true,
          printJobId: 'STONE-NFCE-${DateTime.now().millisecondsSinceEpoch}',
        );
      } else {
        debugPrint('⚠️ Impressão NFC-e retornou resultado vazio');
        return PrintResult(
          success: true, // Considera sucesso mesmo sem retorno explícito
          printJobId: 'STONE-NFCE-${DateTime.now().millisecondsSinceEpoch}',
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao imprimir NFC-e Stone: $e');
      return PrintResult(
        success: false,
        errorMessage: 'Erro ao imprimir NFC-e: ${e.toString()}',
      );
    }
  }
  
  @override
  Future<bool> checkPrinterStatus() async {
    if (!_initialized) return false;
    
    try {
      // Stone não tem verificação direta de status
      // Retorna true se inicializado
      return _initialized;
    } catch (e) {
      return false;
    }
  }
  
  String _formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }
  
  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
  
  /// Centraliza um texto em uma linha de largura específica
  String _centerText(String text, int width) {
    if (text.length >= width) {
      return text.substring(0, width);
    }
    final padding = (width - text.length) ~/ 2;
    return ' ' * padding + text;
  }
  
  /// Alinha texto à direita com label à esquerda
  String _alignRight(String label, String value, int width) {
    final labelValue = '$label $value';
    if (labelValue.length >= width) {
      return labelValue.substring(0, width);
    }
    final padding = width - labelValue.length;
    return label + ' ' * padding + value;
  }
  
  /// Quebra texto longo em múltiplas linhas respeitando o limite de caracteres
  List<String> _wrapText(String text, int maxWidth) {
    if (text.length <= maxWidth) {
      return [text];
    }
    
    final lines = <String>[];
    var currentLine = '';
    
    final words = text.split(' ');
    for (final word in words) {
      if (currentLine.isEmpty) {
        currentLine = word;
      } else if ((currentLine + ' ' + word).length <= maxWidth) {
        currentLine += ' $word';
      } else {
        lines.add(currentLine);
        currentLine = word;
      }
    }
    
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    
    return lines;
  }
  
  /// Formata CNPJ (14 dígitos) para formato XX.XXX.XXX/XXXX-XX
  String _formatCNPJ(String cnpj) {
    if (cnpj.length != 14) return cnpj;
    return '${cnpj.substring(0, 2)}.${cnpj.substring(2, 5)}.${cnpj.substring(5, 8)}/${cnpj.substring(8, 12)}-${cnpj.substring(12, 14)}';
  }
  
  /// Formata CPF (11 dígitos) para formato XXX.XXX.XXX-XX
  String _formatCPF(String cpf) {
    if (cpf.length != 11) return cpf;
    return '${cpf.substring(0, 3)}.${cpf.substring(3, 6)}.${cpf.substring(6, 9)}-${cpf.substring(9, 11)}';
  }
  
  /// Formata chave de acesso (44 dígitos) em grupos de 4
  String _formatarChaveAcesso(String chave) {
    if (chave.length != 44) return chave;
    final grupos = <String>[];
    for (int i = 0; i < chave.length; i += 4) {
      final tamanho = (i + 4 <= chave.length) ? 4 : chave.length - i;
      grupos.add(chave.substring(i, i + tamanho));
    }
    return grupos.join(' ');
  }
  
  /// Gera QR Code como imagem base64 para impressão
  /// Retorna null se houver erro
  /// 
  /// IMPORTANTE: O SDK da Stone espera base64 puro (sem prefixo data:image/...)
  /// Tamanho recomendado para impressora térmica 57mm: 100-120px
  Future<String?> _gerarQrCodeImagem(String qrCodeTexto) async {
    try {
      debugPrint('🔲 ========== INÍCIO GERAÇÃO QR CODE ==========');
      debugPrint('🔲 Tamanho do texto QR Code: ${qrCodeTexto.length} caracteres');
      debugPrint('🔲 QR Code texto (primeiros 100 chars): ${qrCodeTexto.substring(0, qrCodeTexto.length > 100 ? 100 : qrCodeTexto.length)}...');
      
      // Tamanho da imagem do QR Code (ajustado para impressora térmica 57mm)
      // Impressoras térmicas 57mm têm largura útil de ~48mm (aproximadamente 180-200 pixels)
      // Usar 200px para o QR Code e adicionar padding branco nas laterais para centralizar
      // Largura total da imagem: 240px (200px QR Code + 20px padding de cada lado)
      const qrSize = 200.0;
      const paddingLateral = 20.0; // Padding nas laterais para centralizar
      const paddingVertical = 10.0; // Padding vertical mínimo
      const totalWidth = qrSize + (paddingLateral * 2); // 240px de largura
      const totalHeight = qrSize + (paddingVertical * 2); // 220px de altura
      
      debugPrint('🔲 Criando QR Code painter com tamanho ${qrSize}x${qrSize}px (total: ${totalWidth}x${totalHeight}px)...');
      
      // Criar QR Code painter com correção de erro alta (H) para melhor legibilidade em impressão
      final qrPainter = QrPainter(
        data: qrCodeTexto,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H, // Alta correção de erro para impressão
        color: const ui.Color(0xFF000000), // Preto
        emptyColor: const ui.Color(0xFFFFFFFF), // Branco
      );
      
      debugPrint('🔲 QR Code painter criado, criando canvas...');
      
      // Criar um PictureRecorder para capturar a pintura
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Pintar fundo branco primeiro (importante para QR Code legível)
      final backgroundPaint = Paint()..color = const ui.Color(0xFFFFFFFF);
      canvas.drawRect(Rect.fromLTWH(0, 0, totalWidth, totalHeight), backgroundPaint);
      
      debugPrint('🔲 Fundo branco pintado, pintando QR Code centralizado...');
      
      // Pintar o QR Code centralizado no canvas
      // Centralizar horizontalmente: padding lateral
      // Centralizar verticalmente: padding vertical
      canvas.save();
      canvas.translate(paddingLateral, paddingVertical);
      qrPainter.paint(canvas, Size(qrSize, qrSize));
      canvas.restore();
      
      debugPrint('🔲 QR Code pintado no canvas, finalizando picture...');
      
      // Finalizar a pintura
      final picture = recorder.endRecording();
      final image = await picture.toImage(totalWidth.toInt(), totalHeight.toInt());
      
      debugPrint('🔲 Imagem criada (${totalWidth.toInt()}x${totalHeight.toInt()}px), convertendo para PNG...');
      
      // Converter para PNG bytes (PNG é melhor para QR Code - mantém qualidade)
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('❌ Erro: byteData é null após conversão para PNG');
        return null;
      }
      
      debugPrint('🔲 PNG bytes obtidos: ${byteData.lengthInBytes} bytes');
      
      // Converter para base64
      final pngBytes = byteData.buffer.asUint8List();
      final base64String = base64Encode(pngBytes);
      
      debugPrint('✅ QR Code gerado como base64 com sucesso!');
      debugPrint('🔲 Tamanho do base64: ${base64String.length} caracteres');
      debugPrint('🔲 Primeiros 100 caracteres: ${base64String.substring(0, base64String.length > 100 ? 100 : base64String.length)}...');
      debugPrint('🔲 Últimos 50 caracteres: ...${base64String.substring(base64String.length > 50 ? base64String.length - 50 : 0)}');
      debugPrint('🔲 ========== FIM GERAÇÃO QR CODE ==========');
      
      // O SDK da Stone espera apenas o base64 puro (sem prefixo "data:image/png;base64,")
      // Retorna apenas o base64 puro
      return base64String;
    } catch (e, stackTrace) {
      debugPrint('❌ ========== ERRO NA GERAÇÃO QR CODE ==========');
      debugPrint('❌ Erro: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      debugPrint('❌ ============================================');
      return null;
    }
  }
  
  /// Adiciona QR Code como texto (fallback quando imagem falha)
  void _adicionarQrCodeComoTexto(List<ItemPrintModel> items, String qrCodeTexto) {
    debugPrint('📝 Adicionando QR Code como texto (fallback)...');
    items.add(const ItemPrintModel(
      type: ItemPrintTypeEnum.text,
      data: '',
    ));
    items.add(const ItemPrintModel(
      type: ItemPrintTypeEnum.text,
      data: 'QR CODE (TEXTO):',
    ));
    
    // Quebra o QR Code em linhas de 32 caracteres
    final qrLinhas = _wrapText(qrCodeTexto, 32);
    for (final linha in qrLinhas) {
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: linha,
      ));
    }
    
    debugPrint('✅ QR Code adicionado como texto');
  }
  
  /// Imprime recibo do cliente (após pagamento aprovado)
  Future<void> printClientReceipt() async {
    try {
      debugPrint('🖨️ Imprimindo recibo do cliente...');
      final result = await StonePayments.printReceipt(TypeOwnerPrintEnum.client);
      debugPrint('✅ Recibo do cliente impresso: $result');
    } catch (e) {
      debugPrint('❌ Erro ao imprimir recibo do cliente: $e');
      rethrow;
    }
  }
  
  /// Imprime recibo do comerciante (após pagamento aprovado)
  Future<void> printMerchantReceipt() async {
    try {
      debugPrint('🖨️ Imprimindo recibo do comerciante...');
      final result = await StonePayments.printReceipt(TypeOwnerPrintEnum.merchant);
      debugPrint('✅ Recibo do comerciante impresso: $result');
    } catch (e) {
      debugPrint('❌ Erro ao imprimir recibo do comerciante: $e');
      rethrow;
    }
  }
}

