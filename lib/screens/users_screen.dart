import 'dart:io'; // Para verificar se está em macOS
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_button.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({Key? key}) : super(key: key);

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  // Controle do slider e exibição:
  bool _showCardSizeSlider = false;
  double _maxCardWidth = 250.0;

  @override
  Widget build(BuildContext context) {
    // Verifica se está em macOS
    final bool isMacOS =
        defaultTargetPlatform == TargetPlatform.macOS || Platform.isMacOS;

    return BaseLayout(
      title: "Timesheet",
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const TitleBox(title: "Users"),
            const SizedBox(height: 20),

            // Barra superior com botões
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomButton(
                  type: ButtonType.addUserButton,
                  onPressed: () {
                    Navigator.pushNamed(context, '/new-user');
                  },
                ),
                // Se for macOS, exibe o botão "Columns"
                if (isMacOS) ...[
                  const SizedBox(width: 20),
                  CustomButton(
                    type: ButtonType.columnsButton,
                    onPressed: () {
                      setState(() {
                        _showCardSizeSlider = !_showCardSizeSlider;
                      });
                    },
                  ),
                ],
              ],
            ),

            // Espaçamento entre a barra de botões e o slider
            if (isMacOS && _showCardSizeSlider) ...[
              const SizedBox(height: 20),
              _buildSliderForMacOS(),
            ],

            const SizedBox(height: 20),

            // Listagem de usuários (Grid)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Erro ao carregar usuários',
                    style: TextStyle(color: Colors.red),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Text('Nenhum usuário encontrado.');
                }

                // Container que limita a largura
                final double rawWidth = MediaQuery.of(context).size.width - 60;
                final double containerWidth = (rawWidth < 0.0) ? 0.0 : rawWidth;

                return Container(
                  width: containerWidth,
                  child: _buildUsersGrid(docs, isMacOS),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói o slider para macOS, com largura máxima de 600
  Widget _buildSliderForMacOS() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0FF),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Card Size:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              const Text("Min"),
              SizedBox(
                width: 150,
                child: Slider(
                  value: _maxCardWidth,
                  min: 150,
                  max: 600,
                  divisions: 45,
                  onChanged: (double value) {
                    setState(() {
                      _maxCardWidth = value;
                    });
                  },
                ),
              ),
              const Text("Max"),
            ],
          ),
        ),
      ),
    );
  }

  /// Constrói a Grid de usuários. Se for macOS, usamos SliverGridDelegateWithMaxCrossAxisExtent.
  Widget _buildUsersGrid(List<DocumentSnapshot> docs, bool isMacOS) {
    final gridDelegate = isMacOS
        ? SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: _maxCardWidth,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
          )
        : const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
          );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      gridDelegate: gridDelegate,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final firstName = data['firstName'] ?? '';
        final lastName = data['lastName'] ?? '';

        // Card no estilo timesheet: amarelo + borda azul
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFD0), // Fundo amarelo
            border: Border.all(
              color: const Color(0xFF0205D3), // Azul
              width: 2,
            ),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '$firstName $lastName',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
