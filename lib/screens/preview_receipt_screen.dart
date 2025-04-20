import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart'; // Adicione esse import

import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/custom_multiline_input_field.dart';
import '../widgets/date_picker_input.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_dropdown_field.dart';

class USDCurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) digits = '0';
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

  DateTime? _selectedDate;
  bool _isUploading = false;
  List<Map<String, String>> _activeCards = [];
  String? _selectedCardOption;

  @override
  void initState() {
    super.initState();
    _loadActiveCards();
  }

  Future<void> _loadActiveCards() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('cards')
          .where('status', isEqualTo: 'ativo')
          .get();

      final List<Map<String, String>> loaded = [];
      for (var doc in snap.docs) {
        final data = doc.data();
        final last4 = data['last4Digits']?.toString() ?? '';
        final holder = data['cardholderName']?.toString() ?? '';
        if (last4.isNotEmpty) {
          loaded.add({
            'last4': last4,
            'cardholderName': holder,
          });
        }
      }
      setState(() {
        _activeCards = loaded;
      });
    } catch (e) {
      print("Erro ao carregar cartões ativos: $e");
    }
  }

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
            _buildCardLast4Dropdown(),
            const SizedBox(height: 16),
            DatePickerInput(
              label: "Purchase date",
              hintText: "Select purchase date",
              controller: _dateController,
              onDateSelected: (picked) => _selectedDate = picked,
            ),
            const SizedBox(height: 16),
            CustomInputField(
              label: "Amount",
              hintText: "\$0.00",
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [USDCurrencyInputFormatter()],
            ),
            const SizedBox(height: 16),
            CustomMultilineInputField(
              label: "Description",
              hintText: "Description of the purchase",
              controller: _descriptionController,
            ),
            const SizedBox(height: 20),
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
            Visibility(
              visible:
                  false, // Define como false para ocultar o botão e colapsá-lo
              replacement: const SizedBox.shrink(),
              child: ElevatedButton(
                onPressed: _convertDatesToTimestamps,
                child: const Text("Converter Datas para Timestamp"),
              ),
            ),
            const SizedBox(height: 20),
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

  Future<void> _convertDatesToTimestamps() async {
    try {
      final collection = FirebaseFirestore.instance.collection('receipts');
      final querySnapshot = await collection.get();

      // Define o formatador para "M/d/yy" (exemplo: "4/12/25")
      final DateFormat formatter = DateFormat("M/d/yy");

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final dateField = data['date'];

        // Verifica se o campo 'date' é String
        if (dateField is String) {
          // Separa o dia, usando apenas a parte antes da vírgula
          final String dateToParse = dateField.split(',')[0];
          try {
            DateTime parsedDate = formatter.parse(dateToParse);
            final Timestamp timestamp = Timestamp.fromDate(parsedDate);
            // Atualiza o documento com o valor convertido
            await doc.reference.update({'date': timestamp});
          } catch (e) {
            print("Erro ao converter data para doc ${doc.id}: $e");
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Datas convertidas com sucesso!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Falha ao converter datas: $e")),
      );
    }
  }

  Widget _buildCardLast4Dropdown() {
    final List<String> dropdownItems = _activeCards.isNotEmpty
        ? _activeCards.map((map) {
            final last4 = map['last4'] ?? '';
            final holder = map['cardholderName'] ?? '';
            return "$last4 - $holder";
          }).toList()
        : [];

    return CustomDropdownField(
      label: "Last 4 digits",
      hintText: "Select the card",
      items: dropdownItems,
      value: _selectedCardOption,
      onChanged: (newValue) {
        setState(() {
          _selectedCardOption = newValue;
          if (newValue != null && newValue.contains(' - ')) {
            final parts = newValue.split(' - ');
            _cardLast4Controller.text = parts[0];
          } else {
            _cardLast4Controller.clear();
          }
        });
      },
    );
  }

  void _attemptUpload(String? imagePath) {
    if (_cardLast4Controller.text.trim().isEmpty ||
        _selectedDate == null ||
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
      final snapshot = await storageRef.putFile(imageFile);
      final imageUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection("receipts").add({
        "userId": user.uid,
        "cardLast4": _cardLast4Controller.text.trim(),
        "date": Timestamp.fromDate(_selectedDate!),
        "amount": _amountController.text.trim(),
        "description": _descriptionController.text.trim(),
        "imageUrl": imageUrl,
        "timestamp": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Receipt uploaded successfully!")),
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/receipts',
        (route) => false,
      );
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
