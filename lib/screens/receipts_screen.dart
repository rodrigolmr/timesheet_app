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
  // Filters
  bool _showFilters = false;
  DateTimeRange? _selectedRange;
  bool _isDescending = true;

  // Pagination
  final int _limit = 15;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  // For the selected receipts (checkboxes)
  final Map<String, Map<String, dynamic>> _selectedReceipts = {};

  // Creator & Cards filters
  Map<String, String> _userMap = {};
  List<String> _creatorList = ["Creator"];
  String _selectedCreator = "Creator";

  List<String> _cardList = ["Card"];
  String _selectedCard = "Card";

  // Current user info
  String _userRole = "User";
  String _userId = "";

  // Storing all loaded receipts (from pagination)
  // Each item has: {
  //   'docId': String,
  //   'data': Map<String,dynamic>,
  //   'parsedDate': DateTime?,
  //   'creatorName': String
  // }
  final List<Map<String, dynamic>> _allReceipts = [];

  // Filtered list that is shown on the screen
  List<Map<String, dynamic>> _currentItems = [];

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

    // After we know userId and userRole, let's load the user list
    await _loadUsers();
    // Then fetch the first page of receipts
    await _fetchReceipts();
    // Then apply local filters
    _applyFilters();
    setState(() {});
  }

  Future<void> _loadUsers() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      final Map<String, String> tempMap = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
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
    // Example of fixed card labels
    setState(() {
      _cardList = [
        "Card",
        "Visa 1111",
        "Master 2222",
        "Amex 1234",
      ];
    });
  }

  // Pagination logic
  Future<void> _fetchReceipts() async {
    if (!_hasMore) return;

    try {
      // Base query
      Query baseQuery = FirebaseFirestore.instance
          .collection("receipts")
          .orderBy("timestamp", descending: true);

      if (_userRole != "Admin") {
        baseQuery = baseQuery.where("userId", isEqualTo: _userId);
      }

      if (_lastDocument != null) {
        baseQuery = baseQuery.startAfterDocument(_lastDocument!);
      }

      baseQuery = baseQuery.limit(_limit);

      final snapshot = await baseQuery.get();

      if (snapshot.docs.isEmpty) {
        _hasMore = false;
      } else {
        _lastDocument = snapshot.docs.last;

        final newItems = snapshot.docs.map((doc) {
          final map = doc.data() as Map<String, dynamic>? ?? {};
          final docId = doc.id;

          final rawDateString = map['date'] ?? '';
          DateTime? parsedDate;
          try {
            // Example parse "M/d/yy"
            parsedDate = DateFormat("M/d/yy").parse(rawDateString);
          } catch (_) {
            parsedDate = null;
          }

          final uid = map['userId'] ?? '';
          final creatorName = _userMap[uid] ?? '';

          return {
            'docId': docId,
            'data': map,
            'parsedDate': parsedDate,
            'creatorName': creatorName,
          };
        }).toList();

        _allReceipts.addAll(newItems);
      }
    } catch (e) {
      debugPrint("Error fetching receipts: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching receipts: $e")),
      );
    }
  }

  // Filter local _allReceipts and produce _currentItems
  void _applyFilters() {
    List<Map<String, dynamic>> items = List.from(_allReceipts);

    // Creator filter
    if (_selectedCreator != "Creator") {
      items = items.where((item) {
        final cName = item['creatorName'] as String;
        return cName == _selectedCreator;
      }).toList();
    }

    // Card filter
    if (_selectedCard != "Card") {
      items = items.where((item) {
        final map = item['data'] as Map<String, dynamic>;
        final cardLabel = map['cardLabel'] ?? '';
        return cardLabel == _selectedCard;
      }).toList();
    }

    // Date range
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

    // Sort asc/desc
    items.sort((a, b) {
      final dtA = a['parsedDate'] as DateTime?;
      final dtB = b['parsedDate'] as DateTime?;
      if (dtA == null && dtB == null) return 0;
      if (dtA == null) return _isDescending ? 1 : -1;
      if (dtB == null) return _isDescending ? -1 : 1;
      final cmp = dtA.compareTo(dtB);
      return _isDescending ? -cmp : cmp;
    });

    _currentItems = items;
    setState(() {});
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
            Expanded(
              child: _buildReceiptsGrid(),
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
          Row(
            children: [
              CustomButton(
                type: ButtonType.newButton,
                onPressed: _scanDocument,
              ),
              const SizedBox(width: 20),
              CustomButton(
                type: ButtonType.pdfButton,
                onPressed: _selectedReceipts.isEmpty
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("No receipts selected.")),
                        );
                      }
                    : _generatePdf,
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
                "Selected: ${_selectedReceipts.length}",
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
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
                    _applyFilters();
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
                    _applyFilters();
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
                            _applyFilters();
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
                            _applyFilters();
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
                  _applyFilters();
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

  Widget _buildReceiptsGrid() {
    if (_currentItems.isEmpty) {
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
      itemCount: _currentItems.length + 1,
      itemBuilder: (context, index) {
        if (index == _currentItems.length) {
          // The "Load more..." container
          if (!_hasMore) {
            return const Center(child: Text("End of the list"));
          } else {
            return InkWell(
              onTap: () async {
                // Load next 15
                await _fetchReceipts();
                // Then apply filters again
                _applyFilters();
              },
              child: Container(
                alignment: Alignment.center,
                color: Colors.grey.withOpacity(0.2),
                child: const Text(
                  "Load more...",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }
        }

        final item = _currentItems[index];
        final docId = item['docId'] as String;
        final map = item['data'] as Map<String, dynamic>;
        final creatorName = item['creatorName'] as String? ?? '';
        final imageUrl = map['imageUrl'] ?? '';
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Scanning failed: $e")));
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
      _applyFilters();
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
      for (var item in _currentItems) {
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
