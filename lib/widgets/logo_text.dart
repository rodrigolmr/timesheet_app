import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LogoText extends StatelessWidget {
  const LogoText({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 330, // Largura da caixa
      height: 140, // Altura da caixa
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF0205D3), width: 5), // Contorno azul
        borderRadius: BorderRadius.circular(20), // Bordas arredondadas
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Central Island',
            style: GoogleFonts.poppins(
              fontSize: 42, // Tamanho da fonte
              fontWeight: FontWeight.w800, // Negrito
              color: const Color(0xFF0205D3), // Azul
              letterSpacing: -1.5, // Redução do espaçamento entre letras
            ),
          ),
          Text(
            'Floors',
            style: GoogleFonts.poppins(
              fontSize: 42, // Tamanho da fonte
              fontWeight: FontWeight.w800, // Negrito
              color: const Color(0xFF0205D3), // Azul
              letterSpacing: -1.5, // Redução do espaçamento entre letras
            ),
          ),
        ],
      ),
    );
  }
}
