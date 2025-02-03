import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TitleBox extends StatelessWidget {
  final String title;

  const TitleBox({
    Key? key,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 20px menor que a largura total da tela
    final double boxWidth = MediaQuery.of(context).size.width - 20;

    return Container(
      // Define a largura dinamicamente
      width: boxWidth,
      height: 70, // Mantém a altura original
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF0205D3), // Fundo azul
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
