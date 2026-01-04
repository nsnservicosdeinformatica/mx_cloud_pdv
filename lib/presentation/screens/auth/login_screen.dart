import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/adaptive_layout/adaptive_layout.dart';
import '../../../core/config/connection_config_service.dart';
import '../../widgets/common/h4nd_logo.dart';
import '../../widgets/common/home_navigation.dart';
import '../server_config/server_config_screen.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tela de login
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  
  // Animações da logo
  late AnimationController _logoController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  
  // Animações de fundo
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();
    
    // Configurar animações da logo
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    // Escala suave de 0.5 para 1.0
    _logoScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack,
      ),
    );
    
    // Opacidade de 0 para 1
    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeIn,
      ),
    );
    
    // Animação de fundo (gradiente animado)
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);
    
    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _backgroundController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Iniciar animações
    _logoController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _backgroundController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (success && mounted) {
      // Navega para a home usando MaterialPageRoute
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const AdaptiveLayout(
            child: HomeNavigation(),
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.error ?? 'Erro ao realizar login',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
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
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
                  Color.lerp(
                    const Color(0xFF1E3A8A),
                    const Color(0xFF1E40AF),
                    _backgroundAnimation.value,
                  )!,
                  Color.lerp(
                    const Color(0xFF2563EB),
                    const Color(0xFF3B82F6),
                    _backgroundAnimation.value,
                  )!,
                  Color.lerp(
                    const Color(0xFF1E3A8A).withOpacity(0.9),
                    const Color(0xFF1E40AF).withOpacity(0.9),
                    _backgroundAnimation.value,
                  )!,
            ],
                stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
            child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: adaptive.isMobile ? 24 : 48,
                    vertical: 24,
                  ),
              child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                          // Espaço no topo para o indicador de servidor no mobile
                          if (adaptive.isMobile) const SizedBox(height: 50),
                          // Logo H4ND animada (ocupando toda largura)
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoScaleAnimation.value,
                            child: Opacity(
                              opacity: _logoOpacityAnimation.value,
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  horizontal: adaptive.isMobile ? 24 : 32,
                                  vertical: adaptive.isMobile ? 16 : 24,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: H4NDLogo(
                                    fontSize: adaptive.isMobile ? 48 : 56,
                                    showPdv: true,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: adaptive.isMobile ? 20 : 24),

                      // Card de login com efeito de vidro
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                              spreadRadius: 5,
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Título do card
                              Text(
                                'Bem-vindo!',
                                style: GoogleFonts.inter(
                                  fontSize: adaptive.isMobile ? 26 : 28,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E3A8A),
                                  letterSpacing: -0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Informe suas credenciais',
                                style: GoogleFonts.inter(
                                  fontSize: adaptive.isMobile ? 14 : 15,
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),
                              
                              // Divisor interno
                              Container(
                                height: 1,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.grey[300]!,
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Email
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Digite seu email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Email inválido';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Senha
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Senha',
                                  prefixIcon: const Icon(Icons.lock_outlined),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Digite sua senha';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Lembrar-me
                              Row(
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    onChanged: (value) {
                                      setState(() {
                                        _rememberMe = value ?? false;
                                      });
                                    },
                                  ),
                                  Text(
                                    'Lembrar-me',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Botão de login
                              Consumer<AuthProvider>(
                                builder: (context, authProvider, _) {
                                  return ElevatedButton(
                                    onPressed: authProvider.isLoading
                                        ? null
                                        : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      backgroundColor: const Color(0xFF1E3A8A),
                                      foregroundColor: Colors.white,
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: authProvider.isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            'Acessar',
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  );
                                },
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
                  // Indicador de servidor (por último no Stack para ficar por cima de tudo)
                  // No mobile, coloca no topo
                  // No desktop, fica no canto superior direito
                  Positioned(
                    top: adaptive.isMobile ? 8 : 16,
                    right: adaptive.isMobile ? 8 : 16,
                    child: _buildServerIndicator(context, adaptive),
                  ),
                ],
              ),
      ),
    );
        },
      ),
    );
  }

  /// Widget sutil para indicar e trocar de servidor
  Widget _buildServerIndicator(BuildContext context, AdaptiveLayoutProvider adaptive) {
    final config = ConnectionConfigService.getCurrentConfig();
    
    if (config == null) {
      return const SizedBox.shrink();
    }

    // Texto a ser exibido
    final serverText = config.isRemoto 
        ? 'H4ND Cloud'
        : config.serverUrl.replaceFirst(RegExp(r'^https?://'), ''); // Remove http:// ou https://

    return Material(
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicador do servidor atual
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: adaptive.isMobile ? 12 : 16,
              vertical: adaptive.isMobile ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  config.isRemoto ? Icons.cloud : Icons.dns,
                  size: adaptive.isMobile ? 16 : 18,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    serverText,
                    style: GoogleFonts.inter(
                      fontSize: adaptive.isMobile ? 11 : 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Botão para sair/trocar servidor
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _sairDoServidor(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: EdgeInsets.all(adaptive.isMobile ? 8 : 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.logout,
                  size: adaptive.isMobile ? 16 : 18,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Mostra dialog de confirmação e navega para configuração de servidor
  Future<void> _sairDoServidor(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.warningColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Alterar Servidor',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'A configuração do servidor será alterada e você precisará reconfigurar o servidor.\n\n'
          'Deseja continuar?',
          style: GoogleFonts.inter(
            fontSize: 15,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Continuar',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // Limpar configuração do servidor
      await ConnectionConfigService.clearConfig();
      
      // Resetar navegação completamente e ir para tela de configuração como root
      // allowBack: true para poder voltar para login após configurar
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const AdaptiveLayout(
              child: ServerConfigScreen(allowBack: true),
            ),
          ),
          (route) => false, // Remove todas as rotas anteriores
        );
      }
    }
  }
  
}



