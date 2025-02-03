// lib/screens/add_workers_screen.dart

import 'package:flutter/material.dart';
import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_button_mini.dart';
import '../widgets/worker_hours_input_section.dart';
import '../models/timesheet_data.dart';

class AddWorkersScreen extends StatefulWidget {
  const AddWorkersScreen({Key? key}) : super(key: key);

  @override
  State<AddWorkersScreen> createState() => _AddWorkersScreenState();
}

class _AddWorkersScreenState extends State<AddWorkersScreen> {
  bool _showWorkerSection = false;
  int? _editIndex;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _finishController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _travelController = TextEditingController();
  final TextEditingController _mealController = TextEditingController();

  final GlobalKey<WorkerHoursInputSectionState> _workerSectionKey =
      GlobalKey<WorkerHoursInputSectionState>();

  // Lista local (exibida na tabela)
  final List<Map<String, String>> _workersData = [];

  bool _showAddWorkerFirstMessage = false;

  // Recebe o mesmo TimesheetData
  late TimesheetData timesheetData;

  // Parâmetros de edição
  bool _editMode = false;
  String _docId = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null) {
      _editMode = args['editMode'] ?? false;
      _docId = args['docId'] ?? '';
      timesheetData = args['timesheetData'] ?? TimesheetData();
    } else {
      timesheetData = TimesheetData();
    }

    // -- SINCRONIZAR LISTAS:
    // Sempre que voltar a esta tela, limpamos _workersData
    // e re-adicionamos o que estiver em timesheetData.workers.
    _workersData.clear();
    _workersData.addAll(timesheetData.workers);
  }

  void _clearAllFields() {
    _nameController.clear();
    _startController.clear();
    _finishController.clear();
    _hoursController.clear();
    _travelController.clear();
    _mealController.clear();
  }

  void _clearOnlyName() {
    _nameController.clear();
    _workerSectionKey.currentState?.resetDropdown();
  }

  bool _validateFields() {
    final nameEmpty = _nameController.text.trim().isEmpty;
    final hoursEmpty = _hoursController.text.trim().isEmpty;

    _workerSectionKey.currentState?.setNameError(nameEmpty);
    _workerSectionKey.currentState?.setHoursError(hoursEmpty);

    return !(nameEmpty || hoursEmpty);
  }

  void _handleAddOrSave() {
    if (!_validateFields()) return;

    final name = _nameController.text.trim();
    final start = _startController.text.trim();
    final finish = _finishController.text.trim();
    final hours = _hoursController.text.trim();
    final travel = _travelController.text.trim();
    final meal = _mealController.text.trim();

    setState(() {
      // Cria o map com os dados do trabalhador
      final workerMap = {
        'name': name,
        'start': start,
        'finish': finish,
        'hours': hours,
        'travel': travel,
        'meal': meal,
      };

      if (_editIndex == null) {
        // ADD
        _workersData.add(workerMap);
        timesheetData.workers.add(workerMap);
        _clearOnlyName();
      } else {
        // SAVE (edição de um item existente)
        _workersData[_editIndex!] = workerMap;
        timesheetData.workers[_editIndex!] = workerMap;
        _editIndex = null;
        _clearOnlyName();
      }
      _showAddWorkerFirstMessage = false;
    });
  }

  void _handleNext() {
    if (_workersData.isEmpty) {
      setState(() {
        _showAddWorkerFirstMessage = true;
      });
      return;
    }
    // Passa timesheetData para Review
    Navigator.pushNamed(
      context,
      '/review-time-sheet',
      arguments: {
        'editMode': _editMode,
        'docId': _docId,
        'timesheetData': timesheetData,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: "Time Sheet",
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Center(child: TitleBox(title: "Add Workers")),
            const SizedBox(height: 20),

            // Linha com Back, Add Worker e Next
            SizedBox(
              width: 330,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomButton(
                    type: ButtonType.backButton,
                    onPressed: () {
                      // Volta para new-time-sheet com timesheetData
                      Navigator.pushNamed(
                        context,
                        '/new-time-sheet',
                        arguments: {
                          'editMode': _editMode,
                          'docId': _docId,
                          'timesheetData': timesheetData,
                        },
                      );
                    },
                  ),
                  CustomButton(
                    type: ButtonType.addWorkerButton,
                    onPressed: () {
                      setState(() {
                        _showAddWorkerFirstMessage = false;
                        _showWorkerSection = true;
                        _editIndex = null;
                      });
                    },
                  ),
                  CustomButton(
                    type: ButtonType.nextButton,
                    onPressed: _handleNext,
                  ),
                ],
              ),
            ),

            // Se não houver nenhum trabalhador, exibe aviso
            if (_showAddWorkerFirstMessage) ...[
              const SizedBox(height: 10),
              const Text(
                "Add a worker first.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Barlow',
                  fontSize: 24,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Se estiver adicionando/ editando trabalhador
            if (_showWorkerSection) ...[
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFEFFE4),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(5),
                    topRight: Radius.circular(5),
                  ),
                ),
                child: WorkerHoursInputSection(
                  key: _workerSectionKey,
                  nameController: _nameController,
                  startController: _startController,
                  finishController: _finishController,
                  hoursController: _hoursController,
                  travelController: _travelController,
                  mealController: _mealController,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 270,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Cancel mini => esconde a seção
                    CustomMiniButton(
                      type: MiniButtonType.cancelMiniButton,
                      onPressed: () {
                        setState(() {
                          _showWorkerSection = false;
                          _editIndex = null;
                        });
                        _clearAllFields();
                        _workerSectionKey.currentState?.resetDropdown();
                      },
                    ),
                    // Clear mini => limpa campos
                    CustomMiniButton(
                      type: MiniButtonType.clearMiniButton,
                      onPressed: () {
                        _clearAllFields();
                        _workerSectionKey.currentState?.resetDropdown();
                      },
                    ),
                    // Add ou Save
                    CustomMiniButton(
                      type: _editIndex == null
                          ? MiniButtonType.addMiniButton
                          : MiniButtonType.saveMiniButton,
                      onPressed: _handleAddOrSave,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Exibe tabela se houver _workersData
            if (_workersData.isNotEmpty) _buildWorkersTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkersTable() {
    return Container(
      width: 340,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 0.5),
      ),
      child: Table(
        border: TableBorder.all(color: Colors.black, width: 0.5),
        columnWidths: const {
          0: FixedColumnWidth(130),
          1: FixedColumnWidth(50),
          2: FixedColumnWidth(50),
          3: FixedColumnWidth(50),
          4: FixedColumnWidth(30),
          5: FixedColumnWidth(30),
        },
        children: [
          TableRow(
            children: [
              _buildHeaderCell("Name"),
              _buildHeaderCell("Start"),
              _buildHeaderCell("Finish"),
              _buildHeaderCell("Hours"),
              _buildHeaderCell("T"),
              _buildHeaderCell("M"),
            ],
          ),
          for (int i = 0; i < _workersData.length; i++)
            _buildDataRow(_workersData[i], i),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Container(
      height: 20,
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Barlow',
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3B3B3B),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  TableRow _buildDataRow(Map<String, String> worker, int index) {
    final name = worker['name'] ?? '';
    final start = worker['start'] ?? '';
    final finish = worker['finish'] ?? '';
    final hours = worker['hours'] ?? '';
    final travel = worker['travel'] ?? '';
    final meal = worker['meal'] ?? '';

    return TableRow(
      children: [
        _buildDataCell(name, isBold: true, index: index),
        _buildDataCell(start, index: index),
        _buildDataCell(finish, index: index),
        _buildDataCell(hours, isBold: true, index: index),
        _buildDataCell(travel, index: index),
        _buildDataCell(meal, index: index),
      ],
    );
  }

  Widget _buildDataCell(String text,
      {bool isBold = false, required int index}) {
    return InkWell(
      onTap: () {
        // Carrega dados para edição
        setState(() {
          _showWorkerSection = true;
          _editIndex = index;
        });
        final w = _workersData[index];
        _nameController.text = w['name'] ?? '';
        _startController.text = w['start'] ?? '';
        _finishController.text = w['finish'] ?? '';
        _hoursController.text = w['hours'] ?? '';
        _travelController.text = w['travel'] ?? '';
        _mealController.text = w['meal'] ?? '';
        _workerSectionKey.currentState?.setDropdownValue(w['name'] ?? '');
      },
      child: Container(
        height: 35,
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Barlow',
            fontSize: 16,
            color: const Color(0xFF3B3B3B),
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
