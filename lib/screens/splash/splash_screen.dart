import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/adaptive_layout/adaptive_layout.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/widgets/common/mx_logo.dart';
import '../../presentation/widgets/common/home_navigation.dart';
import '../../presentation/screens/auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _backgroundController;
  
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();

    // Logo animations - simplificadas
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Escala suave de 0.5 para 1.0
    _logoScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOut,
      ),
    );

    // Opacidade de 0 para 1
    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeIn,
      ),
    );

    // Text animations
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOut,
      ),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Background animation
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _backgroundController,
        curve: Curves.easeInOut,
      ),
    );

    // Start animations
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _textController.forward();
    });

    // Verifica autenticação e navega após animação
    Future.delayed(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      
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
    _textController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6366F1),
                  const Color(0xFF8B5CF6),
                  const Color(0xFFEC4899),
                ],
                stops: [
                  0.0,
                  0.5 + (_backgroundAnimation.value * 0.1),
                  1.0,
                ],
              ),
            ),
            child: Stack(
              children: [
                // Animated circles background
                ...List.generate(5, (index) {
                  return Positioned(
                    left: 100 + (index * 150) +
                        (50 * (_backgroundAnimation.value * 2 - 1)),
                    top: 100 + (index * 100) +
                        (30 * ((_backgroundAnimation.value + index * 0.2) % 1 - 0.5)),
                    child: Container(
                      width: 200 + (index * 50),
                      height: 200 + (index * 50),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  );
                }),
                // Main content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo MX com animações simples
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoScaleAnimation.value,
                            child: Opacity(
                              opacity: _logoOpacityAnimation.value,
                              child: const MXLogo(
                                size: 120,
                                animated: true,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                      // Text with animations
                      SlideTransition(
                        position: _textSlideAnimation,
                        child: FadeTransition(
                          opacity: _textFadeAnimation,
                          child: Column(
                            children: [
                              Text(
                                'MX Cloud PDV',
                                style: GoogleFonts.inter(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -1,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Sistema de Atendimento Multi-segmento',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.9),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                      // Loading indicator
                      FadeTransition(
                        opacity: _textFadeAnimation,
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withOpacity(0.8),
                            ),
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

