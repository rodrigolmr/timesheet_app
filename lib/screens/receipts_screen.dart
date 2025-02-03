import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_button.dart';
import 'receipt_viewer_screen.dart';
import 'preview_receipt_screen.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({Key? key}) : super(key: key);

  @override
  _ReceiptsScreenState createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  String _userRole = "User"; // Padrão: "User"
  String _userId = ""; // ID do usuário logado

  @override
  void initState() {
    super.initState();
    _getUserRole(); // Obtém o tipo de usuário ao iniciar a tela
  }

  /// **Obtém a role do usuário logado no Firestore**
  Future<void> _getUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(_userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          _userRole = userDoc.data()?["role"] ?? "User"; // Padrão: "User"
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: "Time Sheet", // ✅ Mantém o título fixo
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Center(
              child: TitleBox(title: "Receipts")), // ✅ Mantém o título Receipts
          const SizedBox(height: 20),

          // ✅ Container para o botão "New" (abrir scanner)
          SizedBox(
            width: 330, // Mesmo tamanho dos botões em outras telas
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CustomButton(
                  type: ButtonType.newButton,
                  onPressed: () async {
                    await _scanDocument(context);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Exibir os recibos
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  _getReceiptsStream(), // ✅ Busca de acordo com o tipo de usuário
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading receipts"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text("No receipts found."));
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: GridView.builder(
                    itemCount: docs.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // ✅ Agora exibe 3 colunas
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final String imageUrl = data["imageUrl"] ?? "";

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ReceiptViewerScreen(imageUrl: imageUrl),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            color: Colors.grey[300],
                            child: imageUrl.endsWith(".pdf")
                                ? _buildPdfThumbnail()
                                : _buildImageThumbnail(imageUrl),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// **Abre o scanner de documentos e envia para `PreviewReceiptScreen`**
  Future<void> _scanDocument(BuildContext context) async {
    try {
      List<String>? scannedImages = await CunningDocumentScanner.getPictures();

      if (scannedImages != null && scannedImages.isNotEmpty) {
        // Pegamos a primeira imagem capturada
        String imagePath = scannedImages.first;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewReceiptScreen(),
            settings: RouteSettings(arguments: {'imagePath': imagePath}),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No document scanned.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Scanning failed: $e")),
      );
    }
  }

  /// **Obtém os recibos com base no tipo de usuário**
  Stream<QuerySnapshot> _getReceiptsStream() {
    final receiptsCollection =
        FirebaseFirestore.instance.collection("receipts");

    if (_userRole == "Admin") {
      return receiptsCollection
          .orderBy("timestamp", descending: true)
          .snapshots();
    } else {
      return receiptsCollection
          .where("userId",
              isEqualTo:
                  _userId) // ✅ Filtra apenas os recibos do usuário logado
          .orderBy("timestamp", descending: true)
          .snapshots();
    }
  }

  /// Exibe um ícone de PDF como miniatura
  Widget _buildPdfThumbnail() {
    return const Center(
      child: Icon(
        Icons.picture_as_pdf,
        size: 50,
        color: Colors.red,
      ),
    );
  }

  /// Exibe a miniatura da imagem do recibo
  Widget _buildImageThumbnail(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) =>
          const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}
