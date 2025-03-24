import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Range de datas
  DateTimeRange? _selectedRange;

  // Filtro por "Creator"
  List<String> _creatorList = ["Creator"];
  Map<String, String> _usersMap = {};
  String _selectedCreator = "Creator";

  // Ordenação asc/desc
  bool _isDescending = true;

  // Armazena timesheets selecionados via checkbox
  final Map<String, Map<String, dynamic>> _selectedTimesheets = {};

  // Dados do usuário atual
  String? _userId;
  String? _userRole;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  /// Carrega dados do usuário (id e role) e lista de criadores
  Future<void> _loadUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Se não houver user, vá para login
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      _userId = user.uid;

      // Lê role
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        _userRole = data['role'] ?? 'User';
      } else {
        _userRole = 'User';
      }

      // Carrega todos os usuários para compor _creatorList
      await _loadCreators();

      setState(() {
        _isLoadingUser = false;
      });
    } catch (e) {
      debugPrint("Error loading user info: $e");
      setState(() {
        _isLoadingUser = false;
      });
    }
  }

  /// Busca usuários para montar a lista "Creator"
  Future<void> _loadCreators() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      final List<String> loaded = [];
      final Map<String, String> usersMap = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final firstName = data["firstName"] ?? "";
        final lastName = data["lastName"] ?? "";
        final fullName = (firstName + " " + lastName).trim();
        usersMap[doc.id] = fullName;
        if (fullName.isNotEmpty) {
          loaded.add(fullName);
        }
      }
      loaded.sort();
      _creatorList = ["Creator", ...loaded];
      _usersMap = usersMap;
    } catch (e) {
      debugPrint("Error loading creators: $e");
    }
  }

  /// Retorna o stream de timesheets (todos se admin, só do user se user normal)
  Stream<QuerySnapshot> _getTimesheetsStream() {
    final collection = FirebaseFirestore.instance.collection('timesheets');
    if (_userRole == "Admin") {
      return collection.snapshots();
    } else {
      return collection.where('userId', isEqualTo: _userId).snapshots();
    }
  }

  /// Aplica os filtros localmente (creator, range, asc/desc)
  List<Map<String, dynamic>> _applyFiltersLocally(
      List<Map<String, dynamic>> source) {
    var items = List<Map<String, dynamic>>.from(source);

    // Filtro por Creator
    if (_selectedCreator != "Creator" && _usersMap.isNotEmpty) {
      items = items.where((item) {
        final mapData = item['data'] as Map<String, dynamic>;
        final userId = mapData['userId'] ?? '';
        final fullName = _usersMap[userId] ?? "";
        return fullName == _selectedCreator;
      }).toList();
    }

    // Filtro por Range
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

    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return BaseLayout(
      title: "Timesheet",
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
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getTimesheetsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text("Error loading data: ${snapshot.error}"),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                final List<Map<String, dynamic>> rawItems = [];

                // Converte docs
                for (var doc in docs) {
                  final mapData = doc.data() as Map<String, dynamic>;
                  final docId = doc.id;
                  final rawDateString = mapData['date'] ?? '';
                  DateTime? parsedDate;
                  try {
                    parsedDate =
                        DateFormat("M/d/yy, EEEE").parse(rawDateString);
                  } catch (_) {
                    parsedDate = null;
                  }
                  rawItems.add({
                    'docId': docId,
                    'data': mapData,
                    'parsedDate': parsedDate,
                  });
                }

                // Aplica filtros localmente
                final filtered = _applyFiltersLocally(rawItems);

                if (filtered.isEmpty) {
                  return const Center(child: Text("No timesheets found."));
                }

                // Renderiza a lista de timesheets
                return _buildTimesheetListView(filtered);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Botões à esquerda
            Row(
              children: [
                CustomButton(
                  type: ButtonType.newButton,
                  onPressed: () {
                    Navigator.pushNamed(context, '/new-time-sheet');
                  },
                ),
                const SizedBox(width: 20),

                // Só mostra PDF se for Admin
                if (_userRole == "Admin") ...[
                  CustomButton(
                    type: ButtonType.pdfButton,
                    onPressed: _selectedTimesheets.isEmpty
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("No timesheet selected."),
                              ),
                            );
                          }
                        : _generatePdf,
                  ),
                ],
              ],
            ),

            // Botões de Filter, SelectAll, DeselectAll e contagem
            // (Aqui poderíamos exibir apenas se Admin também,
            // mas no seu código original, aparecia para todos)
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
                  "Selected: ${_selectedTimesheets.length}",
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
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
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Range + arrow up/down
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

          // DropDown do Creator (só exibir se Admin ou se quiser)
          if (_userRole == "Admin") ...[
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
          ],

          // Botoes de Clear/Apply/Close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CustomMiniButton(
                type: MiniButtonType.clearAllMiniButton,
                onPressed: () {
                  setState(() {
                    _selectedRange = null;
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

  /// Constrói a lista de timesheets (já filtrados) em um ListView
  Widget _buildTimesheetListView(List<Map<String, dynamic>> filtered) {
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final docId = item['docId'] as String;
        final mapData = item['data'] as Map<String, dynamic>;
        final userId = mapData['userId'] ?? '';
        // Precisa do fullName?
        final userName = _usersMap[userId] ?? "User";
        final jobName = mapData['jobName'] ?? '';

        // data parse
        String day = '--';
        String month = '--';
        final dtParsed = item['parsedDate'] as DateTime?;
        if (dtParsed != null) {
          day = DateFormat('d').format(dtParsed);
          month = DateFormat('MMM').format(dtParsed);
        }

        final bool isChecked = _selectedTimesheets.containsKey(docId);

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
              userName: userName,
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

  void _handleSelectAll() {
    // Se quisermos "selecionar tudo que está sendo exibido no momento"
    // Precisamos recalcular a lista filtrada do snapshot atual.
    // Se estivermos guardando local, podemos mandar um setState
    // Exemplo (com stream approach) => Precisaríamos da lista 'filtered'
    // no build. Ex:
    // Modo simples: não implementado
  }

  void _handleDeselectAll() {
    setState(() {
      _selectedTimesheets.clear();
    });
  }
}
