import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _fullName = "";
  String _email = "";
  String _role = "User";
  bool _isLoadingUser = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoadingUser = false;
        });
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final firstName = data["firstName"] ?? "";
        final lastName = data["lastName"] ?? "";
        final fullName = (firstName + " " + lastName).trim();
        final email = data["email"] ?? user.email ?? "";
        final role = data["role"] ?? "User";

        setState(() {
          _fullName = fullName.isEmpty ? "Unknown user" : fullName;
          _email = email;
          _role = role;
          _isLoadingUser = false;
        });
      } else {
        setState(() {
          _fullName = user.email ?? "Unknown";
          _email = user.email ?? "no-email";
          _role = "User";
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      setState(() {
        _fullName = "Error loading user";
        _email = "";
        _role = "";
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _exportDatabaseToJSON() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final Map<String, List<Map<String, dynamic>>> collectionData = {};
      final firestore = FirebaseFirestore.instance;
      int successfulCollections = 0;
      
      // Lista de coleções para exportar
      final collections = ['cards', 'receipts', 'timesheets', 'users', 'workers'];
      
      // Para cada coleção, obter todos os documentos
      for (final collection in collections) {
        try {
          final snapshot = await firestore.collection(collection).get();
          
          if (snapshot.docs.isEmpty) {
            print('Coleção vazia: $collection');
            continue;
          }
          
          // Preparar lista para guardar os documentos da coleção
          final documents = <Map<String, dynamic>>[];
          
          // Adicionar dados de cada documento
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final processedData = <String, dynamic>{};
            
            // Processar cada campo para garantir que seja serializável
            data.forEach((key, value) {
              if (value is Timestamp) {
                processedData[key] = value.toDate().toIso8601String();
              } else if (value is Map || value is List) {
                processedData[key] = value;
              } else {
                processedData[key] = value;
              }
            });
            
            // Adicionar ID do documento
            processedData['docId'] = doc.id;
            documents.add(processedData);
          }
          
          collectionData[collection] = documents;
          successfulCollections++;
        }
        catch (e) {
          print('Erro ao processar coleção $collection: $e');
          continue;
        }
      }
      
      // Criar arquivo JSON para cada coleção
      final directory = await getApplicationDocumentsDirectory();
      final files = <File>[];
      
      for (final entry in collectionData.entries) {
        final jsonContent = entry.value;
        final file = File('${directory.path}/${entry.key}.json');
        await file.writeAsString(jsonEncode(jsonContent));
        files.add(file);
      }
      
      // Se não houver arquivos, mostrar mensagem
      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum dado encontrado para exportar')),
        );
        setState(() {
          _isExporting = false;
        });
        return;
      }

      // Compartilhar arquivos
      final xFiles = files.map((f) => XFile(f.path)).toList();
      await Share.shareXFiles(
        xFiles,
        subject: 'Backup do Banco de Dados',
        text: 'Backup completo do banco de dados em formato JSON',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Banco de dados exportado com sucesso! Coleções exportadas: $successfulCollections')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: "Timesheet",
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const TitleBox(title: "Settings"),
            const SizedBox(height: 20),
            _isLoadingUser
                ? const Center(child: CircularProgressIndicator())
                : _buildUserInfoBox(),
            const SizedBox(height: 20),

            // Botão de backup do banco de dados
            Container(
              width: 330,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0205D3),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                onPressed: _isExporting ? null : _exportDatabaseToJSON,
                child: _isExporting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.0,
                        ),
                      )
                    : const Text(
                        "Baixar Backup do Banco de Dados (JSON)",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Exibe a Row apenas se for Admin:
            if (_role == "Admin")
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomButton(
                    type: ButtonType.usersButton,
                    onPressed: () {
                      Navigator.pushNamed(context, '/users');
                    },
                  ),
                  const SizedBox(width: 20),
                  CustomButton(
                    type: ButtonType.workersButton,
                    onPressed: () {
                      Navigator.pushNamed(context, '/workers');
                    },
                  ),
                  const SizedBox(width: 20),
                  // Novo botão "Cards"
                  CustomButton(
                    type: ButtonType.cardsButton,
                    onPressed: () {
                      Navigator.pushNamed(context, '/cards');
                    },
                  ),
                  const SizedBox(width: 20),
                  // Botão para exportar o banco de dados
                  CustomButton(
                    type: ButtonType.exportButton,
                    onPressed: _isExporting ? () {} : () => _exportDatabaseToJSON(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoBox() {
    return Container(
      width: 330,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFD0),
        border: Border.all(
          color: const Color(0xFF0205D3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fullName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0205D3),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _email,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _role, // "Admin" ou "User"
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
