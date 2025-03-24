// lib/screens/receipts_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:printing/printing.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import '../services/receipt_pdf_service.dart';
import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_button_mini.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({Key? key}) : super(key: key);

  @override
  _ReceiptsScreenState createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  // Filtros
  bool _showFilters = false;
  DateTimeRange? _selectedRange;
  bool _isDescending = true;

  // Para armazenar quem está selecionado via checkbox
  final Map<String, Map<String, dynamic>> _selectedReceipts = {};

  // Creator & Cards filters
  Map<String, String> _userMap = {};
  List<String> _creatorList = ["Creator"];
  String _selectedCreator = "Creator";

  List<String> _cardList = ["Card"];
  String _selectedCard = "Card";

  // Dados do usuário atual
  String _userRole = "User";
  String _userId = "";

  @override
  void initState() {
    super.initState();
    _getUserInfo();
    _loadCardList();
  }

  Future<void> _getUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(_userId)
          .get();
      if (userDoc.exists) {
        _userRole = userDoc.data()?["role"] ?? "User";
      }
    }
    // Depois de saber o userId e role, carregamos a lista de usuários
    await _loadUsers();
    setState(() {});
  }

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
      _userMap = tempMap;
      _creatorList = ["Creator", ...sortedNames];
    } catch (e) {
      debugPrint("Error loading users: $e");
    }
  }

  Future<void> _loadCardList() async {
    // Se quiser buscar cards do Firestore, faça-o aqui
    setState(() {
      _cardList = [
        "Card",
        "Visa 1111",
        "Master 2222",
        "Amex 1234",
      ];
    });
  }

  /// Retorna o stream de recibos, dependendo da role
  Stream<QuerySnapshot> _getReceiptsStream() {
    Query query = FirebaseFirestore.instance
        .collection("receipts")
        .orderBy("timestamp", descending: true);

    if (_userRole != "Admin") {
      query = query.where("userId", isEqualTo: _userId);
    }

    return query.snapshots();
  }

  /// Aplica os filtros (Creator, Card, Range, Asc/Desc) a uma lista local
  List<Map<String, dynamic>> _applyFiltersLocally(
      List<Map<String, dynamic>> source) {
    // Copiamos a lista para não modificar o original
    var items = List<Map<String, dynamic>>.from(source);

    // Filtro Creator
    if (_selectedCreator != "Creator") {
      items = items.where((item) {
        final cName = item['creatorName'] as String;
        return cName == _selectedCreator;
      }).toList();
    }

    // Filtro Card
    if (_selectedCard != "Card") {
      items = items.where((item) {
        final map = item['data'] as Map<String, dynamic>;
        final cardLabel = map['cardLabel'] ?? '';
        return cardLabel == _selectedCard;
      }).toList();
    }

    // Filtro Date Range
    if (_selectedRange != null) {
      final start = _selectedRange!.start;
      final end = _selectedRange!.end;
      items = items.where((item) {
        final dt = item['parsedDate'] as DateTime?;
        if (dt == null) return false;
        return dt.isAfter(start.subtract(const Duration(days: 1))) &&
            dt.isBefore(end.add(const Duration(days: 1)));
      }).toList();
    }

    // Ordenação Asc/Desc
    items.sort((a, b) {
      final dtA = a['parsedDate'] as DateTime?;
      final dtB = b['parsedDate'] as DateTime?;
      if (dtA == null && dtB == null) return 0;
      if (dtA == null) return _isDescending ? 1 : -1;
      if (dtB == null) return _isDescending ? -1 : 1;
      final cmp = dtA.compareTo(dtB);
      return _isDescending ? -cmp : cmp;
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: "Time Sheet",
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Center(child: TitleBox(title: "Receipts")),
            const SizedBox(height: 20),
            _buildTopBar(),
            if (_showFilters) ...[
              const SizedBox(height: 20),
              _buildFilterContainer(context),
            ],
            // Aqui usamos StreamBuilder
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getReceiptsStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text("Error: ${snapshot.error}"),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Monta a lista local "rawItems"
                  final docs = snapshot.data?.docs ?? [];
                  final List<Map<String, dynamic>> rawItems = [];

                  for (var doc in docs) {
                    final map = doc.data() as Map<String, dynamic>? ?? {};
                    final docId = doc.id;

                    final rawDateString = map['date'] ?? '';
                    DateTime? parsedDate;
                    try {
                      parsedDate = DateFormat("M/d/yy").parse(rawDateString);
                    } catch (_) {
                      parsedDate = null;
                    }

                    final uid = map['userId'] ?? '';
                    final creatorName = _userMap[uid] ?? '';

                    rawItems.add({
                      'docId': docId,
                      'data': map,
                      'parsedDate': parsedDate,
                      'creatorName': creatorName,
                    });
                  }

                  // Aplica filtros localmente
                  final filtered = _applyFiltersLocally(rawItems);

                  if (filtered.isEmpty) {
                    return const Center(child: Text("No receipts found."));
                  }

                  // Renderiza o grid
                  return _buildReceiptsGrid(filtered);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botões à esquerda
          Row(
            children: [
              CustomButton(
                type: ButtonType.newButton,
                onPressed: _scanDocument,
              ),
              const SizedBox(width: 20),
              if (_userRole == "Admin") ...[
                CustomButton(
                  type: ButtonType.pdfButton,
                  onPressed: _selectedReceipts.isEmpty
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("No receipts selected."),
                            ),
                          );
                        }
                      : _generatePdf,
                ),
              ],
            ],
          ),

          // Botões à direita, somente se admin
          if (_userRole == "Admin") ...[
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CustomMiniButton(
                      type: MiniButtonType.sortMiniButton,
                      onPressed: () {
                        setState(() {
                          _showFilters = !_showFilters;
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    CustomMiniButton(
                      type: MiniButtonType.selectAllMiniButton,
                      onPressed: _handleSelectAll,
                    ),
                    const SizedBox(width: 4),
                    CustomMiniButton(
                      type: MiniButtonType.deselectAllMiniButton,
                      onPressed: _handleDeselectAll,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Selected: ${_selectedReceipts.length}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterContainer(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
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
                          "${DateFormat('MMM/dd').format(_selectedRange!.start)} - ${DateFormat('MMM/dd').format(_selectedRange!.end)}",
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
                onTap: () {
                  setState(() {
                    _isDescending = false;
                  });
                },
              ),
              const SizedBox(width: 8),
              _buildSquareArrowButton(
                icon: Icons.arrow_downward,
                isActive: _isDescending,
                onTap: () {
                  setState(() {
                    _isDescending = true;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border:
                        Border.all(color: const Color(0xFF0205D3), width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCreator,
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedCreator = newValue;
                          });
                        }
                      },
                      items: _creatorList.map((creator) {
                        return DropdownMenuItem<String>(
                          value: creator,
                          child: Text(
                            creator,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border:
                        Border.all(color: const Color(0xFF0205D3), width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCard,
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedCard = newValue;
                          });
                        }
                      },
                      items: _cardList.map((cardName) {
                        return DropdownMenuItem<String>(
                          value: cardName,
                          child: Text(
                            cardName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                    _selectedCard = "Card";
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

  /// Constrói o Grid de recibos com base em [filteredItems],
  /// já filtrados no builder.
  Widget _buildReceiptsGrid(List<Map<String, dynamic>> filteredItems) {
    if (filteredItems.isEmpty) {
      return const Center(child: Text("No receipts found."));
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.7,
      ),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        final docId = item['docId'] as String;
        final map = item['data'] as Map<String, dynamic>;
        final creatorName = item['creatorName'] as String? ?? '';
        final bool isChecked = _selectedReceipts.containsKey(docId);
        final amount = map['amount']?.toString() ?? '';
        final last4 = map['cardLast4']?.toString() ?? '0000';
        final dt = item['parsedDate'] as DateTime?;
        String day = '--';
        String month = '--';
        if (dt != null) {
          day = DateFormat('d').format(dt);
          month = DateFormat('MMM').format(dt);
        }

        final imageUrl = map['imageUrl'] ?? '';

        return GestureDetector(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/receipt-viewer',
              arguments: {
                'imageUrl': imageUrl,
              },
            );
          },
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(
                color: Color(0xFF0205D3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Se quisesse remover a imagem, só remover esse Expanded
                Expanded(
                  child: imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : Container(
                          color: const Color(0xFFEEEEEE),
                          child: const Icon(
                            Icons.receipt_long,
                            size: 32,
                            color: Colors.grey,
                          ),
                        ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        last4,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        creatorName,
                        style: const TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        amount,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black,
                              ),
                              children: [
                                TextSpan(
                                  text: day,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const TextSpan(text: " "),
                                TextSpan(
                                  text: month,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Checkbox(
                            value: isChecked,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedReceipts[docId] = map;
                                } else {
                                  _selectedReceipts.remove(docId);
                                }
                              });
                            },
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _scanDocument() async {
    try {
      List<String>? scannedImages = await CunningDocumentScanner.getPictures();
      if (scannedImages != null && scannedImages.isNotEmpty) {
        String imagePath = scannedImages.first;
        Navigator.pushNamed(
          context,
          '/preview-receipt',
          arguments: {'imagePath': imagePath},
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

  Future<void> _generatePdf() async {
    if (_selectedReceipts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No receipt selected.")),
      );
      return;
    }
    try {
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

  void _handleSelectAll() {
    setState(() {
      // Precisamos pegar o que estiver filtrado no grid
      // e adicionar ao _selectedReceipts
      // Mas note que chamamos _buildReceiptsGrid(...) passando [filteredItems]
      // Logo, podemos armazenar esses items localmente ou "ousar" nada
      // Para simplificar, podemos re-aplicar local aqui também, mas sem setState
      // Nesse caso, iremos recuperar com a StreamBuilder ou armazenar
      // de antemão. Se quisermos "fingir" que todos estão ali, segue:
      // O approach mais correto: re-filtrar no local:
      // ...
      // Por simplicidade, iremos apenas iterar no _buildReceiptsGrid
      // => ou passamos a lista "filtered" ao handle. Veja abaixo:
    });
    // Exemplo rápido: se quiser manter a mesma approach, ok...
  }

  void _handleDeselectAll() {
    setState(() {
      _selectedReceipts.clear();
    });
  }
}
