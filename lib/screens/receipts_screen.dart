import 'dart:io';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
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

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({Key? key}) : super(key: key);
  @override
  _ReceiptsScreenState createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> with RouteAware {
  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _receipts = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  final int _pageSize = 15;
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

  bool _showCardSizeSlider = false;
  double _maxCardWidth = 250;

  @override
  void initState() {
    super.initState();
    _getUserInfo();
    _loadCardList();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent * 0.9 &&
          !_isLoading &&
          _hasMore) {
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
  void dispose() {
    routeObserver.unsubscribe(this);
    _scrollController.dispose();
    super.dispose();
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
    _resetAndLoadFirstPage();
  }

  Future<void> _loadUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    final Map<String, String> tempMap = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final fullName =
          "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim();
      if (fullName.isNotEmpty) {
        tempMap[doc.id] = fullName;
      }
    }
    _userMap = tempMap;
    _creatorList = ["Creator", ...tempMap.values.toList()..sort()];
  }

  Future<void> _loadCardList() async {
    final snap = await FirebaseFirestore.instance
        .collection('cards')
        .where('status', isEqualTo: 'ativo')
        .get();
    final loaded = snap.docs
        .map((doc) => doc.data()['last4Digits']?.toString() ?? '')
        .where((last4) => last4.isNotEmpty)
        .toList()
      ..sort();
    _cardList = ["Card", ...loaded];
  }

  Query _getBaseQuery() {
    Query query = FirebaseFirestore.instance.collection("receipts");
    if (_userRole != "Admin") {
      query = query.where("userId", isEqualTo: _userId);
    }
    if (_userRole == "Admin" && _selectedCreator != "Creator") {
      final userId = _userMap.entries
          .firstWhere((entry) => entry.value == _selectedCreator,
              orElse: () => const MapEntry("", ""))
          .key;
      if (userId.isNotEmpty) {
        query = query.where("userId", isEqualTo: userId);
      }
    }
    if (_selectedCard != "Card") {
      query = query.where("cardLast4", isEqualTo: _selectedCard);
    }
    if (_selectedRange != null) {
      query = query
          .where("date",
              isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedRange!.start))
          .where("date",
              isLessThanOrEqualTo: Timestamp.fromDate(_selectedRange!.end));
    }
    query = query.orderBy("date", descending: _isDescending);
    return query;
  }

  void _resetAndLoadFirstPage() async {
    setState(() {
      _receipts.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _loadMoreReceipts();
  }

  Future<void> _loadMoreReceipts() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
    });
    try {
      Query query = _getBaseQuery().limit(_pageSize);
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }
      final snap = await query.get();
      final docs = snap.docs;
      if (docs.isNotEmpty) {
        _lastDocument = docs.last;
        _receipts.addAll(docs);
      }
      if (docs.length < _pageSize) {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint("Error loading receipts: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
    return BaseLayout(
      title: "Time Sheet",
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Center(child: TitleBox(title: "Receipts")),
            const SizedBox(height: 20),
            _buildTopBarWithCardSizeSlider(isMacOS),
            if (_showFilters) ...[
              const SizedBox(height: 20),
              _buildFilterContainer(context),
            ],
            Expanded(child: _buildReceiptsGrid(_receipts, isMacOS)),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            if (!_isLoading && !_hasMore && _receipts.isEmpty)
              const Center(child: Text("No receipts found.")),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBarWithCardSizeSlider(bool isMacOS) {
    return Column(
      children: [
        _buildTopBarCentered(isMacOS),
        if (isMacOS && _showCardSizeSlider)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0FF),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                const Text(
                  "Card Size:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Text("Min"),
                Expanded(
                  child: Slider(
                    value: _maxCardWidth,
                    min: 150,
                    max: 600,
                    divisions: 45,
                    label: null,
                    onChanged: (double value) {
                      setState(() {
                        _maxCardWidth = value;
                      });
                    },
                  ),
                ),
                const Text("Max"),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTopBarCentered(bool isMacOS) {
    // Grupo da esquerda (botões do Mac / Admin + New e PDF)
    final leftGroup = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!isMacOS)
          CustomButton(
            type: ButtonType.newButton,
            onPressed: _scanDocument,
          ),
        if (!isMacOS) const SizedBox(width: 20),
        if (_userRole == "Admin")
          CustomButton(
            type: ButtonType.pdfButton,
            onPressed: _selectedReceipts.isEmpty
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("No receipts selected.")),
                    )
                : _generatePdf,
          ),
        if (isMacOS) const SizedBox(width: 20),
        if (isMacOS)
          CustomButton(
            type: ButtonType.columnsButton,
            onPressed: () {
              setState(() {
                _showCardSizeSlider = !_showCardSizeSlider;
              });
            },
          ),
      ],
    );

    // Grupo da direita (botões do Admin + contagem de selecionados)
    final rightGroup = _userRole == "Admin"
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CustomMiniButton(
                    type: MiniButtonType.sortMiniButton,
                    onPressed: () => setState(() => _showFilters = !_showFilters),
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
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          )
        : const SizedBox();

    // Montamos um Row central, com um Flexible SizedBox entre os dois grupos
    return Row(
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
                      ? const Text(
                          "No date range",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        )
                      : Text(
                          "${DateFormat('MMM/dd').format(_selectedRange!.start)} - ${DateFormat('MMM/dd').format(_selectedRange!.end)}",
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
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
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedCreator = newValue;
                            _resetAndLoadFirstPage();
                          });
                        }
                      },
                      items: _creatorList.map((creator) {
                        return DropdownMenuItem<String>(
                          value: creator,
                          child: Text(creator, overflow: TextOverflow.ellipsis),
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
                    border: Border.all(color: const Color(0xFF0205D3), width: 2),
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
                            _resetAndLoadFirstPage();
                          });
                        }
                      },
                      items: _cardList.map((cardLast4) {
                        return DropdownMenuItem<String>(
                          value: cardLast4,
                          child: Text(cardLast4, overflow: TextOverflow.ellipsis),
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
                onPressed: () => setState(() => _showFilters = false),
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

  Widget _buildReceiptsGrid(List<DocumentSnapshot> docs, bool isMacOS) {
    if (docs.isEmpty) {
      return const Center(child: Text("No receipts found."));
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _maxCardWidth,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.62,
      ),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        final docId = doc.id;
        final creatorName = _userMap[data['userId']] ?? '';
        final amount = data['amount']?.toString() ?? '';
        final last4 = data['cardLast4']?.toString() ?? '0000';
        final imageUrl = data['imageUrl'] ?? '';
        final date = (data['date'] as Timestamp?)?.toDate();
        final isChecked = _selectedReceipts.containsKey(docId);

        String day = '--';
        String month = '--';
        if (date != null) {
          day = DateFormat('d').format(date);
          month = DateFormat('MMM').format(date);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final double baseWidth = 220;
            final double scale = constraints.maxWidth / baseWidth;
            final double last4FontSize = (isMacOS ? 22 : 20) * scale;
            final double creatorFontSize = (isMacOS ? 14 : 12) * scale;
            final double amountFontSize = (isMacOS ? 28 : 26) * scale;
            final double dayFontSize = (isMacOS ? 24 : 22) * scale;
            final double monthFontSize = (isMacOS ? 20 : 18) * scale;

            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFF0205D3), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 15,
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                          : Container(
                              color: const Color(0xFFEEEEEE),
                              child: const Icon(Icons.receipt_long, size: 32, color: Colors.grey),
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 5 / 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                last4,
                                style: TextStyle(
                                  fontSize: last4FontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                creatorName,
                                style: TextStyle(fontSize: creatorFontSize),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        AspectRatio(
                          aspectRatio: 4 / 1,
                          child: Center(
                            child: Text(
                              amount,
                              style: TextStyle(
                                fontSize: amountFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AspectRatio(
                          aspectRatio: 5 / 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 10 * scale,
                                    color: Colors.black,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: day,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: dayFontSize,
                                      ),
                                    ),
                                    const TextSpan(text: " "),
                                    TextSpan(
                                      text: month,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: monthFontSize,
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
                                      _selectedReceipts[docId] = data;
                                    } else {
                                      _selectedReceipts.remove(docId);
                                    }
                                  });
                                },
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _scanDocument() async {
    try {
      List<String>? scannedImages = await CunningDocumentScanner.getPictures();
      if (scannedImages != null && scannedImages.isNotEmpty) {
        String imagePath = scannedImages.first;
        Navigator.pushNamed(context, '/preview-receipt',
            arguments: {'imagePath': imagePath});
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("No document scanned.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Scanning failed: $e")));
    }
  }

  Future<void> _generatePdf() async {
    if (_selectedReceipts.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("No receipt selected.")));
      return;
    }
    try {
      await ReceiptPdfService().generateReceiptsPdf(_selectedReceipts);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PDF generated successfully!")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error generating PDF: $e")));
    }
  }

  void _handleSelectAll() {
    for (var doc in _receipts) {
      final data = doc.data() as Map<String, dynamic>;
      _selectedReceipts[doc.id] = data;
    }
    setState(() {});
  }

  void _handleDeselectAll() {
    setState(() {
      _selectedReceipts.clear();
    });
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
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
}
