import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class BaseLayout extends StatelessWidget {
  final Widget child; // Conteúdo principal da página
  final String title; // Texto do cabeçalho flutuante

  const BaseLayout({
    Key? key,
    required this.child,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Cabeçalho flutuante dentro de SafeArea
          SafeArea(
            bottom: false,
            child: Container(
              height: 60, // Altura do cabeçalho
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Ícone de menu suspenso (três barras horizontais)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.menu,
                      color: Color(0xFF0205D3),
                      size: 40, // Tamanho do ícone
                    ),
                    onSelected: (value) async {
                      if (value == 'Home') {
                        // Navega para /home e remove todas as rotas anteriores
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/home',
                          (route) => false,
                        );
                      } else if (value == 'Logout') {
                        // Faz logout no Firebase e vai para /login
                        await FirebaseAuth.instance.signOut();
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (route) => false,
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'Home',
                        child: Text('Home'),
                      ),
                      PopupMenuItem(
                        value: 'Logout',
                        child: Text('Logout'),
                      ),
                    ],
                  ),

                  // Título centralizado
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.raleway(
                      fontSize: 30, // Tamanho maior da fonte
                      fontWeight: FontWeight.w800, // Peso da fonte
                      color: Color(0xFF0205D3), // Azul
                    ),
                  ),

                  // Placeholder para balancear o espaço
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),

          // Conteúdo principal diretamente abaixo do cabeçalho
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}
