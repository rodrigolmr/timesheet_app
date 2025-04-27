import 'dart:io';
import 'dart:convert'; // se formos usar jsonDecode
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_button_mini.dart';
import '../widgets/time_sheet_row.dart';
import '../services/pdf_service.dart';
import 'package:timesheet_app/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/local_timesheet_service.dart';

class TimesheetsScreen extends StatefulWidget {
  const TimesheetsScreen({Key? key}) : super(key: key);

  @override
  State<TimesheetsScreen> createState() => _TimesheetsScreenState();
}

class _TimesheetsScreenState extends State<TimesheetsScreen> with RouteAware {
  final ScrollController _scrollController = ScrollController();

  // Listas de timesheets local
  List<LocalTimesheet> _allLocalTimesheets = [];
  List<LocalTimesheet> _filteredTimesheets = [];

  bool _isLoading = false;
  bool _showFilters = false;
  bool _isDescending = true;

  DateTimeRange? _selectedRange;
  String _selectedCreator = "Creator";
  String _jobNameSearch = "";
  String _tmSearch = "";
  String _materialSearch = "";

  // Dados do usuário
  String? _userId;
  String? _userRole;
  bool _isLoadingUser = true;

  // Para dropdown de creators
  List<String> _creatorList = ["Creator"];
  Map<String, String> _usersMap = {};

  // Variáveis de filtro "candidatas" (antes de Apply)
  bool _candidateIsDescending = true;
  DateTimeRange? _candidateSelectedRange;
  String _candidateSelectedCreator = "Creator";
  String _candidateJobName = "";
  String _candidateTm = "";
  String _candidateMaterial = "";

  // Controladores
  final TextEditingController _jobNameController = TextEditingController();
  final TextEditingController _tmController = TextEditingController();
  final TextEditingController _materialController = TextEditingController();

  // Em vez de Map<String,Map<...>>, agora só armazenamos os IDs selecionados
  final Set<String> _selectedDocIds = {};

  @override
  void initState() {
    super.initState();
    _getUserInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _scrollController.dispose();
    _jobNameController.dispose();
    _tmController.dispose();
    _materialController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _syncLocalTimesheets();
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

    await _loadUsersMap();
    setState(() => _isLoadingUser = false);

    await _syncLocalTimesheets();
  }

  Future<void> _loadUsersMap() async {
    final snap = await FirebaseFirestore.instance.collection('users').get();
    final tempMap = <String, String>{};
    for (var doc in snap.docs) {
      final data = doc.data();
      final uid = doc.id;
      final fullName =
          ((data["firstName"] ?? "") + " " + (data["lastName"] ?? "")).trim();
      tempMap[uid] = fullName.isNotEmpty ? fullName : "User";
    }
    _usersMap = tempMap;
  }

  Future<void> _syncLocalTimesheets() async {
    setState(() => _isLoading = true);

    await LocalTimesheetService.syncWithFirestore();
    final allLocal = LocalTimesheetService.getAllTimesheets();

    setState(() {
      _allLocalTimesheets = allLocal;
      _isLoading = false;
    });

    _buildCreatorListFromTimesheets();
    _applyLocalFilters();
  }

  void _buildCreatorListFromTimesheets() {
    final creatorUidSet = <String>{};
    for (var ts in _allLocalTimesheets) {
      creatorUidSet.add(ts.userId);
    }
    final localCreators = <String>[];
    for (var uid in creatorUidSet) {
      if (_usersMap.containsKey(uid)) {
        localCreators.add(_usersMap[uid]!);
      }
    }
    localCreators.sort();
    setState(() {
      _creatorList = ["Creator", ...localCreators];
    });
  }

  void _applyLocalFilters() {
    List<LocalTimesheet> result = List.from(_allLocalTimesheets);

    if (_userRole != "Admin") {
      result = result.where((ts) => ts.userId == _userId).toList();
    } else {
      if (_selectedCreator != "Creator") {
        final uid = _usersMap.entries
            .firstWhere((e) => e.value == _selectedCreator,
                orElse: () => const MapEntry("", ""))
            .key;
        if (uid.isNotEmpty) {
          result = result.where((ts) => ts.userId == uid).toList();
        }
      }
    }

    if (_selectedRange != null) {
      final start = _selectedRange!.start;
      final end = _selectedRange!.end;
      result = result.where((ts) {
        return ts.date.isAfter(start.subtract(const Duration(days: 1))) &&
            ts.date.isBefore(end.add(const Duration(days: 1)));
      }).toList();
    }

    if (_jobNameSearch.isNotEmpty) {
      final search = _jobNameSearch.toLowerCase();
      result = result.where((ts) => ts.jobName.toLowerCase().contains(search)).toList();
    }
    if (_tmSearch.isNotEmpty) {
      final search = _tmSearch.toLowerCase();
      result = result.where((ts) => ts.tm.toLowerCase().contains(search)).toList();
    }
    if (_materialSearch.isNotEmpty) {
      final search = _materialSearch.toLowerCase();
      result = result.where((ts) => ts.material.toLowerCase().contains(search)).toList();
    }

    result.sort((a, b) {
      if (_isDescending) {
        return b.date.compareTo(a.date);
      } else {
        return a.date.compareTo(b.date);
      }
    });

    setState(() {
      _filteredTimesheets = result;
    });
  }

  void _applyCandidateFilters() {
    setState(() {
      _isDescending = _candidateIsDescending;
      _selectedRange = _candidateSelectedRange;
      _selectedCreator = _candidateSelectedCreator;
      _jobNameSearch = _candidateJobName;
      _tmSearch = _candidateTm;
      _materialSearch = _candidateMaterial;
    });
    _applyLocalFilters();
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
          if (_showFilters) ...[
            const SizedBox(height: 20),
            _buildFilterContainer(context),
          ],
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Expanded(
                  child: _buildTimesheetListView(_filteredTimesheets),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          if (!_isLoading && _filteredTimesheets.isEmpty)
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
            // Ajustamos para checar se _selectedDocIds está vazio
            onPressed: _selectedDocIds.isEmpty
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

    // Repare que a UI exibe "Selected: ${_selectedTimesheets.length}" 
    // mas trocaremos para _selectedDocIds.length (sem mudar o layout).
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
                        _candidateIsDescending = _isDescending;
                        _candidateSelectedRange = _selectedRange;
                        _candidateSelectedCreator = _selectedCreator;
                        _candidateJobName = _jobNameSearch;
                        _candidateTm = _tmSearch;
                        _candidateMaterial = _materialSearch;

                        _jobNameController.text = _candidateJobName;
                        _tmController.text = _candidateTm;
                        _materialController.text = _candidateMaterial;

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
                // Trocamos _selectedTimesheets.length -> _selectedDocIds.length
                "Selected: ${_selectedDocIds.length}",
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
            Flexible(child: SizedBox(width: 100)),
            rightGroup,
          ],
        ),
      ),
    );
  }

  Widget _buildFilterContainer(BuildContext context) {
    final isDateActive = (_selectedRange != null);
    final isCreatorActive =
        (_userRole == "Admin" && _selectedCreator != "Creator");

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Container(
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
            // Range e ordenação
            Row(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDateActive ? Colors.green : const Color(0xFF0277BD),
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
                    child: _candidateSelectedRange == null
                        ? const Text(
                            "No date range",
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          )
                        : Text(
                            "${DateFormat('MMM/dd').format(_candidateSelectedRange!.start)} - ${DateFormat('MMM/dd').format(_candidateSelectedRange!.end)}",
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildSquareArrowButton(
                  icon: Icons.arrow_upward,
                  isActive: !_isDescending,
                  onTap: () {
                    setState(() {
                      _candidateIsDescending = false;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildSquareArrowButton(
                  icon: Icons.arrow_downward,
                  isActive: _isDescending,
                  onTap: () {
                    setState(() {
                      _candidateIsDescending = true;
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
                  border: Border.all(
                    color: isCreatorActive ? Colors.green : const Color(0xFF0205D3),
                    width: isCreatorActive ? 2 : 1,
                  ),
                  boxShadow: isCreatorActive
                      ? [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _candidateSelectedCreator,
                    style: const TextStyle(fontSize: 14, color: Colors.black),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _candidateSelectedCreator = value;
                        });
                      }
                    },
                    items: _creatorList.map((creatorName) {
                      return DropdownMenuItem<String>(
                        value: creatorName,
                        child: Text(creatorName),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            _buildSearchField(
              controller: _jobNameController,
              label: "Job Name",
              hintText: "Job Name",
              isUsed: _jobNameSearch.isNotEmpty,
              onChanged: (val) {
                setState(() {
                  _candidateJobName = val.trim();
                });
              },
            ),
            _buildSearchField(
              controller: _tmController,
              label: "T.M.",
              hintText: "T.M.",
              isUsed: _tmSearch.isNotEmpty,
              onChanged: (val) {
                setState(() {
                  _candidateTm = val.trim();
                });
              },
            ),
            _buildSearchField(
              controller: _materialController,
              label: "Material",
              hintText: "Material",
              isUsed: _materialSearch.isNotEmpty,
              onChanged: (val) {
                setState(() {
                  _candidateMaterial = val.trim();
                });
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CustomMiniButton(
                  type: MiniButtonType.clearAllMiniButton,
                  onPressed: () {
                    setState(() {
                      _candidateSelectedRange = null;
                      _candidateSelectedCreator = "Creator";
                      _candidateIsDescending = true;
                      _candidateJobName = "";
                      _candidateTm = "";
                      _candidateMaterial = "";

                      _isDescending = true;
                      _selectedRange = null;
                      _selectedCreator = "Creator";
                      _jobNameSearch = "";
                      _tmSearch = "";
                      _materialSearch = "";

                      _jobNameController.clear();
                      _tmController.clear();
                      _materialController.clear();
                    });
                    _applyLocalFilters();
                  },
                ),
                CustomMiniButton(
                  type: MiniButtonType.applyMiniButton,
                  onPressed: () {
                    _applyCandidateFilters();
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
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required bool isUsed,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 60,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        boxShadow: isUsed
            ? [
                BoxShadow(
                  color: Colors.green.withOpacity(0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(fontSize: 16, color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black,
          ),
          floatingLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.green,
          ),
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: isUsed ? Colors.green : const Color(0xFF0205D3),
              width: isUsed ? 2 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: isUsed ? Colors.green : const Color(0xFF0205D3),
              width: isUsed ? 2 : 1,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
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

  // Agora só armazenamos docIds em _selectedDocIds
  Widget _buildTimesheetListView(List<LocalTimesheet> localDocs) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: localDocs.length,
      itemBuilder: (context, index) {
        final item = localDocs[index];
        final docId = item.docId;

        final userName = _usersMap[item.userId] ?? "User";
        final jobName = item.jobName;
        final dtParsed = item.date;
        final bool isChecked = _selectedDocIds.contains(docId);

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
                    _selectedDocIds.add(docId);
                  } else {
                    _selectedDocIds.remove(docId);
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
      initialDateRange: _candidateSelectedRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      setState(() {
        _candidateSelectedRange = selected;
      });
    }
  }

  Future<void> _generatePdf() async {
    if (_selectedDocIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No timesheet selected.")),
      );
      return;
    }
    try {
      // Passamos apenas a lista de docIds
      await PdfService().generateTimesheetPdf(_selectedDocIds.toList());
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
    for (var item in _filteredTimesheets) {
      _selectedDocIds.add(item.docId);
    }
    setState(() {});
  }

  void _handleDeselectAll() {
    setState(() {
      _selectedDocIds.clear();
    });
  }
}
