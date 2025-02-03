import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as p; // ✅ Evita conflito com `context`
import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/custom_multiline_input_field.dart';
import '../widgets/date_picker_input.dart';
import '../widgets/custom_button.dart';

class PreviewReceiptScreen extends StatefulWidget {
  const PreviewReceiptScreen({Key? key}) : super(key: key);

  @override
  _PreviewReceiptScreenState createState() => _PreviewReceiptScreenState();
}

class _PreviewReceiptScreenState extends State<PreviewReceiptScreen> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isUploading = false; // Controle de carregamento

  @override
  Widget build(BuildContext context) {
    // Obtém o caminho da imagem passada via argumentos
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String? imagePath = args?['imagePath'];

    return BaseLayout(
      title: "Time Sheet",
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const Center(child: TitleBox(title: "New Receipt")),
            const SizedBox(height: 20),

            // 1️⃣ Campo de Data
            DatePickerInput(
              label: "Date",
              hintText: "Select receipt date",
              controller: _dateController,
            ),

            const SizedBox(height: 16),

            // 2️⃣ Campo de Valor
            CustomInputField(
              label: "Amount",
              hintText: "Enter receipt amount",
              controller: _amountController,
            ),

            const SizedBox(height: 16),

            // 3️⃣ Campo de Descrição
            CustomMultilineInputField(
              label: "Description",
              hintText: "Enter receipt details",
              controller: _descriptionController,
            ),

            const SizedBox(height: 20),

            // Exibir imagem completa
            if (imagePath != null && imagePath.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain, // Exibe imagem inteira
                  width: double.infinity,
                ),
              )
            else
              const Text(
                "No image captured.",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),

            const SizedBox(height: 20),

            // Botões: Cancelar & Upload
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CustomButton(
                  type: ButtonType.cancelButton,
                  onPressed: () {
                    Navigator.pop(context); // Voltar
                  },
                ),
                _isUploading
                    ? const CircularProgressIndicator() // Mostra loading enquanto faz upload
                    : CustomButton(
                        type: ButtonType.uploadReceiptButton,
                        onPressed: () {
                          if (imagePath != null) {
                            uploadReceipt(File(imagePath));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("No image to upload!")),
                            );
                          }
                        },
                      ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// **Faz upload da imagem e dos dados para o Firebase**
  Future<void> uploadReceipt(File imageFile) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "User not logged in.";

      // Gera um nome de arquivo único
      String fileName = p.basename(imageFile.path);
      Reference storageRef =
          FirebaseStorage.instance.ref().child("receipts/$fileName");

      // Faz upload da imagem para o Firebase Storage
      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;

      // Obtém a URL da imagem após o upload
      String imageUrl = await snapshot.ref.getDownloadURL();

      // Salva os detalhes do recibo no Firestore com o userId do criador
      await FirebaseFirestore.instance.collection("receipts").add({
        "userId": user.uid, // ✅ Salva o ID do usuário logado
        "date": _dateController.text.trim(),
        "amount": _amountController.text.trim(),
        "description": _descriptionController.text.trim(),
        "imageUrl": imageUrl,
        "timestamp": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Receipt uploaded successfully!")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }
}
