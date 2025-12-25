import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Container de barra de ferramentas com efeito 3D elevado e identidade visual da marca
/// 
/// Este componente pode ser reutilizado em qualquer lugar do sistema que precise
/// de uma barra de ferramentas com o design padrão elevado.
/// 
/// Altura fixa: 68px (incluindo linha decorativa de 2.5px)
class ElevatedToolbarContainer extends StatelessWidget {
  /// Conteúdo da barra de ferramentas
  final Widget child;
  
  /// Se deve aplicar SafeArea (padrão: true)
  final bool useSafeArea;
  
  /// Padding customizado (opcional)
  final EdgeInsets? padding;
  
  /// Altura base da barra em logical pixels (padrão: 68px)
  /// Será ajustada automaticamente baseado na densidade de pixels da tela
  static const double alturaBase = 68.0;

  const ElevatedToolbarContainer({
    super.key,
    required this.child,
    this.useSafeArea = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    // Calcula altura total: base + SafeArea (se aplicável)
    // Isso garante que a altura VISUAL do conteúdo seja sempre a mesma
    final mediaQuery = MediaQuery.of(context);
    final safeAreaTop = useSafeArea ? mediaQuery.padding.top : 0.0;
    
    // Altura total = altura base + SafeArea
    // Isso mantém a altura visual do conteúdo consistente
    final alturaTotal = alturaBase + safeAreaTop;
    
    return Container(
      height: alturaTotal,
      decoration: BoxDecoration(
        // Gradiente vertical com cores da marca (azul e verde) de forma sutil
        // Mantém a mesma cor no início e no fim
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            // Topo: branco com toque muito sutil de azul
            const Color(0xFFF8F9FF),
            Colors.white,
            // Meio: branco com toque muito sutil de verde
            const Color(0xFFF8FFF9),
            // Base: branco com toque muito sutil de azul (mesma cor do topo)
            const Color(0xFFF8F9FF),
          ],
          stops: const [0.0, 0.2, 0.6, 1.0],
        ),
        // Bordas para efeito de elevação 3D com identidade visual
        border: Border(
          // Borda superior com cor da marca
          top: BorderSide(
            color: AppTheme.primaryColor.withOpacity(0.2),
            width: 2.5,
          ),
          left: BorderSide(
            color: Colors.white.withOpacity(0.8),
            width: 1,
          ),
          right: BorderSide(
            color: Colors.white.withOpacity(0.8),
            width: 1,
          ),
          // Borda inferior com toque de azul da marca
          bottom: BorderSide(
            color: AppTheme.primaryColor.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        // Múltiplas sombras pronunciadas com toque de cor da marca
        boxShadow: [
          // Sombra principal forte (mais próxima - cria elevação)
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          // Sombra intermediária (profundidade)
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          // Sombra ambiente (espalhamento)
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          // Sombra de elevação superior (brilho)
          BoxShadow(
            color: Colors.white.withOpacity(0.95),
            blurRadius: 0,
            offset: const Offset(0, -2),
            spreadRadius: 0,
          ),
          // Sombra lateral esquerda (profundidade 3D)
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(-2, 2),
            spreadRadius: 0,
          ),
          // Sombra lateral direita (profundidade 3D)
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(2, 2),
            spreadRadius: 0,
          ),
          // Sombra sutil com toque de azul da marca (identidade visual)
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      // Linha decorativa superior com cores da marca (azul e verde)
      child: Stack(
        children: [
          // Linha decorativa no topo com gradiente vertical (verde-azul-verde)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 2.5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.accentColor.withOpacity(0.4),
                    AppTheme.primaryColor.withOpacity(0.6),
                    AppTheme.accentColor.withOpacity(0.4),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Conteúdo da barra
          // Padding top já está incluído na altura total, então apenas posicionamos
          Padding(
            padding: EdgeInsets.only(
              top: safeAreaTop,
            ),
            child: _buildContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    // Padding consistente independente da plataforma
    // O SafeArea já foi tratado no build(), então aqui apenas aplicamos o padding padrão
    return Container(
      padding: padding ??
          EdgeInsets.only(
            top: 2.5 + 10, // Espaço para linha decorativa + padding padrão
            bottom: 10,
            left: 16,
            right: 16,
          ),
      child: child,
    );
  }
}

