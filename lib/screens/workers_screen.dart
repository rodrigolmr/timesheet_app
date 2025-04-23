import 'dart:io'; // Para verificar Platform.isMacOS
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/custom_button_mini.dart';

class WorkersScreen extends StatefulWidget {
  const WorkersScreen({Key? key}) : super(key: key);

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  bool _showForm = false;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  String _statusFilter = "all"; // "all", "active", "inactive"

  // Lógica de redimensionamento (somente macOS)
  bool _showCardSizeSlider = false;
  double _maxCardWidth = 250;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _handleAddWorker() {
    setState(() {
      _showForm = true;
    });
  }

  void _handleCancel() {
    setState(() {
      _showForm = false;
      _firstNameController.clear();
      _lastNameController.clear();
    });
  }

  Future<void> _handleSave() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os campos antes de salvar.'),
        ),
      );
      return;
    }

    try {
      final docRef = FirebaseFirestore.instance.collection('workers').doc();
      await docRef.set({
        'uniqueId': docRef.id,
        'firstName': firstName,
        'lastName': lastName,
        'status': 'ativo', // valor padrão
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Worker salvo com sucesso!')),
      );

      setState(() {
        _showForm = false;
        _firstNameController.clear();
        _lastNameController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    }
  }

  void _showStatusDialog(
    String docId,
    String firstName,
    String lastName,
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
                    "$firstName $lastName",
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
                        style: const TextStyle(fontSize: 14, color: Colors.black),
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
                      .collection('workers')
                      .doc(docId)
                      .update({'status': newStatus});

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Status atualizado para "$newStatus"!')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao atualizar status: $e')),
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
    // Detecta macOS para exibir eventual botão de colunas
    final bool isMacOS = Platform.isMacOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    // Largura de campos do formulário
    final double fieldMaxWidth = isMacOS ? 600 : double.infinity;

    return BaseLayout(
      title: "Timesheet",
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const TitleBox(title: "Workers"),
            const SizedBox(height: 20),

            // Barra superior: Add Worker e, se macOS, botão de colunas
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_showForm)
                  CustomButton(
                    type: ButtonType.addWorkerButton,
                    onPressed: _handleAddWorker,
                  )
                else
                  const SizedBox.shrink(),

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

            // Se está exibindo formulário
            if (_showForm) ...[
              const SizedBox(height: 20),
              _buildAddWorkerForm(fieldMaxWidth),
            ],

            // Se macOS e se _showCardSizeSlider, exibimos a caixa com slider
            if (isMacOS && _showCardSizeSlider) ...[
              const SizedBox(height: 20),
              _buildSliderForMacOS(),
            ],

            const SizedBox(height: 20),

            // Dropdown de status (All, Active, Inactive) alinhado à direita
            Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: fieldMaxWidth),
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
            ),

            const SizedBox(height: 20),

            // Grid de Workers
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('workers')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Erro ao carregar Workers',
                    style: TextStyle(color: Colors.red),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Text('Nenhum worker encontrado.');
                }

                // Aplica filtro de status
                final filteredDocs = _applyStatusFilter(docs);

                // Ajuste de largura: subtraímos 60 da tela
                final double rawWidth = MediaQuery.of(context).size.width - 60;
                final double effectiveWidth = rawWidth < 0 ? 0.0 : rawWidth;

                return Container(
                  width: effectiveWidth, // precisa ser double
                  child: _buildWorkersGrid(filteredDocs, isMacOS),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Aplica o filtro de status "all", "active", ou "inactive"
  List<DocumentSnapshot> _applyStatusFilter(List<DocumentSnapshot> docs) {
    if (_statusFilter == 'active') {
      return docs
          .where((doc) =>
              (doc.data() as Map<String, dynamic>)['status'] == 'ativo')
          .toList();
    } else if (_statusFilter == 'inactive') {
      return docs
          .where((doc) =>
              (doc.data() as Map<String, dynamic>)['status'] == 'inativo')
          .toList();
    }
    return docs;
  }

  /// Cria a grid, mudando a forma de delegar colunas conforme a plataforma
  Widget _buildWorkersGrid(List<DocumentSnapshot> docs, bool isMacOS) {
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
        final docData = docs[index].data() as Map<String, dynamic>;
        final docId = docs[index].id;
        final firstName = docData['firstName'] ?? '';
        final lastName = docData['lastName'] ?? '';
        final status = docData['status'] ?? 'ativo';

        return GestureDetector(
          onTap: () {
            _showStatusDialog(docId, firstName, lastName, status);
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
                  '$firstName $lastName',
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

  /// Formulário de criação/edição de worker
  Widget _buildAddWorkerForm(double fieldMaxWidth) {
    return Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: fieldMaxWidth),
          child: CustomInputField(
            label: "First name",
            hintText: "Enter first name",
            controller: _firstNameController,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: fieldMaxWidth),
          child: CustomInputField(
            label: "Last name",
            hintText: "Enter last name",
            controller: _lastNameController,
          ),
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
    );
  }

  /// Slider para macOS, limitado a 600px de largura
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
      ),
    );
  }
}
