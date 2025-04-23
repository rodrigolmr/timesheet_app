import 'dart:io'; // Para verificar se está em macOS
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/custom_button_mini.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({Key? key}) : super(key: key);

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  bool _showForm = false;
  final TextEditingController _cardholderNameController =
      TextEditingController();
  final TextEditingController _last4DigitsController = TextEditingController();

  String _statusFilter = "all"; // "all", "active", "inactive"

  // Lógica de redimensionamento (similar ao receipts_screen)
  bool _showCardSizeSlider = false;
  double _maxCardWidth = 250;

  void _handleAddCard() {
    setState(() {
      _showForm = true;
    });
  }

  void _handleCancel() {
    setState(() {
      _showForm = false;
      _cardholderNameController.clear();
      _last4DigitsController.clear();
    });
  }

  /// Salva o novo cartão no Firestore
  Future<void> _handleSave() async {
    final cardholderName = _cardholderNameController.text.trim();
    final last4Digits = _last4DigitsController.text.trim();

    if (cardholderName.isEmpty || last4Digits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields before saving.'),
        ),
      );
      return;
    }

    try {
      final docRef = FirebaseFirestore.instance.collection('cards').doc();
      await docRef.set({
        'uniqueId': docRef.id,
        'cardholderName': cardholderName,
        'last4Digits': last4Digits,
        'status': 'ativo', // status padrão
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card saved successfully!')),
      );

      setState(() {
        _showForm = false;
        _cardholderNameController.clear();
        _last4DigitsController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving card: $e')),
      );
    }
  }

  /// Abre o diálogo para mudar status (ativo/inativo)
  void _showStatusDialog(
    String docId,
    String cardholderName,
    String last4Digits,
    String currentStatus,
  ) {
    String newStatus = currentStatus;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFF0205D3), width: 2),
            borderRadius: BorderRadius.circular(5),
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$cardholderName ($last4Digits)",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDD0),
                      border: Border.all(
                        color: const Color(0xFF0205D3),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: newStatus,
                        style:
                            const TextStyle(fontSize: 14, color: Colors.black),
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'ativo',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'inativo',
                            child: Text('Inactive'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              newStatus = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            CustomMiniButton(
              type: MiniButtonType.cancelMiniButton,
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(width: 10),
            CustomMiniButton(
              type: MiniButtonType.saveMiniButton,
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('cards')
                      .doc(docId)
                      .update({'status': newStatus});

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Status updated to "$newStatus"!'),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating status: $e')),
                  );
                }
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
    return BaseLayout(
      title: "Cards",
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const TitleBox(title: "Company Cards"),
            const SizedBox(height: 20),

            // Top bar (Add + Columns se macOS)
            _buildTopBar(isMacOS),

            // Se estiver no macOS e showCardSizeSlider = true, exibir caixa com slider
            if (isMacOS && _showCardSizeSlider) ...[
              // Espaçamento extra semelhante ao do form
              const SizedBox(height: 20),
              _buildSliderForMacOS(),
            ],

            // Se _showForm = true, exibe o formulário
            if (_showForm) ...[
              const SizedBox(height: 20),
              _buildAddCardForm(isMacOS),
            ],

            const SizedBox(height: 20),

            // Dropdown de status (All, Active, Inactive)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(right: 20),
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFF0205D3), width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    style: const TextStyle(fontSize: 14, color: Colors.black),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All'),
                      ),
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Active'),
                      ),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive'),
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          _statusFilter = value;
                        });
                      }
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Exibição da grade de cartões
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('cards')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Error loading Cards',
                    style: TextStyle(color: Colors.red),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Text('No cards found.');
                }

                // Filtro de status
                List<DocumentSnapshot> filteredDocs = docs;
                if (_statusFilter == 'active') {
                  filteredDocs = docs
                      .where((doc) =>
                          (doc.data() as Map<String, dynamic>)['status'] ==
                          'ativo')
                      .toList();
                } else if (_statusFilter == 'inactive') {
                  filteredDocs = docs
                      .where((doc) =>
                          (doc.data() as Map<String, dynamic>)['status'] ==
                          'inativo')
                      .toList();
                }

                final double containerWidth =
                    MediaQuery.of(context).size.width - 60;

                return Container(
                  width: containerWidth < 0 ? 0 : containerWidth,
                  child: _buildCardsGrid(filteredDocs),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Top bar contendo Add e Columns (somente macOS)
  Widget _buildTopBar(bool isMacOS) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Botão Add (abriu, remove o outro "Add" do código)
        CustomButton(
          type: ButtonType.addWorkerButton,
          onPressed: _handleAddCard,
        ),
        // Botão Columns caso seja macOS
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
    );
  }

  /// Exibe slider (no macOS) para ajustar a largura,
  /// agora com ConstrainedBox limitando a 600px e
  /// espaçamento extra igual ao do "Add".
  Widget _buildSliderForMacOS() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0FF),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
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
    );
  }

  /// Constrói a grid de cartões (usamos SliverGridDelegate condicional)
  Widget _buildCardsGrid(List<DocumentSnapshot> docs) {
    final bool isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
    final gridDelegate =
        (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS)
            ? const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.5,
              )
            : SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: _maxCardWidth,
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
        final docData = docs[index].data() as Map<String, dynamic>;
        final docId = docs[index].id;
        final cardholderName = docData['cardholderName'] ?? '';
        final last4 = docData['last4Digits'] ?? '';
        final status = docData['status'] ?? 'ativo';

        return GestureDetector(
          onTap: () {
            _showStatusDialog(docId, cardholderName, last4, status);
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFD0),
              border: Border.all(
                color: const Color(0xFF0205D3),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                child: Text(
                  '$cardholderName\n($last4)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Formulário para cadastrar o cartão
  Widget _buildAddCardForm(bool isMacOS) {
    final double fieldMaxWidth = isMacOS ? 600 : double.infinity;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: fieldMaxWidth),
      child: Column(
        children: [
          CustomInputField(
            label: "Cardholder Name",
            hintText: "Enter cardholder name",
            controller: _cardholderNameController,
          ),
          const SizedBox(height: 10),
          CustomInputField(
            label: "Last 4 digits",
            hintText: "Enter last 4 digits",
            controller: _last4DigitsController,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomMiniButton(
                type: MiniButtonType.cancelMiniButton,
                onPressed: _handleCancel,
              ),
              const SizedBox(width: 10),
              CustomMiniButton(
                type: MiniButtonType.saveMiniButton,
                onPressed: _handleSave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
