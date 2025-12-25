import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../../../core/adaptive_layout/adaptive_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/teclado_numerico_dialog.dart';
import '../../../../presentation/providers/services_provider.dart';
import '../../../../data/services/modules/restaurante/mesa_service.dart';
import '../../../../data/services/modules/restaurante/comanda_service.dart';
import '../../../../data/services/core/venda_service.dart';
import '../../../../data/models/modules/restaurante/mesa_list_item.dart';
import '../../../../data/models/modules/restaurante/comanda_list_item.dart';
import '../../../../data/models/modules/restaurante/mesa_filter.dart';
import '../../../../data/models/modules/restaurante/comanda_filter.dart';
import '../../../../data/models/modules/restaurante/configuracao_restaurante_dto.dart';
import 'package:google_fonts/google_fonts.dart';

/// Resultado da seleção de mesa e comanda
class SelecaoMesaComandaResult {
  final MesaListItemDto? mesa;
  final ComandaListItemDto? comanda;

  SelecaoMesaComandaResult({
    this.mesa,
    this.comanda,
  });

  bool get temSelecao => mesa != null || comanda != null;
}

/// Tela simples para selecionar mesa e/ou comanda
/// Mostra apenas ícones - ao clicar, abre entrada numérica
class SelecionarMesaComandaDialog extends StatefulWidget {
  final String? mesaIdPreSelecionada;
  final String? comandaIdPreSelecionada;
  final bool permiteVendaAvulsa;

  const SelecionarMesaComandaDialog({
    super.key,
    this.mesaIdPreSelecionada,
    this.comandaIdPreSelecionada,
    this.permiteVendaAvulsa = false,
  });

  @override
  State<SelecionarMesaComandaDialog> createState() => _SelecionarMesaComandaDialogState();

  static Future<SelecaoMesaComandaResult?> show(
    BuildContext context, {
    String? mesaIdPreSelecionada,
    String? comandaIdPreSelecionada,
    bool permiteVendaAvulsa = false,
  }) async {
    final adaptive = AdaptiveLayoutProvider.of(context);
    final isMobile = adaptive?.isMobile ?? true;
    
    if (isMobile) {
      return Navigator.of(context).push<SelecaoMesaComandaResult>(
        MaterialPageRoute(
          builder: (context) => AdaptiveLayout(
            child: SelecionarMesaComandaDialog(
              mesaIdPreSelecionada: mesaIdPreSelecionada,
              comandaIdPreSelecionada: comandaIdPreSelecionada,
              permiteVendaAvulsa: permiteVendaAvulsa,
            ),
          ),
          fullscreenDialog: true,
        ),
      );
    } else {
    return showDialog<SelecaoMesaComandaResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdaptiveLayout(
        child: SelecionarMesaComandaDialog(
          mesaIdPreSelecionada: mesaIdPreSelecionada,
          comandaIdPreSelecionada: comandaIdPreSelecionada,
          permiteVendaAvulsa: permiteVendaAvulsa,
        ),
      ),
    );
    }
  }
}

class _SelecionarMesaComandaDialogState extends State<SelecionarMesaComandaDialog> {
  MesaListItemDto? _mesaSelecionada;
  ComandaListItemDto? _comandaSelecionada;
  String? _mesaIdVinculadaComanda;
  String? _comandaNumeroPreSelecionada; // Apenas para exibição inicial, não define _comandaSelecionada
  bool _isLoadingInicial = false; // Controla o loading durante busca inicial

  MesaService get _mesaService {
    return Provider.of<ServicesProvider>(context, listen: false).mesaService;
  }

  ComandaService get _comandaService {
    return Provider.of<ServicesProvider>(context, listen: false).comandaService;
  }

  ServicesProvider get _servicesProvider {
    return Provider.of<ServicesProvider>(context, listen: false);
  }

  VendaService get _vendaService {
    return _servicesProvider.vendaService;
  }

  ConfiguracaoRestauranteDto? get _configuracaoRestaurante {
    return _servicesProvider.configuracaoRestaurante;
  }

  bool get _mostrarSelecaoComanda {
    if (_configuracaoRestaurante != null && _configuracaoRestaurante!.controlePorMesa) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    debugPrint('🔵 [SelecionarMesaComandaDialog] initState:');
    debugPrint('  - mesaIdPreSelecionada: ${widget.mesaIdPreSelecionada}');
    debugPrint('  - comandaIdPreSelecionada: ${widget.comandaIdPreSelecionada}');
    debugPrint('  - permiteVendaAvulsa: ${widget.permiteVendaAvulsa}');
    
    // Verifica se precisa fazer busca inicial
    final precisaBuscar = widget.mesaIdPreSelecionada != null || widget.comandaIdPreSelecionada != null;
    
    if (precisaBuscar) {
      _carregarDadosIniciais();
    }
  }
  
  /// Carrega dados iniciais com loading e bloqueio de interações
  Future<void> _carregarDadosIniciais() async {
    setState(() {
      _isLoadingInicial = true;
    });
    
    try {
      // Busca mesa e comanda em paralelo se necessário
      final futures = <Future>[];
      
      if (widget.mesaIdPreSelecionada != null) {
        futures.add(_buscarMesaPreSelecionada());
      }
      
      // IMPORTANTE: Não carrega comanda pré-selecionada automaticamente
      // A comanda só será selecionada se o usuário interagir explicitamente
      // Se comandaIdPreSelecionada for fornecido, apenas busca o número para exibição inicial
      if (widget.comandaIdPreSelecionada != null) {
        futures.add(_buscarNumeroComandaPreSelecionada());
      }
      
      // Aguarda todas as buscas terminarem
      await Future.wait(futures);
    } catch (e) {
      debugPrint('Erro ao carregar dados iniciais: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInicial = false;
        });
      }
    }
  }
  
  /// Busca apenas o número da comanda pré-selecionada para exibição inicial
  /// Não define _comandaSelecionada - isso só acontece se o usuário confirmar explicitamente
  Future<void> _buscarNumeroComandaPreSelecionada() async {
    try {
      final response = await _comandaService.getComandaById(widget.comandaIdPreSelecionada!);
      if (response.success && response.data != null && mounted) {
        setState(() {
          _comandaNumeroPreSelecionada = response.data!.numero;
          // NÃO define _comandaSelecionada - apenas armazena o número para exibição
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar número da comanda pré-selecionada: $e');
    }
  }

  Future<void> _buscarMesaPreSelecionada() async {
    try {
      final response = await _mesaService.getMesaById(widget.mesaIdPreSelecionada!);
      if (response.success && response.data != null && mounted) {
        setState(() {
          _mesaSelecionada = response.data;
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar mesa pré-selecionada: $e');
    }
  }

  Future<void> _buscarComandaPreSelecionada() async {
    try {
      final response = await _comandaService.getComandaById(widget.comandaIdPreSelecionada!);
      if (response.success && response.data != null) {
        setState(() {
          _comandaSelecionada = response.data;
        });
        
          try {
            final vendaResponse = await _vendaService.getVendaAbertaPorComanda(widget.comandaIdPreSelecionada!);
            if (vendaResponse.success && vendaResponse.data != null && vendaResponse.data!.mesaId != null) {
            _mesaIdVinculadaComanda = vendaResponse.data!.mesaId;
            
            if (widget.mesaIdPreSelecionada != null && widget.mesaIdPreSelecionada != vendaResponse.data!.mesaId) {
                setState(() {
                  _comandaSelecionada = null;
                  _mesaIdVinculadaComanda = null;
                });
                
                await AppDialog.showError(
                  context: context,
                  title: 'Comanda já vinculada',
                message: 'A comanda ${response.data!.numero} já está vinculada a outra mesa.',
              );
            } else if (widget.mesaIdPreSelecionada == null) {
              final mesaResponse = await _mesaService.getMesaById(vendaResponse.data!.mesaId!);
                  if (mesaResponse.success && mesaResponse.data != null) {
                    setState(() {
                      _mesaSelecionada = mesaResponse.data;
                    });
                }
              }
            }
          } catch (e) {
          debugPrint('⚠️ Erro ao buscar venda aberta: $e');
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar comanda pré-selecionada: $e');
    }
  }

  Future<void> _abrirEntradaMesa() async {
    final numero = await TecladoNumericoDialog.show(
      context,
      titulo: 'Digite o número da mesa',
      valorInicial: _mesaSelecionada?.numero,
      hint: 'Número da mesa',
      icon: Icons.table_restaurant,
      cor: AppTheme.primaryColor,
    );

    if (numero != null && numero.trim().isNotEmpty) {
      await _buscarMesa(numero.trim());
    }
  }

  Future<void> _abrirEntradaComanda() async {
    final numero = await TecladoNumericoDialog.show(
      context,
      titulo: 'Digite o número da comanda',
      valorInicial: _comandaSelecionada?.numero ?? _comandaNumeroPreSelecionada,
      hint: 'Número ou código da comanda',
      icon: Icons.receipt_long,
      cor: AppTheme.infoColor,
    );

    if (numero != null && numero.trim().isNotEmpty) {
      await _buscarComanda(numero.trim());
    }
  }

  Future<void> _buscarMesa(String numero) async {
    try {
      final response = await _mesaService.searchMesas(
        page: 1,
        pageSize: 100,
        filter: MesaFilterDto(
          searchTerm: numero,
          ativa: true,
        ),
      );

      if (response.success && response.data != null && response.data!.list.isNotEmpty) {
        final mesas = response.data!.list;
        
        // IMPORTANTE: Busca apenas correspondência EXATA
        // Não aceita correspondência parcial
        MesaListItemDto? mesaExata;
        try {
          mesaExata = mesas.firstWhere(
            (m) => m.numero.toLowerCase() == numero.toLowerCase(),
          );
        } catch (e) {
          // Não encontrou correspondência exata
          mesaExata = null;
        }
        
        // Se não encontrou correspondência exata, rejeita
        if (mesaExata == null) {
        setState(() {
            _mesaSelecionada = null;
          });
          await AppDialog.showError(
            context: context,
            title: 'Mesa não encontrada',
            message: 'Não foi possível encontrar a mesa "$numero". Verifique o número e tente novamente.',
          );
          return;
        }
        
        // Validação de comanda vinculada
        if (_comandaSelecionada != null && _mesaIdVinculadaComanda != null && mesaExata.id != _mesaIdVinculadaComanda) {
          // Limpa seleção de mesa se comanda está vinculada a outra mesa
          setState(() {
            _mesaSelecionada = null;
          });
          await AppDialog.showError(
            context: context,
            title: 'Comanda já vinculada',
            message: 'A comanda ${_comandaSelecionada!.numero} já está vinculada a outra mesa.',
          );
          return;
        }
        
        // Mesa encontrada e validada - seleciona
        setState(() {
          _mesaSelecionada = mesaExata;
        });
      } else {
        // Mesa não encontrada - limpa seleção e mostra erro
        setState(() {
          _mesaSelecionada = null;
        });
        await AppDialog.showError(
          context: context,
          title: 'Mesa não encontrada',
          message: 'Não foi possível encontrar a mesa "$numero". Verifique o número e tente novamente.',
        );
      }
    } catch (e) {
      // Erro na busca - limpa seleção e mostra erro
      setState(() {
        _mesaSelecionada = null;
      });
      await AppDialog.showError(
        context: context,
        title: 'Erro ao buscar mesa',
        message: 'Não foi possível buscar a mesa. Tente novamente.',
      );
      debugPrint('Erro ao buscar mesa: $e');
    }
  }

  Future<void> _buscarComanda(String numero) async {
    try {
      final response = await _comandaService.searchComandas(
        page: 1,
        pageSize: 100,
        filter: ComandaFilterDto(
          search: numero,
          ativa: true,
        ),
      );

      if (response.success && response.data != null && response.data!.list.isNotEmpty) {
        final comandas = response.data!.list;
        
        // IMPORTANTE: Busca apenas correspondência EXATA
        // Por número ou código de barras, mas deve ser exato
        ComandaListItemDto? comandaExata;
        try {
          comandaExata = comandas.firstWhere(
            (c) => c.numero.toLowerCase() == numero.toLowerCase() ||
                   (c.codigoBarras != null && c.codigoBarras!.toLowerCase() == numero.toLowerCase()),
          );
    } catch (e) {
          // Não encontrou correspondência exata
          comandaExata = null;
        }
        
        // Se não encontrou correspondência exata, rejeita
        if (comandaExata == null) {
      setState(() {
        _comandaSelecionada = null;
        _mesaIdVinculadaComanda = null;
      });
      await AppDialog.showError(
        context: context,
            title: 'Comanda não encontrada',
            message: 'Não foi possível encontrar a comanda "$numero". Verifique o número ou código e tente novamente.',
          );
          return;
    }
    
    setState(() {
          _comandaSelecionada = comandaExata;
          _mesaIdVinculadaComanda = null;
        });

        // Buscar venda aberta para preencher mesa automaticamente
        try {
          final vendaResponse = await _vendaService.getVendaAbertaPorComanda(comandaExata.id);
        if (vendaResponse.success && vendaResponse.data != null && vendaResponse.data!.mesaId != null) {
          final venda = vendaResponse.data!;
            _mesaIdVinculadaComanda = venda.mesaId;
          
            // Validação: se já tem mesa selecionada e é diferente da vinculada, limpa comanda
          if (_mesaSelecionada != null && _mesaSelecionada!.id != venda.mesaId) {
            setState(() {
              _comandaSelecionada = null;
              _mesaIdVinculadaComanda = null;
            });
            
            await AppDialog.showError(
              context: context,
              title: 'Comanda já vinculada',
                message: 'A comanda ${comandaExata.numero} já está vinculada à mesa ${venda.mesaNome}.',
            );
              return;
          }
          
            // Preenche mesa automaticamente se não tinha mesa selecionada
          final mesaResponse = await _mesaService.getMesaById(venda.mesaId!);
          if (mesaResponse.success && mesaResponse.data != null) {
            setState(() {
              _mesaSelecionada = mesaResponse.data;
            });
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar venda aberta: $e');
          }
        } else {
        // Comanda não encontrada - limpa seleção e mostra erro
        setState(() {
          _comandaSelecionada = null;
          _mesaIdVinculadaComanda = null;
        });
        await AppDialog.showError(
          context: context,
          title: 'Comanda não encontrada',
          message: 'Não foi possível encontrar a comanda "$numero". Verifique o número ou código e tente novamente.',
        );
        }
      } catch (e) {
      // Erro na busca - limpa seleção e mostra erro
      setState(() {
        _comandaSelecionada = null;
        _mesaIdVinculadaComanda = null;
      });
      await AppDialog.showError(
        context: context,
        title: 'Erro ao buscar comanda',
        message: 'Não foi possível buscar a comanda. Tente novamente.',
      );
      debugPrint('Erro ao buscar comanda: $e');
    }
  }

  void _removerMesa() {
    setState(() {
      _mesaSelecionada = null;
    });
  }

  void _removerComanda() {
    setState(() {
      _comandaSelecionada = null;
      _mesaIdVinculadaComanda = null;
    });
  }

  bool _podeConfirmar() {
    // Sempre permite confirmar - tudo é opcional
    // A diferença é apenas se mostra ou não a opção de comanda baseado na configuração
      return true;
  }

  void _confirmar() async {
    if (_comandaSelecionada != null && _mesaIdVinculadaComanda != null) {
      final mesaIdSelecionada = _mesaSelecionada?.id ?? widget.mesaIdPreSelecionada;
      if (mesaIdSelecionada != null && mesaIdSelecionada != _mesaIdVinculadaComanda) {
        await AppDialog.showError(
          context: context,
          title: 'Comanda já vinculada',
          message: 'A comanda ${_comandaSelecionada!.numero} já está vinculada a outra mesa.',
        );
        return;
      }
    }

    // Se há mesa pré-selecionada mas não foi carregada ainda, tenta carregar antes de retornar
    MesaListItemDto? mesaFinal = _mesaSelecionada;
    if (mesaFinal == null && widget.mesaIdPreSelecionada != null) {
      try {
        final response = await _mesaService.getMesaById(widget.mesaIdPreSelecionada!);
        if (response.success && response.data != null) {
          mesaFinal = response.data;
        }
      } catch (e) {
        debugPrint('Erro ao buscar mesa pré-selecionada no confirmar: $e');
      }
    }

    // Retorna o valor atual de _comandaSelecionada (pode ser null)
    // Se o usuário não selecionou ou removeu a comanda, será null
    // Se o usuário selecionou uma comanda, será a comanda selecionada
    ComandaListItemDto? comandaFinal = _comandaSelecionada;

    debugPrint('✅ [SelecionarMesaComandaDialog] Confirmando seleção:');
    debugPrint('  - Mesa final: ${mesaFinal?.id} (${mesaFinal?.numero})');
    debugPrint('  - Comanda final: ${comandaFinal?.id} (${comandaFinal?.numero ?? "null"})');
    debugPrint('  - Mesa pré-selecionada: ${widget.mesaIdPreSelecionada}');
    debugPrint('  - Comanda pré-selecionada: ${widget.comandaIdPreSelecionada}');
    debugPrint('  - _comandaSelecionada: ${_comandaSelecionada?.id} (${_comandaSelecionada?.numero ?? "null"})');

    Navigator.of(context).pop(
      SelecaoMesaComandaResult(
        mesa: mesaFinal,
        comanda: comandaFinal, // Será null se o usuário não selecionou ou removeu a comanda
      ),
    );
  }

  void _cancelar() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) return const SizedBox.shrink();

    final isMobile = adaptive.isMobile;

    if (isMobile) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textPrimary),
            onPressed: _cancelar,
          ),
          title: Text(
            'Novo Pedido',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: _buildConteudoMobile(adaptive),
        bottomNavigationBar: _buildBottomBarMobile(adaptive),
      );
    } else {
    return Dialog(
      backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
      child: Container(
          width: 500,
        decoration: BoxDecoration(
          color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Novo Pedido',
                      style: GoogleFonts.inter(
                          fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: _cancelar,
                  ),
                ],
              ),
            ),
              Flexible(child: _buildConteudo(adaptive)),
            Container(
                padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                    Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoadingInicial ? null : _cancelar,
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: (_isLoadingInicial || !_podeConfirmar()) ? null : _confirmar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Continuar',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    }
  }

  /// Conteúdo para mobile (sem botões, que ficam no rodapé)
  Widget _buildConteudoMobile(AdaptiveLayoutProvider adaptive) {
    // Mostra loading durante busca inicial
    if (_isLoadingInicial) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Carregando informações...',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mensagem informativa - sempre opcional
          Text(
            _mostrarSelecaoComanda 
              ? 'Selecione mesa e/ou comanda (opcional)'
              : 'Selecione uma mesa (opcional)',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Ícone Mesa
          _buildCardSelecao(
            adaptive,
            label: 'Mesa',
            selecionado: _mesaSelecionada,
            numero: _mesaSelecionada?.numero,
            icon: Icons.table_restaurant,
            cor: AppTheme.primaryColor,
            onTap: _isLoadingInicial ? null : _abrirEntradaMesa,
            onRemover: _isLoadingInicial ? null : _removerMesa,
          ),
          
          if (_mostrarSelecaoComanda) ...[
            const SizedBox(height: 24),
            _buildCardSelecao(
              adaptive,
              label: 'Comanda',
              selecionado: _comandaSelecionada,
              numero: _comandaSelecionada?.numero,
              icon: Icons.receipt_long,
              cor: AppTheme.infoColor,
              onTap: _isLoadingInicial ? null : _abrirEntradaComanda,
              onRemover: _isLoadingInicial ? null : _removerComanda,
            ),
          ],
          
          // Espaço extra no final para não ficar colado nos botões do rodapé
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Rodapé fixo com botões para mobile
  Widget _buildBottomBarMobile(AdaptiveLayoutProvider adaptive) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoadingInicial ? null : _cancelar,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: (_isLoadingInicial || !_podeConfirmar()) ? null : _confirmar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Continuar',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Conteúdo para desktop (com botões dentro)
  Widget _buildConteudo(AdaptiveLayoutProvider adaptive) {
    // Mostra loading durante busca inicial
    if (_isLoadingInicial) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Carregando informações...',
              style: GoogleFonts.inter(
                fontSize: 18,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mensagem informativa - sempre opcional
          Text(
            _mostrarSelecaoComanda 
              ? 'Selecione mesa e/ou comanda (opcional)'
              : 'Selecione uma mesa (opcional)',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          
          // Ícone Mesa
          _buildCardSelecao(
            adaptive,
            label: 'Mesa',
            selecionado: _mesaSelecionada,
            numero: _mesaSelecionada?.numero,
            icon: Icons.table_restaurant,
            cor: AppTheme.primaryColor,
            onTap: _isLoadingInicial ? null : _abrirEntradaMesa,
            onRemover: _isLoadingInicial ? null : _removerMesa,
          ),
          
          if (_mostrarSelecaoComanda) ...[
            const SizedBox(height: 32),
            _buildCardSelecao(
              adaptive,
              label: 'Comanda',
              selecionado: _comandaSelecionada,
              numero: _comandaSelecionada?.numero,
              icon: Icons.receipt_long,
              cor: AppTheme.infoColor,
              onTap: _isLoadingInicial ? null : _abrirEntradaComanda,
              onRemover: _isLoadingInicial ? null : _removerComanda,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardSelecao(
    AdaptiveLayoutProvider adaptive, {
    required String label,
    required dynamic selecionado,
    required String? numero,
    required IconData icon,
    required Color cor,
    required VoidCallback? onTap,
    required VoidCallback? onRemover,
  }) {
    final isSelecionado = selecionado != null;
    final isDisabled = onTap == null || onRemover == null;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 20 : 24),
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: Container(
            padding: EdgeInsets.all(adaptive.isMobile ? 32 : 28),
        decoration: BoxDecoration(
              color: isSelecionado ? cor.withOpacity(0.1) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(adaptive.isMobile ? 20 : 24),
          border: Border.all(
                color: isSelecionado ? cor : Colors.grey.shade300,
                width: isSelecionado ? 2 : 1,
          ),
        ),
        child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
          children: [
                Icon(
                  icon,
                  size: adaptive.isMobile ? 64 : 56,
                  color: isSelecionado ? cor : Colors.grey.shade400,
                ),
                SizedBox(width: adaptive.isMobile ? 24 : 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                        label,
                    style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 18 : 16,
                      fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                    ),
                  ),
                      SizedBox(height: 6),
                    Text(
                        isSelecionado ? numero! : 'Toque para selecionar',
                      style: GoogleFonts.inter(
                          fontSize: adaptive.isMobile ? 24 : 22,
                          fontWeight: FontWeight.w700,
                          color: isSelecionado ? cor : Colors.grey.shade400,
                      ),
                    ),
                ],
              ),
            ),
                if (isSelecionado)
            IconButton(
                    icon: Icon(Icons.close, color: cor),
                    onPressed: isDisabled ? null : onRemover,
                    iconSize: adaptive.isMobile ? 24 : 22,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}
