import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Widget da logo H4ND
/// H, N, D em azul escuro, 4 em verde, pdv em verde abaixo
class H4NDLogo extends StatelessWidget {
  final double? fontSize;
  final bool showPdv;
  final Color? blueColor;
  final Color? greenColor;

  const H4NDLogo({
    super.key,
    this.fontSize,
    this.showPdv = true,
    this.blueColor,
    this.greenColor,
  });

  @override
  Widget build(BuildContext context) {
    final size = fontSize ?? 48.0;
    final blue = blueColor ?? const Color(0xFF1E3A8A); // Azul escuro
    final green = greenColor ?? const Color(0xFF10B981); // Verde vibrante

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // H4ND principal
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // H
            Text(
              'H',
              style: GoogleFonts.inter(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: blue,
                letterSpacing: -1,
                height: 1,
              ),
            ),
            // 4
            Text(
              '4',
              style: GoogleFonts.inter(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: green,
                letterSpacing: -1,
                height: 1,
              ),
            ),
            // N
            Text(
              'N',
              style: GoogleFonts.inter(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: blue,
                letterSpacing: -1,
                height: 1,
              ),
            ),
            // D
            Text(
              'D',
              style: GoogleFonts.inter(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: blue,
                letterSpacing: -1,
                height: 1,
              ),
            ),
          ],
        ),
        // pdv abaixo, alinhado à direita do final de H4ND
        if (showPdv)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'pdv',
              style: GoogleFonts.inter(
                fontSize: size * 0.35,
                fontWeight: FontWeight.w600,
                color: green,
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ),
      ],
    );
  }
}

