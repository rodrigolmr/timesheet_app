import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_button_mini.dart';

class ReceiptViewerScreen extends StatelessWidget {
  final String imageUrl;

  const ReceiptViewerScreen({Key? key, required this.imageUrl})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: "Time Sheet", // ✅ Floating Header sempre "Time Sheet"
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Center(child: TitleBox(title: "Receipt")), // ✅ Título da página
          const SizedBox(height: 20),

          // Exibir informações do Firestore antes do recibo
          Expanded(
            child: FutureBuilder<DocumentSnapshot>(
              future: _getReceiptDetails(imageUrl),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text("Receipt not found"));
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final String docId =
                    snapshot.data!.id; // ID do documento Firestore

                return Column(
                  children: [
                    // Exibir informações do recibo
                    _buildInfoRow("Date:", data["date"] ?? "Not available"),
                    _buildInfoRow("Amount:", data["amount"] ?? "Not available"),
                    _buildInfoRow(
                        "Description:", data["description"] ?? "Not available"),

                    const SizedBox(height: 16),

                    // Exibir recibo (imagem ou PDF)
                    Expanded(
                      child: Center(
                        child: imageUrl.endsWith(".pdf")
                            ? PDFView(
                                filePath: imageUrl,
                                enableSwipe: true,
                                swipeHorizontal: true,
                                autoSpacing: true,
                                pageFling: true,
                              )
                            : Image.network(imageUrl, fit: BoxFit.contain),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ✅ Container para os botões Back e Delete
                    SizedBox(
                      width: 330, // Mesmo tamanho usado em outras telas
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment
                            .spaceBetween, // ✅ Back na esquerda, Delete na direita
                        children: [
                          // Botão de voltar (esquerda)
                          CustomButton(
                            type: ButtonType.backButton,
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),

                          // Mini botão de deletar (direita)
                          CustomMiniButton(
                            type: MiniButtonType.deleteMiniButton,
                            onPressed: () => _confirmDelete(context, docId),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Recupera os detalhes do recibo do Firestore com base na `imageUrl`
  Future<DocumentSnapshot> _getReceiptDetails(String imageUrl) async {
    final query = await FirebaseFirestore.instance
        .collection("receipts")
        .where("imageUrl", isEqualTo: imageUrl)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first;
    } else {
      return FirebaseFirestore.instance
          .collection("receipts")
          .doc("empty")
          .get();
    }
  }

  /// Exibe um alerta de confirmação antes de deletar
  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text("Delete Receipt"),
          content: const Text(
              "Are you sure you want to delete this receipt? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Fechar o alerta
                _deleteReceipt(context, docId);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  /// **Deleta o recibo do Firestore e Firebase Storage**
  Future<void> _deleteReceipt(BuildContext context, String docId) async {
    try {
      // Recuperar a URL do arquivo para deletá-lo do Storage
      final docRef =
          FirebaseFirestore.instance.collection("receipts").doc(docId);
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final String fileUrl = data["imageUrl"] ?? "";

        // Deletar o arquivo do Firebase Storage
        if (fileUrl.isNotEmpty) {
          final storageRef = FirebaseStorage.instance.refFromURL(fileUrl);
          await storageRef.delete();
        }

        // Deletar o documento do Firestore
        await docRef.delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Receipt deleted successfully!")),
        );

        Navigator.pop(context); // Voltar para a lista de recibos após deletar
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting receipt: $e")),
      );
    }
  }

  /// Constrói uma linha com o título e o valor da informação
  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
