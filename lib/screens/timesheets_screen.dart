import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_button_mini.dart';
import '../widgets/time_sheet_row.dart';
import '../services/pdf_service.dart';

class TimesheetsScreen extends StatefulWidget {
  const TimesheetsScreen({Key? key}) : super(key: key);

  @override
  State<TimesheetsScreen> createState() => _TimesheetsScreenState();
}

class _TimesheetsScreenState extends State<TimesheetsScreen> {
  bool _showFilters = false;

  /// Intervalo de datas escolhido no filtro
  DateTimeRange? _selectedRange;

  /// Indica se a ordenação é decrescente (default) ou não
  bool _isDescending = true;

  /// Map de timesheets selecionados para gerar PDF
  final Map<String, Map<String, dynamic>> _selectedTimesheets = {};

  /// Lista de nomes de “criadores” (Foreman) (com “Creator” como placeholder)
  List<String> _creatorList = ["Creator"];
  String _selectedCreator = "Creator";

  @override
  void initState() {
    super.initState();
    _loadCreators();
  }

  /// Carrega os nomes (Foreman) da coleção "users"
  Future<void> _loadCreators() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      final List<String> loaded = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final firstName = data["firstName"] ?? "";
        final lastName = data["lastName"] ?? "";
        final fullName = (firstName + " " + lastName).trim();
        if (fullName.isNotEmpty) {
          loaded.add(fullName);
        }
      }
      loaded.sort();
      setState(() {
        _creatorList = ["Creator", ...loaded];
      });
    } catch (e) {
      debugPrint("Error loading creators: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: "Time Sheet",
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Center(child: TitleBox(title: "Timesheets")),
          const SizedBox(height: 20),

          _buildTopBar(),

          if (_showFilters) ...[
            const SizedBox(height: 20),
            _buildFilterContainer(context),
          ],

          // Exibe a lista de timesheets (filtrada e ordenada em memória)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('timesheets')
                  .snapshots(), // sem orderBy
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text("Error loading data: ${snapshot.error}"),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data;
                if (data == null || data.docs.isEmpty) {
                  return const Center(child: Text("No timesheets found."));
                }

                // 1) Convertemos docs para uma lista manipulável
                var items = data.docs.map((doc) {
                  final mapData = doc.data() as Map<String, dynamic>;
                  final docId = doc.id;

                  // Pega o campo "date" (string)
                  final rawDateString = mapData['date'] ?? '';

                  // Parse para DateTime
                  DateTime? parsedDate;
                  try {
                    // Ajuste o formato se precisar (ex.: "M/d/yy, EEEE")
                    parsedDate =
                        DateFormat("M/d/yy, EEEE").parse(rawDateString);
                  } catch (e) {
                    // Se der erro, parsedDate fica nulo
                  }

                  return {
                    'doc': doc,
                    'docId': docId,
                    'data': mapData,
                    'dateString': rawDateString, // só pra referência
                    'parsedDate': parsedDate,
                  };
                }).toList();

                // 2) Filtro por "Foreman" se != "Creator"
                if (_selectedCreator != "Creator") {
                  items = items.where((item) {
                    final foreman = item['data']['foreman'] ?? '';
                    return foreman == _selectedCreator;
                  }).toList();
                }

                // 3) Filtro por data (usando _selectedRange, e parsedDate)
                if (_selectedRange != null) {
                  final start = _selectedRange!.start;
                  final end = _selectedRange!.end;

                  items = items.where((item) {
                    final dt = item['parsedDate'] as DateTime?;
                    if (dt == null) return false; // se não parseou, filtra fora
                    return dt
                            .isAfter(start.subtract(const Duration(days: 1))) &&
                        dt.isBefore(end.add(const Duration(days: 1)));
                  }).toList();
                }

                // 4) Ordena (asc/desc) pelo parsedDate
                items.sort((a, b) {
                  final dtA = a['parsedDate'] as DateTime?;
                  final dtB = b['parsedDate'] as DateTime?;
                  // caso dtA ou dtB seja null
                  if (dtA == null && dtB == null) return 0;
                  if (dtA == null) return _isDescending ? 1 : -1;
                  if (dtB == null) return _isDescending ? -1 : 1;

                  // se ambos existem
                  final cmp = dtA.compareTo(dtB); // asc
                  return _isDescending ? -cmp : cmp;
                });

                // 5) Monta a ListView
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final docId = item['docId'] as String;
                    final mapData = item['data'] as Map<String, dynamic>;
                    final foreman = mapData['foreman'] ?? '';
                    final jobName = mapData['jobName'] ?? '';

                    // parse data => day / month
                    String day = '--';
                    String month = '--';
                    final dtParsed = item['parsedDate'] as DateTime?;
                    if (dtParsed != null) {
                      day = DateFormat('d').format(dtParsed);
                      month = DateFormat('MMM').format(dtParsed);
                    }

                    // se já estava marcado (pdf)
                    final bool isChecked =
                        _selectedTimesheets.containsKey(docId);

                    return GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/timesheet-view',
                          arguments: {'docId': docId},
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: TimeSheetRowItem(
                          day: day,
                          month: month,
                          jobName: jobName,
                          userName: foreman.isNotEmpty ? foreman : "User",
                          initialChecked: isChecked,
                          onCheckChanged: (checked) {
                            setState(() {
                              if (checked) {
                                _selectedTimesheets[docId] = mapData;
                              } else {
                                _selectedTimesheets.remove(docId);
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

  /// Barra superior (New, PDF, Sort)
  Widget _buildTopBar() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          CustomButton(
            type: ButtonType.newButton,
            onPressed: () {
              Navigator.pushNamed(context, '/new-time-sheet');
            },
          ),
          CustomButton(
            type: ButtonType.pdfButton,
            onPressed: _generatePdf,
          ),
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

  /// Container do filtro
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
          // Linha 1: Range / datas / asc / desc
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

  /// Botão quadrado 40x40 com apenas a seta
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

  /// Abre o DateRangePicker
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

  /// Gera PDF a partir dos timesheets selecionados
  Future<void> _generatePdf() async {
    if (_selectedTimesheets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No timesheet selected.")),
      );
      return;
    }
    try {
      await PdfService().generateTimesheetPdf(_selectedTimesheets);
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
