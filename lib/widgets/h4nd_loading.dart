import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Componente de loading personalizado com a logo H4ND
/// - Anel rotativo ao redor
/// - Letras H, 4, N, D com animação de pulso
/// - O "4" é verde, o resto é azul
class H4ndLoading extends StatefulWidget {
  final double size;
  final Color? blueColor;
  final Color? greenColor;
  final bool showSolutions;
  final String? message;

  const H4ndLoading({
    Key? key,
    this.size = 120.0, // ✅ Aumentado para 120.0 para dar mais espaço ao texto
    this.blueColor,
    this.greenColor,
    this.showSolutions = false,
    this.message,
  }) : super(key: key);

  @override
  State<H4ndLoading> createState() => _H4ndLoadingState();
}

class _H4ndLoadingState extends State<H4ndLoading>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _lettersAppearController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Controlador para rotação do anel
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Controlador para pulso das letras
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Controlador para aparecimento sequencial das letras
    _lettersAppearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _lettersAppearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cores padrão da logo H4ND: azul #00A8E8 e verde #14B8A6
    final blue = widget.blueColor ?? const Color(0xFF00A8E8);
    final green = widget.greenColor ?? const Color(0xFF14B8A6);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Círculo com anel rotativo e texto
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Anel rotativo
                  AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationController.value * 2 * math.pi,
                        child: CustomPaint(
                          size: Size(widget.size, widget.size),
                          painter: _RotatingRingPainter(
                            color: blue,
                            size: widget.size,
                          ),
                        ),
                      );
                    },
                  ),
                  // Texto H4ND
                  Padding(
                    padding: EdgeInsets.all(widget.size * 0.12), // ✅ Reduzido de 0.15 para 0.12 para dar mais espaço ao texto
                    child: ClipRect(
                      child: _buildH4ndText(blue, green),
                    ),
                  ),
                ],
              ),
            ),
            // Texto "solutions" (se solicitado)
            if (widget.showSolutions) ...[
              SizedBox(height: widget.size * 0.1),
              Text(
                'solutions',
                style: TextStyle(
                  fontSize: widget.size * 0.12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
            // Mensagem opcional
            if (widget.message != null) ...[
              SizedBox(height: widget.size * 0.1),
              Text(
                widget.message!,
                style: TextStyle(
                  fontSize: widget.size * 0.1,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildH4ndText(Color blue, Color green) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLetterWithAppear('H', 0, blue),
        _buildLetterWithAppear('4', 1, green, isGreen: true),
        _buildLetterWithAppear('N', 2, blue),
        _buildLetterWithAppear('D', 3, blue),
      ],
    );
  }

  Widget _buildLetterWithAppear(
    String letter,
    int index,
    Color color, {
    bool isGreen = false,
  }) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _lettersAppearController,
        _pulseAnimation,
      ]),
      builder: (context, child) {
        // Animação de aparecimento sequencial
        final appearProgress = math.max(
          0.0,
          math.min(
            1.0,
            (_lettersAppearController.value * 4 - index).clamp(0.0, 1.0),
          ),
        );

        // Animação de pulso
        final pulseScale = _pulseAnimation.value;

        // Escala combinada
        final scale = appearProgress * pulseScale;

        // Opacidade
        final opacity = appearProgress;

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Text(
              letter,
              style: TextStyle(
                fontSize: widget.size * 0.24, // ✅ Reduzido de 0.28 para 0.24 para caber melhor
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: color,
                height: 1.0,
                shadows: isGreen
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.08),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Pintor para o anel rotativo
class _RotatingRingPainter extends CustomPainter {
  final Color color;
  final double size;

  _RotatingRingPainter({
    required this.color,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final radius = this.size / 2 - 2;
    final center = Offset(this.size / 2, this.size / 2);

    // Clipping para garantir que não ultrapasse os limites
    canvas.clipRect(Rect.fromLTWH(0, 0, this.size, this.size));

    // Desenha o anel (círculo incompleto para efeito de rotação)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 1.5, // 270 graus
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Versão compacta do loading (sem anel, apenas texto)
class H4ndLoadingCompact extends StatefulWidget {
  final double size;
  final Color? blueColor;
  final Color? greenColor;

  const H4ndLoadingCompact({
    Key? key,
    this.size = 20.0,
    this.blueColor,
    this.greenColor,
  }) : super(key: key);

  @override
  State<H4ndLoadingCompact> createState() => _H4ndLoadingCompactState();
}

class _H4ndLoadingCompactState extends State<H4ndLoadingCompact>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cores padrão da logo H4ND: azul #00A8E8 e verde #14B8A6
    final blue = widget.blueColor ?? const Color(0xFF00A8E8);
    final green = widget.greenColor ?? const Color(0xFF14B8A6);

    return SizedBox(
      width: widget.size * 2.5,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'H',
                  style: TextStyle(
                    fontSize: widget.size * 0.7,
                    fontWeight: FontWeight.w600,
                    color: blue,
                    height: 1.0,
                  ),
                ),
                Text(
                  '4',
                  style: TextStyle(
                    fontSize: widget.size * 0.7,
                    fontWeight: FontWeight.w600,
                    color: green,
                    height: 1.0,
                    shadows: [
                      BoxShadow(
                        color: green.withOpacity(0.15),
                        blurRadius: 3,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
                Text(
                  'N',
                  style: TextStyle(
                    fontSize: widget.size * 0.7,
                    fontWeight: FontWeight.w600,
                    color: blue,
                    height: 1.0,
                  ),
                ),
                Text(
                  'D',
                  style: TextStyle(
                    fontSize: widget.size * 0.7,
                    fontWeight: FontWeight.w600,
                    color: blue,
                    height: 1.0,
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

/// Versão overlay (para usar em diálogos)
class H4ndLoadingOverlay extends StatelessWidget {
  final double size;
  final String? message;

  const H4ndLoadingOverlay({
    Key? key,
    this.size = 120.0, // ✅ Aumentado para 120.0 para consistência
    this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: H4ndLoading(
            size: size,
            message: message,
          ),
        ),
      ),
    );
  }
}

