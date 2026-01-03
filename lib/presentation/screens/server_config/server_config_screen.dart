import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/adaptive_layout/adaptive_layout.dart';
import '../../../core/config/connection_config_service.dart';
import '../../../core/config/app_connection_config.dart';
import '../../../core/config/environment_detector.dart';
import '../../../core/network/health_check_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart' as main_app;
import '../../widgets/common/h4nd_logo.dart';

/// Tela de configuração do servidor
/// Aparece quando não há configuração salva ou quando o usuário quer trocar servidor
class ServerConfigScreen extends StatefulWidget {
  final bool allowBack;
  
  const ServerConfigScreen({
    super.key,
    this.allowBack = false,
  });

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  bool _isValidating = false;
  bool _isValid = false;
  String? _errorMessage;
  TipoConexao? _tipoConexaoSelecionado;
  
  late AnimationController _logoGlowController;
  late Animation<double> _glowAnimation; // null = escolhendo, local/remoto = configurando

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
    
    // Animação de brilho sutil que passa pelo container
    _logoGlowController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
    
    _glowAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(
        parent: _logoGlowController,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _loadCurrentConfig() {
    // Carrega configuração atual
    final config = ConnectionConfigService.getCurrentConfig();
    if (config != null) {
    setState(() {
        _tipoConexaoSelecionado = config.tipoConexao;
        if (config.isLocal) {
          _serverUrlController.text = config.serverUrl;
        }
      });
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _logoGlowController.dispose();
    super.dispose();
  }

  /// Valida e salva configuração
  Future<void> _validarESalvar() async {
    // Se escolheu servidor local, valida formulário
    if (_tipoConexaoSelecionado == TipoConexao.local) {
    if (!_formKey.currentState!.validate()) {
      return;
      }
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
      _isValid = false;
    });

    String serverUrl;
    bool saved = false;
    
    if (_tipoConexaoSelecionado == TipoConexao.remoto) {
      // Servidor Online (H4ND)
      serverUrl = EnvironmentDetector.getServerUrl();
    // Validar healthcheck
      final healthResult = await HealthCheckService.checkHealth(serverUrl);
    
    setState(() {
      _isValidating = false;
      _isValid = healthResult.success;
      _errorMessage = healthResult.message;
    });

    if (healthResult.success) {
        saved = await ConnectionConfigService.configurarServidorOnline();
      }
    } else {
      // Servidor Local
      serverUrl = _serverUrlController.text.trim();
      // Validar healthcheck
      final healthResult = await HealthCheckService.checkHealth(serverUrl);
      
      setState(() {
        _isValidating = false;
        _isValid = healthResult.success;
        _errorMessage = healthResult.message;
      });

      if (healthResult.success) {
        saved = await ConnectionConfigService.configurarServidorLocal(serverUrl);
      }
    }

    if (saved && mounted) {
      // Reiniciar app para carregar providers
      if (mounted) {
        await main_app.initializeApp();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: widget.allowBack
          ? AppBar(
              title: const Text('Configuração do Servidor'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryDark,
              AppTheme.primaryColor.withOpacity(0.9),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: adaptive.isMobile ? 16 : 48,
                vertical: adaptive.isMobile ? 16 : 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // Logo H4ND com destaque e animação sutil (painel branco ocupando toda largura, logo centralizada)
                    AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, child) {
                        return Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: adaptive.isMobile ? 16 : 20,
                            vertical: adaptive.isMobile ? 16 : 20,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: Colors.white.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Logo centralizada (sem animação de tamanho)
                              Center(
                                child: H4NDLogo(
                                  fontSize: adaptive.isMobile ? 40 : 48,
                                  showPdv: true,
                                  blueColor: const Color(0xFF1E3A8A),
                                  greenColor: const Color(0xFF10B981),
                                ),
                              ),
                              // Brilho sutil que passa pelo container inteiro (shimmer effect)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: LinearGradient(
                                        begin: Alignment(
                                          _glowAnimation.value - 1.2,
                                          0,
                                        ),
                                        end: Alignment(
                                          _glowAnimation.value,
                                          0,
                                        ),
                                        colors: [
                                          Colors.transparent,
                                          Colors.white.withOpacity(0.15),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    SizedBox(height: adaptive.isMobile ? 24 : 32),
                      
                      // Título
                      Text(
                        'Configuração do Servidor',
                        style: GoogleFonts.inter(
                        fontSize: adaptive.isMobile ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    SizedBox(height: adaptive.isMobile ? 8 : 12),
                      Text(
                      'Escolha como deseja conectar ao sistema',
                        style: GoogleFonts.inter(
                        fontSize: adaptive.isMobile ? 14 : 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    SizedBox(height: adaptive.isMobile ? 24 : 32),
                      
                    // Card principal
                      Container(
                      padding: EdgeInsets.all(adaptive.isMobile ? 16 : 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Opções de tipo de conexão
                            _buildTipoConexaoOptions(adaptive),
                            
                            const SizedBox(height: 16),
                            
                            // Campo de URL (só aparece se escolher Local)
                            if (_tipoConexaoSelecionado == TipoConexao.local)
                            TextFormField(
                              controller: _serverUrlController,
                              decoration: InputDecoration(
                                  labelText: 'Endereço do Servidor Local',
                                hintText: 'Ex: http://192.168.1.100:5101',
                                prefixIcon: const Icon(Icons.link),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.done,
                              validator: (value) {
                                  if (_tipoConexaoSelecionado == TipoConexao.local) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Digite o endereço do servidor';
                                }
                                final url = value.trim();
                                if (!url.contains('://') && !url.contains('.')) {
                                  return 'Digite um endereço válido';
                                    }
                                }
                                return null;
                              },
                            ),
                            
                            // Status de validação
                            if (_isValidating) ...[
                              SizedBox(height: adaptive.isMobile ? 12 : 16),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: adaptive.isMobile ? 12 : 16,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ] else if (_isValid) ...[
                              SizedBox(height: adaptive.isMobile ? 12 : 16),
                              Container(
                                padding: EdgeInsets.all(adaptive.isMobile ? 10 : 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.successColor,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: const Color(0xFF10B981),
                                      size: adaptive.isMobile ? 18 : 20,
                                    ),
                                    SizedBox(width: adaptive.isMobile ? 6 : 8),
                                    Expanded(
                                      child: Text(
                                        'Servidor acessível e funcionando!',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF10B981),
                                          fontWeight: FontWeight.w600,
                                          fontSize: adaptive.isMobile ? 13 : 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (_errorMessage != null) ...[
                              SizedBox(height: adaptive.isMobile ? 12 : 16),
                              Container(
                                padding: EdgeInsets.all(adaptive.isMobile ? 10 : 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.errorColor,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: AppTheme.errorColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: GoogleFonts.inter(
                                          color: AppTheme.errorColor,
                                            fontSize: adaptive.isMobile ? 12 : 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            
                            const SizedBox(height: 16),
                            
                            // Botão de confirmar
                            if (_tipoConexaoSelecionado != null)
                            ElevatedButton(
                                onPressed: _isValidating ? null : _validarESalvar,
                              style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    vertical: adaptive.isMobile ? 14 : 16,
                                  ),
                                  backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _isValidating
                                    ? 'Validando...'
                                      : 'Confirmar',
                                style: GoogleFonts.inter(
                                    fontSize: adaptive.isMobile ? 15 : 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        ),
                      ),
                    ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Constrói as opções de tipo de conexão
  Widget _buildTipoConexaoOptions(AdaptiveLayoutProvider adaptive) {
    final isProd = EnvironmentDetector.isProduction;
    final isMobile = adaptive.isMobile;
    
    return Column(
      children: [
        // Opção: Servidor Online (H4ND)
        Card(
          margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
          elevation: _tipoConexaoSelecionado == TipoConexao.remoto ? 4 : 1,
          color: Colors.white,
          child: InkWell(
            onTap: _isValidating
                ? null
                : () {
                    setState(() {
                      _tipoConexaoSelecionado = TipoConexao.remoto;
                      _errorMessage = null;
                      _isValid = false;
                    });
                  },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                gradient: _tipoConexaoSelecionado == TipoConexao.remoto
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.15),
                          AppTheme.primaryColor.withOpacity(0.05),
                        ],
                      )
                    : null,
                border: Border.all(
                  color: _tipoConexaoSelecionado == TipoConexao.remoto
                      ? AppTheme.primaryColor
                      : Colors.grey[300]!,
                  width: _tipoConexaoSelecionado == TipoConexao.remoto ? 2.5 : 1,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isMobile ? 10 : 12),
                        decoration: BoxDecoration(
                          gradient: _tipoConexaoSelecionado == TipoConexao.remoto
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.primaryColor,
                                    AppTheme.primaryColor.withOpacity(0.8),
                                  ],
                                )
                              : null,
                          color: _tipoConexaoSelecionado == TipoConexao.remoto
                              ? null
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _tipoConexaoSelecionado == TipoConexao.remoto
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          Icons.cloud,
                          size: isMobile ? 28 : 32,
                          color: _tipoConexaoSelecionado == TipoConexao.remoto
                              ? Colors.white
                              : Colors.grey[600],
                        ),
                      ),
                      SizedBox(width: isMobile ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Servidor Online (H4ND)',
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 17 : 19,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Conecta ao servidor na nuvem',
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 13 : 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_tipoConexaoSelecionado == TipoConexao.remoto)
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryColor,
                          size: isMobile ? 24 : 28,
                        ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: isMobile ? 16 : 18,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Acesso automático ao servidor H4ND',
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 12 : 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Destaque se for homologação
                  if (!isProd) ...[
                    SizedBox(height: isMobile ? 10 : 12),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 12,
                        vertical: isMobile ? 8 : 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: isMobile ? 18 : 20,
                            color: Colors.orange[700],
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'AMBIENTE DE HOMOLOGAÇÃO',
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 11 : 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
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
          ),
        ),
        
        // Opção: Servidor Local
        Card(
          elevation: _tipoConexaoSelecionado == TipoConexao.local ? 4 : 1,
          color: Colors.white,
          child: InkWell(
            onTap: _isValidating
                ? null
                : () {
                    setState(() {
                      _tipoConexaoSelecionado = TipoConexao.local;
                      _errorMessage = null;
                      _isValid = false;
                    });
                  },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                gradient: _tipoConexaoSelecionado == TipoConexao.local
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.15),
                          AppTheme.primaryColor.withOpacity(0.05),
                        ],
                      )
                    : null,
                border: Border.all(
                  color: _tipoConexaoSelecionado == TipoConexao.local
                      ? AppTheme.primaryColor
                      : Colors.grey[300]!,
                  width: _tipoConexaoSelecionado == TipoConexao.local ? 2.5 : 1,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isMobile ? 10 : 12),
                        decoration: BoxDecoration(
                          gradient: _tipoConexaoSelecionado == TipoConexao.local
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.primaryColor,
                                    AppTheme.primaryColor.withOpacity(0.8),
                                  ],
                                )
                              : null,
                          color: _tipoConexaoSelecionado == TipoConexao.local
                              ? null
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _tipoConexaoSelecionado == TipoConexao.local
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          Icons.dns,
                          size: isMobile ? 28 : 32,
                          color: _tipoConexaoSelecionado == TipoConexao.local
                              ? Colors.white
                              : Colors.grey[600],
                        ),
                      ),
                      SizedBox(width: isMobile ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Servidor Local',
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 17 : 19,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Conecta ao servidor na rede local',
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 13 : 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_tipoConexaoSelecionado == TipoConexao.local)
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryColor,
                          size: isMobile ? 24 : 28,
                        ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: isMobile ? 16 : 18,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Ideal para ambientes com API local',
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 12 : 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
