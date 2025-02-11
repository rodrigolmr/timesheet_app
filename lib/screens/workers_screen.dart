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
                      .collection('workers')
                      .doc(docId)
                      .update({'status': newStatus});

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Status atualizado para "$newStatus"!')),
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
    return BaseLayout(
      title: "Time Sheet",
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const TitleBox(title: "Workers"),
            const SizedBox(height: 20),

            // Botão Add Worker ou formulário
            if (!_showForm)
              CustomButton(
                type: ButtonType.addWorkerButton,
                onPressed: _handleAddWorker,
              )
            else
              _buildAddWorkerForm(),

            const SizedBox(height: 20),

            // Dropdown alinhado à direita
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

                // Aplica o filtro de status
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
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredDocs.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.5,
                    ),
                    itemBuilder: (context, index) {
                      final docData =
                          filteredDocs[index].data() as Map<String, dynamic>;
                      final docId = filteredDocs[index].id;
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
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddWorkerForm() {
    return Column(
      children: [
        CustomInputField(
          label: "First name",
          hintText: "Enter first name",
          controller: _firstNameController,
        ),
        const SizedBox(height: 10),
        CustomInputField(
          label: "Last name",
          hintText: "Enter last name",
          controller: _lastNameController,
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
}
