import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../core/config/connection_config_service.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/widgets/common/h4nd_logo.dart';
import '../../presentation/widgets/common/home_navigation.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/server_config/server_config_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;

  @override
  void initState() {
    super.initState();

    // Logo animations
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

    // Start animation
    _logoController.forward();

    // Verifica autenticação e navega após animação
    Future.delayed(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      
      // Verificar se o servidor está configurado
      if (!ConnectionConfigService.isConfigured()) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AdaptiveLayout(
              child: ServerConfigScreen(allowBack: false),
            ),
          ),
        );
        return;
      }
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isAuthenticated = await authProvider.checkAuth();
      
      if (!mounted) return;
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => AdaptiveLayout(
            child: isAuthenticated
                ? const HomeNavigation()
                : const LoginScreen(),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
              const Color(0xFF1E3A8A), // Azul escuro da logo
              const Color(0xFF2563EB), // Azul médio
              const Color(0xFF1E3A8A).withOpacity(0.9),
            ],
            stops: const [0.0, 0.5, 1.0],
                    ),
        ),
        child: Center(
          child: AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoScaleAnimation.value,
                            child: Opacity(
                              opacity: _logoOpacityAnimation.value,
                  child: H4NDLogo(
                    fontSize: 80,
                    showPdv: true,
                              ),
                            ),
                          );
                        },
                      ),
        ),
      ),
    );
  }
}

