import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para TextInputFormatter
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as p;
import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/custom_multiline_input_field.dart';
import '../widgets/date_picker_input.dart';
import '../widgets/custom_button.dart';

/// USDCurrencyInputFormatter
/// Remove caracteres não numéricos, interpreta os dígitos como centavos e formata para exibir:
/// Exemplo:
/// - Digitar "9" => "$0.09"
/// - Digitar "95" => "$0.95"
/// - Digitar "955" => "$9.55"
/// - Digitar "9557" => "$95.57"
class USDCurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove tudo que não for dígito.
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      digits = '0';
    }
    int value = int.parse(digits);
    double dollars = value / 100.0;
    String newText = "\$" + dollars.toStringAsFixed(2);
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class PreviewReceiptScreen extends StatefulWidget {
  const PreviewReceiptScreen({Key? key}) : super(key: key);

  @override
  _PreviewReceiptScreenState createState() => _PreviewReceiptScreenState();
}

class _PreviewReceiptScreenState extends State<PreviewReceiptScreen> {
  final TextEditingController _cardLast4Controller = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String? imagePath = args?['imagePath'];

    return BaseLayout(
      title: "Timesheet",
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const Center(child: TitleBox(title: "New Receipt")),
            const SizedBox(height: 20),
            // Campo Last 4 digits (apenas números, até 4 dígitos)
            CustomInputField(
              label: "Last 4 digits",
              hintText: "Enter the last 4 digits of the card",
              controller: _cardLast4Controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
            ),
            const SizedBox(height: 16),
            // Campo Purchase date
            DatePickerInput(
              label: "Purchase date",
              hintText: "Select purchase date",
              controller: _dateController,
            ),
            const SizedBox(height: 16),
            // Campo Amount com formatação de moeda americana.
            CustomInputField(
              label: "Amount",
              hintText: "\$0.00",
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                USDCurrencyInputFormatter(),
              ],
            ),
            const SizedBox(height: 16),
            // Campo Description
            CustomMultilineInputField(
              label: "Description",
              hintText: "Description of the purchase",
              controller: _descriptionController,
            ),
            const SizedBox(height: 20),
            // Botões (Cancel e Upload) acima da imagem
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CustomButton(
                  type: ButtonType.cancelButton,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                _isUploading
                    ? const CircularProgressIndicator()
                    : CustomButton(
                        type: ButtonType.uploadReceiptButton,
                        onPressed: () {
                          _attemptUpload(imagePath);
                        },
                      ),
              ],
            ),
            const SizedBox(height: 20),
            // Exibe a imagem capturada
            if (imagePath != null && imagePath.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              )
            else
              const Text(
                "No image captured.",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Verifica se os campos obrigatórios foram preenchidos.
  /// (Description é opcional)
  void _attemptUpload(String? imagePath) {
    if (_cardLast4Controller.text.trim().isEmpty ||
        _dateController.text.trim().isEmpty ||
        _amountController.text.trim().isEmpty ||
        imagePath == null ||
        imagePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Last 4 digits, Purchase date, Amount, and Image are required."),
        ),
      );
      return;
    }
    uploadReceipt(File(imagePath));
  }

  Future<void> uploadReceipt(File imageFile) async {
    setState(() {
      _isUploading = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "User not logged in.";
      final fileName = p.basename(imageFile.path);
      final storageRef =
          FirebaseStorage.instance.ref().child("receipts/$fileName");
      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();
      await FirebaseFirestore.instance.collection("receipts").add({
        "userId": user.uid,
        "cardLast4": _cardLast4Controller.text.trim(),
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
