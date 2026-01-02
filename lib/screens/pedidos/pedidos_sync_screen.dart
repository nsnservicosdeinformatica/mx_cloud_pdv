import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../data/models/local/pedido_local.dart';
import '../../data/models/local/item_pedido_local.dart';
import '../../data/models/local/sync_status_pedido.dart';
import '../../data/models/local/produto_local.dart';
import '../../data/models/local/produto_variacao_local.dart';
import '../../data/repositories/pedido_local_repository.dart';
import '../../data/repositories/produto_local_repository.dart';
import '../../presentation/providers/services_provider.dart';

class PedidosSyncScreen extends StatefulWidget {
  const PedidosSyncScreen({super.key});

  @override
  State<PedidosSyncScreen> createState() => _PedidosSyncScreenState();
}

class _PedidosSyncScreenState extends State<PedidosSyncScreen> {
  final _repo = PedidoLocalRepository();
  final _produtoRepo = ProdutoLocalRepository();
  Future<void>? _initFuture;
  final Set<String> _expandedPedidos = {}; // IDs dos pedidos expandidos
  bool _sincronizando = false;
  String? _mensagemProgresso;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeRepositories();
  }

  Future<void> _initializeRepositories() async {
    await _repo.getAll(); // garante abertura da box de pedidos
    await _produtoRepo.init(); // garante inicialização do repositório de produtos
  }

  void _toggleExpanded(String pedidoId) {
    setState(() {
      if (_expandedPedidos.contains(pedidoId)) {
        _expandedPedidos.remove(pedidoId);
      } else {
        _expandedPedidos.add(pedidoId);
      }
    });
  }

  Color _statusColor(SyncStatusPedido status) {
    switch (status) {
      case SyncStatusPedido.pendente:
        return Colors.orange.shade600;
      case SyncStatusPedido.sincronizando:
        return Colors.blue.shade600;
      case SyncStatusPedido.sincronizado:
        return Colors.green.shade700;
      case SyncStatusPedido.erro:
        return Colors.red.shade600;
    }
  }

  String _statusLabel(SyncStatusPedido status) {
    switch (status) {
      case SyncStatusPedido.pendente:
        return 'Pendente';
      case SyncStatusPedido.sincronizando:
        return 'Sincronizando';
      case SyncStatusPedido.sincronizado:
        return 'Sincronizado';
      case SyncStatusPedido.erro:
        return 'Erro';
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppHeader(
        title: 'Sincronização de Pedidos',
        subtitle: 'Pedidos pendentes de sincronização',
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Column(
        children: [
          // Faixa com botão de sincronizar todos
          _buildSyncBar(),
          // Conteúdo principal
          Expanded(
            child: FutureBuilder(
              future: _initFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                        const SizedBox(height: 16),
                        Text(
                          'Erro ao carregar pedidos locais',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ValueListenableBuilder(
                  valueListenable: Hive.box<PedidoLocal>(PedidoLocalRepository.boxName).listenable(),
                  builder: (context, Box<PedidoLocal> box, _) {
                    final pedidos = box.values
                        .where((p) => p.syncStatus != SyncStatusPedido.sincronizado)
                        .toList()
                      ..sort((a, b) => (b.dataAtualizacao ?? b.dataCriacao).compareTo(a.dataAtualizacao ?? a.dataCriacao));

                    if (pedidos.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhum pedido pendente',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Todos os pedidos foram sincronizados',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: pedidos.length,
                      itemBuilder: (context, index) {
                        final pedido = pedidos[index];
                        final isExpanded = _expandedPedidos.contains(pedido.id);
                        return _buildPedidoCard(pedido, isExpanded, context);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Consumer<ServicesProvider>(
        builder: (context, services, _) {
          if (_sincronizando) {
            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sincronizando pedidos...',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (_mensagemProgresso != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _mensagemProgresso!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.sync,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sincronizar Todos',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enviar todos os pedidos pendentes para o servidor',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => _sincronizarTodos(services),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sync,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sincronizar',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _sincronizarTodos(ServicesProvider services) async {
    setState(() {
      _sincronizando = true;
      _mensagemProgresso = 'Iniciando...';
    });

    try {
      final result = await services.syncService.sincronizarPedidos(
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _mensagemProgresso = progress.mensagem;
            });
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.sincronizados} pedido(s) sincronizado(s)${result.erros > 0 ? ', ${result.erros} com erro' : ''}',
            ),
            backgroundColor: result.erros > 0 ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao sincronizar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sincronizando = false;
          _mensagemProgresso = null;
        });
      }
    }
  }

  Future<void> _sincronizarPedidoIndividual(PedidoLocal pedido, ServicesProvider services) async {
    if (pedido.syncStatus == SyncStatusPedido.sincronizando) {
      return; // Já está sincronizando
    }

    try {
      final sucesso = await services.syncService.sincronizarPedidoIndividual(pedido.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sucesso
                  ? 'Pedido sincronizado com sucesso'
                  : 'Erro ao sincronizar pedido',
            ),
            backgroundColor: sucesso ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao sincronizar pedido: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmarExclusao(PedidoLocal pedido) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmarExclusaoDialog(
        total: pedido.total,
        quantidadeItens: pedido.quantidadeTotal,
      ),
    );

    if (confirmar == true) {
      await _excluirPedido(pedido);
    }
  }

  Future<void> _excluirPedido(PedidoLocal pedido) async {
    try {
      await _repo.delete(pedido.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Pedido excluído com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir pedido: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPedidoCard(PedidoLocal pedido, bool isExpanded, BuildContext context) {
    final status = pedido.syncStatus;
    final date = pedido.dataAtualizacao ?? pedido.dataCriacao;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _statusColor(status).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _toggleExpanded(pedido.id),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header do card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _statusColor(status).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _statusColor(status),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _statusLabel(status),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: _statusColor(status),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Botão de excluir (apenas para pedidos não sincronizados e não sincronizando)
                      if (pedido.syncStatus != SyncStatusPedido.sincronizado &&
                          pedido.syncStatus != SyncStatusPedido.sincronizando)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: Colors.red.shade600,
                          onPressed: () => _confirmarExclusao(pedido),
                          tooltip: 'Excluir pedido',
                        ),
                      // Botão de sincronizar individual (se pendente ou erro)
                      if (pedido.syncStatus == SyncStatusPedido.pendente ||
                          pedido.syncStatus == SyncStatusPedido.erro)
                        Consumer<ServicesProvider>(
                          builder: (context, services, _) {
                            return IconButton(
                              icon: pedido.syncStatus == SyncStatusPedido.sincronizando
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.sync, size: 20),
                              color: pedido.syncStatus == SyncStatusPedido.erro
                                  ? Colors.red
                                  : AppTheme.primaryColor,
                              onPressed: pedido.syncStatus == SyncStatusPedido.sincronizando
                                  ? null
                                  : () => _sincronizarPedidoIndividual(pedido, services),
                              tooltip: 'Sincronizar este pedido',
                            );
                          },
                        ),
                      // Ícone de expandir
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Informações principais
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total: R\$ ${pedido.total.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${pedido.quantidadeTotal} ${pedido.quantidadeTotal == 1 ? 'item' : 'itens'}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (pedido.mesaId != null || pedido.comandaId != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (pedido.mesaId != null)
                                Text(
                                  'Mesa: ${pedido.mesaId}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              if (pedido.comandaId != null) ...[
                                if (pedido.mesaId != null) const SizedBox(height: 2),
                                Text(
                                  'Comanda: ${pedido.comandaId}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Criado: ${_formatDate(pedido.dataCriacao)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (pedido.lastSyncError != null && pedido.lastSyncError!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pedido.lastSyncError!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Detalhes expandidos
            if (isExpanded) ...[
              Divider(height: 1, color: Colors.grey.shade200),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Itens do Pedido',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...pedido.itens.map((item) => _buildItemCard(item)),
                    if (pedido.observacoesGeral != null && pedido.observacoesGeral!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.note, size: 16, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Observações Gerais',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    pedido.observacoesGeral!,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(ItemPedidoLocal item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quantidade badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.quantidade}x',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome do produto
                    Text(
                      item.produtoNome,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    // Variação (se houver)
                    if (item.produtoVariacaoNome != null && item.produtoVariacaoNome!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Variação: ${item.produtoVariacaoNome}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Preço total do item
              Text(
                'R\$ ${item.precoTotal.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          // Preço unitário
          Padding(
            padding: const EdgeInsets.only(left: 52, top: 4),
            child: Text(
              'R\$ ${item.precoUnitario.toStringAsFixed(2)} cada',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          // Atributos selecionados
          if (item.valoresAtributosSelecionados != null && item.valoresAtributosSelecionados!.isNotEmpty) ...[
            const SizedBox(height: 8),
            FutureBuilder<ProdutoLocal?>(
              future: Future.value(_produtoRepo.buscarPorId(item.produtoId)),
              builder: (context, produtoSnapshot) {
                List<Map<String, dynamic>> atributosSelecionados = [];
                
                if (produtoSnapshot.hasData && produtoSnapshot.data != null) {
                  final produto = produtoSnapshot.data!;
                  
                  for (var entry in item.valoresAtributosSelecionados!.entries) {
                    final atributoId = entry.key;
                    final valorIds = entry.value;
                    
                    // Buscar o atributo no produto
                    try {
                      final atributo = produto.atributos.firstWhere((a) => a.id == atributoId);
                      final nomesValores = valorIds.map((valorId) {
                        try {
                          final valor = atributo.valores.firstWhere((v) => v.id == valorId);
                          return valor.nome;
                        } catch (e) {
                          return null;
                        }
                      }).where((nome) => nome != null).cast<String>().toList();
                      
                      if (nomesValores.isNotEmpty) {
                        List<double>? proporcoes;
                        if (item.proporcoesAtributos != null) {
                          proporcoes = valorIds
                              .map((valorId) => item.proporcoesAtributos![valorId])
                              .where((p) => p != null)
                              .cast<double>()
                              .toList();
                          // Se ficou vazio após filtrar, definir como null
                          if (proporcoes.isEmpty) {
                            proporcoes = null;
                          }
                        }
                        
                        atributosSelecionados.add({
                          'nomeAtributo': atributo.nome,
                          'nomesValores': nomesValores,
                          'proporcoes': proporcoes,
                        });
                      }
                    } catch (e) {
                      // Atributo não encontrado
                    }
                  }
                }
                
                if (atributosSelecionados.isEmpty) {
                  return const SizedBox.shrink();
                }
                
                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: atributosSelecionados.map((atributoInfo) {
                    final nomeAtributo = atributoInfo['nomeAtributo'] as String;
                    final nomesValores = atributoInfo['nomesValores'] as List<String>;
                    final proporcoes = atributoInfo['proporcoes'] as List<double>?;
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$nomeAtributo: ',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              proporcoes != null && proporcoes.isNotEmpty
                                  ? nomesValores.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final nome = entry.value;
                                      final proporcao = proporcoes.length > index ? proporcoes[index] : null;
                                      return proporcao != null && proporcao != 1.0
                                          ? '$nome (${(proporcao * 100).toStringAsFixed(0)}%)'
                                          : nome;
                                    }).join(', ')
                                  : nomesValores.join(', '),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
          // Componentes removidos
          if (item.componentesRemovidos.isNotEmpty) ...[
            const SizedBox(height: 8),
            FutureBuilder<ProdutoLocal?>(
              future: Future.value(_produtoRepo.buscarPorId(item.produtoId)),
              builder: (context, produtoSnapshot) {
                List<String> nomesComponentesRemovidos = [];
                
                if (produtoSnapshot.hasData && produtoSnapshot.data != null) {
                  final produto = produtoSnapshot.data!;
                  ProdutoVariacaoLocal? variacao;
                  
                  // Buscar variação se houver
                  if (item.produtoVariacaoId != null && produto.variacoes.isNotEmpty) {
                    try {
                      variacao = produto.variacoes.firstWhere(
                        (v) => v.id == item.produtoVariacaoId,
                      );
                    } catch (e) {
                      // Variação não encontrada, usar composição do produto
                    }
                  }
                  
                  // Usar composição da variação ou do produto
                  final composicao = variacao != null && variacao.composicao.isNotEmpty
                      ? variacao.composicao
                      : produto.composicao;
                  
                  // Mapear IDs para nomes
                  nomesComponentesRemovidos = composicao
                      .where((c) => item.componentesRemovidos.contains(c.componenteId))
                      .map((c) => c.componenteNome)
                      .toList();
                }
                
                // Se não encontrou os nomes, mostrar os IDs
                if (nomesComponentesRemovidos.isEmpty && item.componentesRemovidos.isNotEmpty) {
                  nomesComponentesRemovidos = item.componentesRemovidos.toList();
                }
                
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.remove_circle_outline, size: 14, color: Colors.orange.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Removido${nomesComponentesRemovidos.length == 1 ? '' : 's'}:',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ...nomesComponentesRemovidos.map((nome) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade700,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            nome,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors.orange.shade900,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          // Observações do item
          if (item.observacoes != null && item.observacoes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, size: 14, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.observacoes!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Diálogo para confirmar exclusão de pedido
class _ConfirmarExclusaoDialog extends StatelessWidget {
  final double total;
  final int quantidadeItens;

  const _ConfirmarExclusaoDialog({
    required this.total,
    required this.quantidadeItens,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone de alerta
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline,
                color: Colors.red.shade600,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            
            // Título
            Text(
              'Excluir Pedido?',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Informações do pedido
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'R\$ ${total.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$quantidadeItens ${quantidadeItens == 1 ? 'item' : 'itens'}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Mensagem
            Text(
              'Esta ação não pode ser desfeita. O pedido será permanentemente excluído.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Botões
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Excluir',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
