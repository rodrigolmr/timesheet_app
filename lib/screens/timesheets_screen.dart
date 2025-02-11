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
  DateTimeRange? _selectedRange;
  String _selectedCreator = "Creator";
  DateTimeRange? _appliedRange;
  String _appliedCreator = "Creator";
  bool _isDescending = true;
  final Map<String, Map<String, dynamic>> _selectedTimesheets = {};

  List<Map<String, dynamic>> _currentItems = [];
  List<String> _creatorList = ["Creator"];
  Map<String, String> _usersMap = {};

  // Variáveis para guardar userId e role
  String? _userId;
  String? _userRole;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  // 1) Carrega dados do usuário atual do Auth
  //   depois pega a role lá na coleção "users".
  Future<void> _loadUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Se não houver usuário, navegue para Login, por exemplo.
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      _userId = user.uid;

      // Agora pega o doc do 'users' pra ler a role
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        _userRole = data['role'] ?? 'User';
      } else {
        // Se não existe, assume User, mas em geral convém tratar.
        _userRole = 'User';
      }

      // 2) Carrega a lista de criadores (para o dropdown) => só depois do role
      await _loadCreators();

      // Tudo carregado
      setState(() {
        _isLoadingUser = false;
      });
    } catch (e) {
      debugPrint("Error loading user info: $e");
      // Opcional: setar flags, exibir erro etc.
      setState(() {
        _isLoadingUser = false;
      });
    }
  }

  // Carrega todos os usuários para montar a _usersMap e _creatorList
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

  @override
  Widget build(BuildContext context) {
    // Se ainda não carregou a role do user, mostra spinner
    if (_isLoadingUser) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
          // 3) Mostra a lista filtrada ou do userId ou de todos
          Expanded(
            child: _buildTimesheetList(),
          ),
        ],
      ),
    );
  }

  // 4) Constrói o StreamBuilder usando where(...) caso seja user
  Widget _buildTimesheetList() {
    // Se role == Admin, mostra todos; se == User, mostra só do userId
    final CollectionReference timesheetsRef =
        FirebaseFirestore.instance.collection('timesheets');

    final Stream<QuerySnapshot> stream = (_userRole == "Admin")
        ? timesheetsRef.snapshots()
        : timesheetsRef.where('userId', isEqualTo: _userId).snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
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

        final List<Map<String, dynamic>> items = data.docs.map((doc) {
          final Map<String, dynamic> mapData =
              doc.data() as Map<String, dynamic>;
          final String docId = doc.id;
          final rawDateString = mapData['date'] ?? '';
          DateTime? parsedDate;
          try {
            parsedDate = DateFormat("M/d/yy, EEEE").parse(rawDateString);
          } catch (_) {
            parsedDate = null;
          }
          return {
            'docId': docId,
            'data': mapData,
            'parsedDate': parsedDate,
          };
        }).toList();

        // Filtros do "Creator"
        if (_appliedCreator != "Creator" && _usersMap.isNotEmpty) {
          items.retainWhere((item) {
            final Map<String, dynamic> mapData =
                item['data'] as Map<String, dynamic>;
            final String userId = mapData['userId'] ?? '';
            final fullName = _usersMap[userId] ?? "";
            return fullName == _appliedCreator;
          });
        }

        // Filtro por data
        if (_appliedRange != null) {
          final start = _appliedRange!.start;
          final end = _appliedRange!.end;
          items.retainWhere((item) {
            final DateTime? dt = item['parsedDate'] as DateTime?;
            if (dt == null) return false;
            return dt.isAfter(start.subtract(const Duration(days: 1))) &&
                dt.isBefore(end.add(const Duration(days: 1)));
          });
        }

        // Ordena asc/desc
        items.sort((a, b) {
          final DateTime? dtA = a['parsedDate'] as DateTime?;
          final DateTime? dtB = b['parsedDate'] as DateTime?;
          if (dtA == null && dtB == null) return 0;
          if (dtA == null) return _isDescending ? 1 : -1;
          if (dtB == null) return _isDescending ? -1 : 1;
          final cmp = dtA.compareTo(dtB);
          return _isDescending ? -cmp : cmp;
        });

        _currentItems = items;

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final Map<String, dynamic> item = items[index];
            final String docId = item['docId'] as String;
            final Map<String, dynamic> mapData =
                item['data'] as Map<String, dynamic>;
            final String userId = mapData['userId'] ?? '';
            final String userName = _usersMap[userId] ?? "User";
            final String jobName = mapData['jobName'] ?? '';
            String day = '--';
            String month = '--';
            final DateTime? dtParsed = item['parsedDate'] as DateTime?;
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
      },
    );
  }

  // Barra superior
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CustomButton(
                  type: ButtonType.newButton,
                  onPressed: () {
                    Navigator.pushNamed(context, '/new-time-sheet');
                  },
                ),
                const SizedBox(width: 20),
                CustomButton(
                  type: ButtonType.pdfButton,
                  onPressed: _generatePdf,
                ),
              ],
            ),
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

  // Container de filtros (Range e Creator)
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
                              fontSize: 15, fontWeight: FontWeight.bold),
                          maxLines: 1,
                        )
                      : Text(
                          "${DateFormat('MMM/dd').format(_selectedRange!.start)} - ${DateFormat('MMM/dd').format(_selectedRange!.end)}",
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CustomMiniButton(
                type: MiniButtonType.clearAllMiniButton,
                onPressed: () {
                  setState(() {
                    _selectedRange = null;
                    _selectedCreator = "Creator";
                    _appliedRange = null;
                    _appliedCreator = "Creator";
                  });
                },
              ),
              CustomMiniButton(
                type: MiniButtonType.applyMiniButton,
                onPressed: () {
                  setState(() {
                    _appliedRange = _selectedRange;
                    _appliedCreator = _selectedCreator;
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
        child: Icon(icon, color: Colors.white, size: 20),
      ),
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
          const SnackBar(content: Text("No timesheet selected.")));
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
    setState(() {
      for (var item in _currentItems) {
        final String docId = item['docId'] as String;
        final Map<String, dynamic> map = item['data'] as Map<String, dynamic>;
        _selectedTimesheets[docId] = map;
      }
    });
  }

  void _handleDeselectAll() {
    setState(() {
      _selectedTimesheets.clear();
    });
  }
}
