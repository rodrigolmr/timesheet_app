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
import 'package:timesheet_app/main.dart';

class TimesheetsScreen extends StatefulWidget {
  const TimesheetsScreen({Key? key}) : super(key: key);

  @override
  State<TimesheetsScreen> createState() => _TimesheetsScreenState();
}

class _TimesheetsScreenState extends State<TimesheetsScreen> with RouteAware {
  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _timesheets = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  final int _pageSize = 35;
  bool _showFilters = false;
  DateTimeRange? _selectedRange;
  List<String> _creatorList = ["Creator"];
  Map<String, String> _usersMap = {};
  String _selectedCreator = "Creator";
  bool _isDescending = true;
  final Map<String, Map<String, dynamic>> _selectedTimesheets = {};
  String? _userId;
  String? _userRole;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _getUserInfo();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent * 0.9 &&
          !_isLoading &&
          _hasMore) {
        _loadMoreTimesheets();
      }
    });
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    _resetAndLoadFirstPage();
  }

  Future<void> _getUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    _userId = user.uid;
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(_userId).get();
    if (userDoc.exists && userDoc.data()?['role'] != null) {
      _userRole = userDoc.data()!['role'] as String;
    } else {
      _userRole = 'User';
    }
    await _loadCreators();
    setState(() {
      _isLoadingUser = false;
    });
    _resetAndLoadFirstPage();
  }

  Future<void> _loadCreators() async {
    final snap = await FirebaseFirestore.instance.collection('users').get();
    final Map<String, String> tempMap = {};
    final List<String> loaded = [];
    for (var doc in snap.docs) {
      final data = doc.data();
      final uid = doc.id;
      final fullName =
          ((data["firstName"] ?? "") + " " + (data["lastName"] ?? "")).trim();
      tempMap[uid] = fullName;
      if (fullName.isNotEmpty) {
        loaded.add(fullName);
      }
    }
    loaded.sort();
    setState(() {
      _creatorList = ["Creator", ...loaded];
      _usersMap = tempMap;
    });
  }

  Query _getBaseQuery() {
    Query query = FirebaseFirestore.instance
        .collection("timesheets")
        .orderBy("date", descending: _isDescending);
    if (_userRole != "Admin") {
      query = query.where("userId", isEqualTo: _userId);
    } else if (_selectedCreator != "Creator") {
      final uid = _usersMap.entries
          .firstWhere((e) => e.value == _selectedCreator,
              orElse: () => const MapEntry("", ""))
          .key;
      if (uid.isNotEmpty) {
        query = query.where("userId", isEqualTo: uid);
      }
    }
    if (_selectedRange != null) {
      query = query
          .where("date",
              isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedRange!.start))
          .where("date",
              isLessThanOrEqualTo: Timestamp.fromDate(_selectedRange!.end));
    }
    return query;
  }

  void _resetAndLoadFirstPage() async {
    setState(() {
      _timesheets.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _loadMoreTimesheets();
  }

  Future<void> _loadMoreTimesheets() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
    });
    Query query = _getBaseQuery().limit(_pageSize);
    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }
    final snap = await query.get();
    final docs = snap.docs;
    if (docs.isNotEmpty) {
      _lastDocument = docs.last;
      _timesheets.addAll(docs);
    }
    if (docs.length < _pageSize) {
      _hasMore = false;
    }
    setState(() {
      _isLoading = false;
    });
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
          _buildTopBarCentered(),
          Visibility(
            visible: false,
            replacement: const SizedBox.shrink(),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0205D3),
                foregroundColor: Colors.white,
              ),
              onPressed: () {},
              child: const Text("Corrigir datas das timesheets"),
            ),
          ),
          if (_showFilters) ...[
            const SizedBox(height: 20),
            _buildFilterContainer(context),
          ],
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 20), // Espaço de 20 pixels acima do ListView
                Expanded(
                  child: _buildTimesheetListView(_timesheets),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          if (!_isLoading && !_hasMore && _timesheets.isEmpty)
            const Center(child: Text("No timesheets found.")),
        ],
      ),
    );
  }

  Widget _buildTopBarCentered() {
    final leftGroup = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CustomButton(
          type: ButtonType.newButton,
          onPressed: () {
            Navigator.pushNamed(context, '/new-time-sheet');
          },
        ),
        const SizedBox(width: 20),
        if (_userRole == "Admin")
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
    );

    final rightGroup = _userRole == "Admin"
        ? Column(
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
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          )
        : const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leftGroup,
            Flexible(
              child: SizedBox(
                width: 100, // Máximo de 100 pixels
                child: const SizedBox.shrink(), // Espaço flexível
              ),
            ),
            rightGroup,
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
                      ? const Text("No date range",
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold))
                      : Text(
                          "${DateFormat('MMM/dd').format(_selectedRange!.start)} - ${DateFormat('MMM/dd').format(_selectedRange!.end)}",
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              _buildSquareArrowButton(
                icon: Icons.arrow_upward,
                isActive: !_isDescending,
                onTap: () {
                  setState(() {
                    _isDescending = false;
                    _resetAndLoadFirstPage();
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
                    _resetAndLoadFirstPage();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                        _resetAndLoadFirstPage();
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CustomMiniButton(
                type: MiniButtonType.clearAllMiniButton,
                onPressed: () {
                  setState(() {
                    _selectedRange = null;
                    _selectedCreator = "Creator";
                    _isDescending = true;
                    _resetAndLoadFirstPage();
                  });
                },
              ),
              CustomMiniButton(
                type: MiniButtonType.applyMiniButton,
                onPressed: () {
                  setState(() {
                    _showFilters = false;
                    _resetAndLoadFirstPage();
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

  Widget _buildTimesheetListView(List<DocumentSnapshot> docs) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        final docId = doc.id;
        final userId = data['userId'] ?? '';
        final userName = _usersMap[userId] ?? "User";
        final jobName = data['jobName'] ?? '';
        final timestamp = data['date'] as Timestamp?;
        final dtParsed = timestamp?.toDate();
        final bool isChecked = _selectedTimesheets.containsKey(docId);

        String day = '--';
        String month = '--';
        if (dtParsed != null) {
          day = DateFormat('d').format(dtParsed);
          month = DateFormat('MMM').format(dtParsed);
        }

        return Padding(
          key: ValueKey(docId),
          padding: const EdgeInsets.only(bottom: 5),
          child: GestureDetector(
            onTap: () {
              Navigator.pushNamed(
                context,
                '/timesheet-view',
                arguments: {'docId': docId},
              );
            },
            child: TimeSheetRowItem(
              day: day,
              month: month,
              jobName: jobName,
              userName: userName,
              initialChecked: isChecked,
              onCheckChanged: (checked) {
                setState(() {
                  if (checked) {
                    _selectedTimesheets[docId] = data;
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
      initialDateRange:
          _selectedRange ??
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
        _resetAndLoadFirstPage();
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
    for (var doc in _timesheets) {
      final data = doc.data() as Map<String, dynamic>;
      _selectedTimesheets[doc.id] = data;
    }
    setState(() {});
  }

  void _handleDeselectAll() {
    setState(() {
      _selectedTimesheets.clear();
    });
  }
}
