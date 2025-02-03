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

  /// Exibe o formulário
  void _handleAddWorker() {
    setState(() {
      _showForm = true;
    });
  }

  /// Limpa os campos e esconde o formulário
  void _handleCancel() {
    setState(() {
      _showForm = false;
      _firstNameController.clear();
      _lastNameController.clear();
    });
  }

  /// Salva no Firebase e, em caso de sucesso, limpa e esconde o formulário
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
      await FirebaseFirestore.instance.collection('workers').add({
        'firstName': firstName,
        'lastName': lastName,
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

            // Se não estiver mostrando o formulário, exibimos apenas o botão Add
            if (!_showForm)
              CustomButton(
                type: ButtonType.addWorkerButton,
                onPressed: _handleAddWorker,
              )
            else
              // Caso contrário, exibimos o formulário
              Column(
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
              ),

            const SizedBox(height: 30),
            // StreamBuilder para listar os Workers em formato de Grid
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

                final double containerWidth =
                    MediaQuery.of(context).size.width - 60;

                return Container(
                  width: containerWidth < 0 ? 0 : containerWidth,
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // 2 colunas
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.5, // Altura como era antes
                    ),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final firstName = data['firstName'] ?? '';
                      final lastName = data['lastName'] ?? '';

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
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
