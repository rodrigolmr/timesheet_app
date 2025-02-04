import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';

// Importa o NOVO service de recibos, que usa layoutPdf
import '../services/receipt_pdf_service.dart';

import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_button_mini.dart';
import '../widgets/time_sheet_row.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({Key? key}) : super(key: key);

  @override
  _ReceiptsScreenState createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  bool _showFilters = false;
  DateTimeRange? _selectedRange;
  bool _isDescending = true;

  // Mapa de recibos selecionados para gerar PDF
  final Map<String, Map<String, dynamic>> _selectedReceipts = {};

  // userId -> Nome do usuário
  Map<String, String> _userMap = {};

  // Lista de nomes de criador (placeholder "Creator")
  List<String> _creatorList = ["Creator"];
  String _selectedCreator = "Creator";

  String _userRole = "User";
  String _userId = "";

  @override
  void initState() {
    super.initState();
    _getUserInfo();
    _loadUsers();
  }

  /// Carrega informações do usuário atual (role, userId)
  Future<void> _getUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(_userId)
          .get();
      if (userDoc.exists) {
        setState(() {
          _userRole = userDoc.data()?["role"] ?? "User";
        });
      }
    }
  }

  /// Carrega lista de users e monta userMap + _creatorList
  Future<void> _loadUsers() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      final Map<String, String> tempMap = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userId = doc.id;
        final firstName = data['firstName'] ?? '';
        final lastName = data['lastName'] ?? '';
        final fullName = (firstName + ' ' + lastName).trim();
        if (fullName.isNotEmpty) {
          tempMap[userId] = fullName;
        }
      }
      final sortedNames = tempMap.values.toList()..sort();
      setState(() {
        _userMap = tempMap;
        _creatorList = ["Creator", ...sortedNames];
      });
    } catch (e) {
      debugPrint("Error loading users: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: "Time Sheet",
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Center(child: TitleBox(title: "Receipts")),
          const SizedBox(height: 20),

          // Barra superior (New, PDF, Sort)
          _buildTopBar(),

          if (_showFilters) ...[
            const SizedBox(height: 20),
            _buildFilterContainer(context),
          ],

          // StreamBuilder para receipts
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection("receipts").snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text("Error loading receipts: ${snapshot.error}"),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data;
                if (data == null || data.docs.isEmpty) {
                  return const Center(child: Text("No receipts found."));
                }

                // Converte docs para lista manipulável
                var items = data.docs.map((doc) {
                  final map = doc.data() as Map<String, dynamic>;
                  final docId = doc.id;

                  // parse date
                  final rawDateString = map['date'] ?? '';
                  DateTime? parsedDate;
                  try {
                    parsedDate = DateFormat("M/d/yy").parse(rawDateString);
                  } catch (_) {
                    parsedDate = null;
                  }

                  final userId = map['userId'] ?? '';
                  final creatorName = _userMap[userId] ?? '';

                  return {
                    'docId': docId,
                    'data': map,
                    'parsedDate': parsedDate,
                    'creatorName': creatorName,
                  };
                }).toList();

                // Se user != Admin, filtra userId == _userId
                if (_userRole != "Admin") {
                  items = items.where((item) {
                    final map = item['data'] as Map<String, dynamic>;
                    return (map['userId'] ?? '') == _userId;
                  }).toList();
                }

                // Filtro Creator
                if (_selectedCreator != "Creator") {
                  items = items.where((item) {
                    final cName = item['creatorName'] as String;
                    return cName == _selectedCreator;
                  }).toList();
                }

                // Filtro de data
                if (_selectedRange != null) {
                  final start = _selectedRange!.start;
                  final end = _selectedRange!.end;
                  items = items.where((item) {
                    final dt = item['parsedDate'] as DateTime?;
                    if (dt == null) return false;
                    return dt
                            .isAfter(start.subtract(const Duration(days: 1))) &&
                        dt.isBefore(end.add(const Duration(days: 1)));
                  }).toList();
                }

                // Ordena asc/desc
                items.sort((a, b) {
                  final dtA = a['parsedDate'] as DateTime?;
                  final dtB = b['parsedDate'] as DateTime?;
                  if (dtA == null && dtB == null) return 0;
                  if (dtA == null) return _isDescending ? 1 : -1;
                  if (dtB == null) return _isDescending ? -1 : 1;
                  final cmp = dtA.compareTo(dtB);
                  return _isDescending ? -cmp : cmp;
                });

                // Exibe
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final docId = item['docId'] as String;
                    final map = item['data'] as Map<String, dynamic>;
                    final imageUrl = map['imageUrl'] ?? '';
                    final dateStr = map['date'] ?? '';
                    final creatorName = item['creatorName'] as String? ?? '';

                    String day = '--';
                    String month = '--';
                    final dt = item['parsedDate'] as DateTime?;
                    if (dt != null) {
                      day = DateFormat('d').format(dt);
                      month = DateFormat('MMM').format(dt);
                    }

                    final bool isChecked = _selectedReceipts.containsKey(docId);
                    final rowTitle = "Receipt: $dateStr";

                    return GestureDetector(
                      onTap: () {
                        // Abre viewer
                        Navigator.pushNamed(
                          context,
                          '/receipt-viewer',
                          arguments: {
                            'docId': docId,
                            'imageUrl': imageUrl,
                          },
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: TimeSheetRowItem(
                          day: day,
                          month: month,
                          jobName: rowTitle,
                          userName:
                              creatorName.isNotEmpty ? creatorName : "User",
                          initialChecked: isChecked,
                          onCheckChanged: (checked) {
                            setState(() {
                              if (checked) {
                                _selectedReceipts[docId] = map;
                              } else {
                                _selectedReceipts.remove(docId);
                              }
                            });
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Botão New => scanner
          CustomButton(
            type: ButtonType.newButton,
            onPressed: () async {
              await _scanDocument(context);
            },
          ),
          // Botão PDF => gera PDF via ReceiptPdfService
          CustomButton(
            type: ButtonType.pdfButton,
            onPressed: _generatePdf,
          ),
          // Botão Sort => exibe container de filtro
          CustomMiniButton(
            type: MiniButtonType.sortMiniButton,
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterContainer(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0FF),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Linha 1: Range + data + asc + desc
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0277BD),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 40),
                ),
                onPressed: () => _pickDateRange(context),
                child: const Text("Range"),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _selectedRange == null
                      ? const Text(
                          "No date range",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                        )
                      : Text(
                          "${DateFormat('MMM/dd').format(_selectedRange!.start)} - "
                          "${DateFormat('MMM/dd').format(_selectedRange!.end)}",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              _buildSquareArrowButton(
                icon: Icons.arrow_upward,
                isActive: !_isDescending,
                onTap: () => setState(() => _isDescending = false),
              ),
              const SizedBox(width: 8),
              _buildSquareArrowButton(
                icon: Icons.arrow_downward,
                isActive: _isDescending,
                onTap: () => setState(() => _isDescending = true),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Linha 2: Dropdown Creator
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFF0205D3), width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCreator,
                style: const TextStyle(fontSize: 14, color: Colors.black),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCreator = value;
                    });
                  }
                },
                items: _creatorList.map((creator) {
                  return DropdownMenuItem<String>(
                    value: creator,
                    child: Text(creator),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Linha 3: [Clear], [Apply], [Close]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CustomMiniButton(
                type: MiniButtonType.clearAllMiniButton,
                onPressed: () {
                  setState(() {
                    _selectedRange = null;
                    _isDescending = true;
                    _selectedCreator = "Creator";
                  });
                },
              ),
              CustomMiniButton(
                type: MiniButtonType.applyMiniButton,
                onPressed: () {
                  setState(() {
                    _showFilters = false;
                  });
                },
              ),
              CustomMiniButton(
                type: MiniButtonType.closeMiniButton,
                onPressed: () {
                  setState(() {
                    _showFilters = false;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSquareArrowButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0205D3) : Colors.grey,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  /// Plugin de scanner
  Future<void> _scanDocument(BuildContext context) async {
    try {
      List<String>? scannedImages = await CunningDocumentScanner.getPictures();
      if (scannedImages != null && scannedImages.isNotEmpty) {
        String imagePath = scannedImages.first;
        Navigator.pushNamed(
          context,
          '/preview-receipt',
          arguments: {
            'imagePath': imagePath,
          },
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

  /// DateRangePicker
  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      setState(() {
        _selectedRange = selected;
      });
    }
  }

  /// Chama o ReceiptPdfService e gera PDF
  Future<void> _generatePdf() async {
    if (_selectedReceipts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No receipt selected.")),
      );
      return;
    }

    try {
      // Chama layoutPdf dentro do service (igual timesheet faz)
      await ReceiptPdfService().generateReceiptsPdf(_selectedReceipts);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PDF generated successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error generating PDF: $e")),
      );
    }
  }
}
