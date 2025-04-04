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
  List<String> _creatorList = ["Creator"];
  Map<String, String> _usersMap = {};
  String _selectedCreator = "Creator";
  bool _isDescending = true;
  final Map<String, Map<String, dynamic>> _selectedTimesheets = {};

  String? _userId;
  String? _userRole;
  bool _isLoadingUser = true;

  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _allTimesheets = [];
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _getUserInfo();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.9) {
        _loadMoreTimesheets();
      }
    });
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
    if (userDoc.exists) {
      _userRole = userDoc.data()?['role'] ?? 'User';
    } else {
      _userRole = 'User';
    }

    await _loadCreators();

    setState(() {
      _isLoadingUser = false;
    });
    _loadFirstPage();
  }

  Future<void> _loadCreators() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      final Map<String, String> tempMap = {};
      final List<String> loaded = [];
      for (var doc in snap.docs) {
        final data = doc.data();
        final uid = doc.id;
        final firstName = data["firstName"] ?? "";
        final lastName = data["lastName"] ?? "";
        final fullName = (firstName + " " + lastName).trim();
        tempMap[uid] = fullName;
        if (fullName.isNotEmpty) {
          loaded.add(fullName);
        }
      }
      loaded.sort();
      _creatorList = ["Creator", ...loaded];
      _usersMap = tempMap;
    } catch (e) {
      // Trate erros se quiser
    }
  }

  /// Ajuste aqui se seus docs tiverem outro campo de data/hora:
  /// Ex: orderBy("createdAt") ou orderBy("timestamp").
  /// Aqui usamos "date" só para demonstrar.
  Query _getBaseQuery() {
    Query query = FirebaseFirestore.instance
        .collection("timesheets")
        .orderBy("date", descending: true);
    if (_userRole != "Admin") {
      query = query.where("userId", isEqualTo: _userId);
    }
    return query;
  }

  Future<void> _loadFirstPage() async {
    try {
      _allTimesheets.clear();
      _lastDoc = null;
      _hasMore = true;

      final snap = await _getBaseQuery().limit(_pageSize).get();
      _allTimesheets.addAll(snap.docs);

      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
      }
      if (snap.docs.length < _pageSize) {
        _hasMore = false;
      }

      setState(() {});
    } catch (e) {
      // Trate erro se quiser
    }
  }

  Future<void> _loadMoreTimesheets() async {
    if (_isLoadingMore || !_hasMore || _lastDoc == null) return;
    setState(() {
      _isLoadingMore = true;
    });
    try {
      final snap = await _getBaseQuery()
          .limit(_pageSize)
          .startAfterDocument(_lastDoc!)
          .get();

      _allTimesheets.addAll(snap.docs);
      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
      }
      if (snap.docs.length < _pageSize) {
        _hasMore = false;
      }
      setState(() {});
    } catch (e) {
      // Trate erro se quiser
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  List<Map<String, dynamic>> _applyLocalFilters() {
    final List<Map<String, dynamic>> rawItems = [];
    for (var doc in _allTimesheets) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final docId = doc.id;
      final rawDateString = data['date'] ?? '';
      DateTime? parsedDate;
      try {
        parsedDate = DateFormat("M/d/yy, EEEE").parse(rawDateString);
      } catch (_) {
        parsedDate = null;
      }
      rawItems.add({
        'docId': docId,
        'data': data,
        'parsedDate': parsedDate,
      });
    }

    var items = List<Map<String, dynamic>>.from(rawItems);

    // Filtro Creator
    if (_userRole == "Admin" && _selectedCreator != "Creator") {
      items = items.where((item) {
        final mapData = item['data'] as Map<String, dynamic>;
        final uid = mapData['userId'] ?? '';
        final fullName = _usersMap[uid] ?? "";
        return fullName == _selectedCreator;
      }).toList();
    }

    // Filtro Range
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

    // Ordena
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

    final filtered = _applyLocalFilters();

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
            child: _buildTimesheetListView(filtered),
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
            Row(
              children: [
                CustomButton(
                  type: ButtonType.newButton,
                  onPressed: () {
                    Navigator.pushNamed(context, '/new-time-sheet');
                  },
                ),
                const SizedBox(width: 20),
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
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
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

  Widget _buildTimesheetListView(List<Map<String, dynamic>> filtered) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: filtered.length + 1,
      itemBuilder: (context, index) {
        if (index == filtered.length) {
          if (_isLoadingMore) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text("Loading more timesheets..."),
                  ],
                ),
              ),
            );
          } else {
            if (_hasMore && filtered.isNotEmpty) {
              return Container();
            } else {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("No more timesheets."),
                ),
              );
            }
          }
        }

        final item = filtered[index];
        final docId = item['docId'] as String;
        final mapData = item['data'] as Map<String, dynamic>;
        final userId = mapData['userId'] ?? '';
        final userName = _usersMap[userId] ?? "User";
        final jobName = mapData['jobName'] ?? '';
        final dtParsed = item['parsedDate'] as DateTime?;
        String day = '--';
        String month = '--';
        if (dtParsed != null) {
          day = DateFormat('d').format(dtParsed);
          month = DateFormat('MMM').format(dtParsed);
        }
        final bool isChecked = _selectedTimesheets.containsKey(docId);

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
    final filtered = _applyLocalFilters();
    setState(() {
      for (var item in filtered) {
        final docId = item['docId'] as String;
        final mapData = item['data'] as Map<String, dynamic>;
        _selectedTimesheets[docId] = mapData;
      }
    });
  }

  void _handleDeselectAll() {
    setState(() {
      _selectedTimesheets.clear();
    });
  }
}
