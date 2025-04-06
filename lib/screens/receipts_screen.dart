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
import 'package:timesheet_app/main.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({Key? key}) : super(key: key);

  @override
  _ReceiptsScreenState createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> with RouteAware {
  bool _showFilters = false;
  DateTimeRange? _selectedRange;
  bool _isDescending = true;
  Map<String, String> _userMap = {};
  List<String> _creatorList = ["Creator"];
  String _selectedCreator = "Creator";
  List<String> _cardList = ["Card"];
  String _selectedCard = "Card";
  final Map<String, Map<String, dynamic>> _selectedReceipts = {};
  String _userRole = "User";
  String _userId = "";
  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _allReceipts = [];
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _getUserInfo();
    _loadCardList();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.9) {
        _loadMoreReceipts();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    _loadFirstPage();
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
    await _loadUsers();
    setState(() {});
    _loadFirstPage();
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
    } catch (e) {}
  }

  Future<void> _loadCardList() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('cards')
          .where('status', isEqualTo: 'ativo')
          .get();
      final List<String> loaded = [];
      for (var doc in snap.docs) {
        final data = doc.data();
        final last4 = data['last4Digits']?.toString() ?? '';
        if (last4.isNotEmpty) {
          loaded.add(last4);
        }
      }
      loaded.sort();
      setState(() {
        _cardList = ["Card", ...loaded];
      });
    } catch (e) {}
  }

  Future<void> _loadFirstPage() async {
    try {
      _allReceipts.clear();
      _lastDoc = null;
      _hasMore = true;
      Query baseQuery = _getBaseQuery();
      final snap = await baseQuery.limit(_pageSize).get();
      _allReceipts.addAll(snap.docs);
      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
      }
      if (snap.docs.length < _pageSize) {
        _hasMore = false;
      }
      setState(() {});
    } catch (e) {}
  }

  Future<void> _loadMoreReceipts() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
    });
    try {
      Query baseQuery = _getBaseQuery();
      final snap =
          await baseQuery.limit(_pageSize).startAfterDocument(_lastDoc!).get();
      _allReceipts.addAll(snap.docs);
      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
      }
      if (snap.docs.length < _pageSize) {
        _hasMore = false;
      }
      setState(() {});
    } catch (e) {} finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Query _getBaseQuery() {
    Query query = FirebaseFirestore.instance
        .collection("receipts")
        .orderBy("timestamp", descending: true);
    if (_userRole != "Admin") {
      query = query.where("userId", isEqualTo: _userId);
    }
    return query;
  }

  List<Map<String, dynamic>> _applyLocalFilters() {
    final List<Map<String, dynamic>> rawItems = [];
    for (var doc in _allReceipts) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final docId = doc.id;
      final rawDateString = data['date'] ?? '';
      DateTime? parsedDate;
      try {
        parsedDate = DateFormat("M/d/yy").parse(rawDateString);
      } catch (_) {
        parsedDate = null;
      }
      final uid = data['userId'] ?? '';
      final creatorName = _userMap[uid] ?? '';
      rawItems.add({
        'docId': docId,
        'data': data,
        'parsedDate': parsedDate,
        'creatorName': creatorName,
      });
    }
    var items = List<Map<String, dynamic>>.from(rawItems);
    if (_selectedCreator != "Creator") {
      items = items.where((item) {
        final cName = item['creatorName'] as String;
        return cName == _selectedCreator;
      }).toList();
    }
    if (_selectedCard != "Card") {
      items = items.where((item) {
        final map = item['data'] as Map<String, dynamic>;
        final cardLast4 = map['cardLast4'] ?? '';
        return cardLast4 == _selectedCard;
      }).toList();
    }
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
  void dispose() {
    routeObserver.unsubscribe(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
    final filteredItems = _applyLocalFilters();
    return BaseLayout(
      title: "Time Sheet",
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Center(child: TitleBox(title: "Receipts")),
            const SizedBox(height: 20),
            _buildTopBar(isMacOS),
            if (_showFilters) ...[
              const SizedBox(height: 20),
              _buildFilterContainer(context),
            ],
            Expanded(
              child: _buildReceiptsGrid(filteredItems),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isMacOS) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CustomButton(
                type: ButtonType.newButton,
                onPressed: isMacOS ? null : _scanDocument,
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
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() {
                            _selectedCard = value;
                          });
                        }
                      },
                      items: _cardList.map((cardLast4) {
                        return DropdownMenuItem<String>(
                          value: cardLast4,
                          child: Text(
                            cardLast4,
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

  Widget _buildReceiptsGrid(List<Map<String, dynamic>> filteredItems) {
    if (filteredItems.isEmpty) {
      return const Center(child: Text("No receipts found."));
    }
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.7,
      ),
      itemCount: filteredItems.length + 1,
      itemBuilder: (context, index) {
        if (index == filteredItems.length) {
          if (_isLoadingMore) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text("Loading more receipts..."),
                ],
              ),
            );
          } else {
            if (_hasMore && filteredItems.isNotEmpty) {
              return Container();
            } else {
              return const Center(
                child: Text("No more receipts."),
              );
            }
          }
        }
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
    final filtered = _applyLocalFilters();
    setState(() {
      for (var item in filtered) {
        final docId = item['docId'] as String;
        final map = item['data'] as Map<String, dynamic>;
        _selectedReceipts[docId] = map;
      }
    });
  }

  void _handleDeselectAll() {
    setState(() {
      _selectedReceipts.clear();
    });
  }
}
