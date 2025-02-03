// lib/screens/new_time_sheet_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/custom_multiline_input_field.dart';
import '../widgets/date_picker_input.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_button_mini.dart';
import '../models/timesheet_data.dart';

class NewTimeSheetScreen extends StatefulWidget {
  const NewTimeSheetScreen({Key? key}) : super(key: key);

  @override
  State<NewTimeSheetScreen> createState() => _NewTimeSheetScreenState();
}

class _NewTimeSheetScreenState extends State<NewTimeSheetScreen> {
  // Controladores
  final _jobNameController = TextEditingController();
  final _dateController = TextEditingController();
  final _tmController = TextEditingController();
  final _jobSizeController = TextEditingController();
  final _materialController = TextEditingController();
  final _jobDescController = TextEditingController();
  final _foremanController = TextEditingController();
  final _vehicleController = TextEditingController();

  bool _showJobNameError = false;
  bool _showDateError = false;
  bool _showJobDescError = false;

  final _jobNameFocus = FocusNode();
  final _dateFocus = FocusNode();
  final _jobDescFocus = FocusNode();

  late TimesheetData timesheetData;

  // Parâmetros de edição
  bool _editMode = false;
  String _docId = '';

  // Flag para inicializar controllers só UMA vez
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    // Listener para remover erro se tiver foco no campo date
    _dateFocus.addListener(() {
      if (_dateFocus.hasFocus && _showDateError) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _showDateError = false;
            });
          }
        });
      }
    });

    // Listeners que atualizam o timesheetData (mantém os dados sincronizados):
    _jobNameController.addListener(() {
      timesheetData.jobName = _jobNameController.text;
    });
    _dateController.addListener(() {
      timesheetData.date = _dateController.text;
    });
    _tmController.addListener(() {
      timesheetData.tm = _tmController.text;
    });
    _jobSizeController.addListener(() {
      timesheetData.jobSize = _jobSizeController.text;
    });
    _materialController.addListener(() {
      timesheetData.material = _materialController.text;
    });
    _jobDescController.addListener(() {
      timesheetData.jobDesc = _jobDescController.text;
    });
    _foremanController.addListener(() {
      timesheetData.foreman = _foremanController.text;
    });
    _vehicleController.addListener(() {
      timesheetData.vehicle = _vehicleController.text;
    });
  }

  /// Carrega os dados existentes (inclusive workers e note) do Firestore
  Future<void> _loadExistingTimesheet(String docId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('timesheets')
          .doc(docId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        setState(() {
          // Preenche os controladores/fields básicos
          _jobNameController.text = data['jobName'] ?? '';
          _dateController.text = data['date'] ?? '';
          _tmController.text = data['tm'] ?? '';
          _jobSizeController.text = data['jobSize'] ?? '';
          _materialController.text = data['material'] ?? '';
          _jobDescController.text = data['jobDesc'] ?? '';
          _foremanController.text = data['foreman'] ?? '';
          _vehicleController.text = data['vehicle'] ?? '';

          // Carrega a note (se existir)
          timesheetData.notes = data['notes'] ?? '';
        });

        // Carrega lista de workers
        final List<dynamic> workersRaw = data['workers'] ?? [];
        final List<Map<String, String>> loadedWorkers = workersRaw.map((item) {
          final mapItem = item as Map<String, dynamic>;
          return {
            'name': mapItem['name']?.toString() ?? '',
            'start': mapItem['start']?.toString() ?? '',
            'finish': mapItem['finish']?.toString() ?? '',
            'hours': mapItem['hours']?.toString() ?? '',
            'travel': mapItem['travel']?.toString() ?? '',
            'meal': mapItem['meal']?.toString() ?? '',
          };
        }).toList();

        // Atribui ao timesheetData
        timesheetData.workers = loadedWorkers;
      } else {
        // Documento não encontrado no Firestore
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Timesheet não encontrado para edição.')),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar timesheet: $error')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Só roda se não inicializamos ainda
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _editMode = args['editMode'] ?? false;
        _docId = args['docId'] ?? '';
        // Se já existir um TimesheetData vindo de outra tela
        timesheetData = args['timesheetData'] ?? TimesheetData();
      } else {
        timesheetData = TimesheetData();
      }

      if (_editMode && _docId.isNotEmpty) {
        // Carrega os dados existentes (inclusive workers e note) do Firestore
        _loadExistingTimesheet(_docId);
      }

      _initialized = true;
    }
  }

  @override
  void dispose() {
    _jobNameFocus.dispose();
    _dateFocus.dispose();
    _jobDescFocus.dispose();

    _jobNameController.dispose();
    _dateController.dispose();
    _tmController.dispose();
    _jobSizeController.dispose();
    _materialController.dispose();
    _jobDescController.dispose();
    _foremanController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  void _handleClear() {
    setState(() {
      _jobNameController.clear();
      _dateController.clear();
      _tmController.clear();
      _jobSizeController.clear();
      _materialController.clear();
      _jobDescController.clear();
      _foremanController.clear();
      _vehicleController.clear();

      // se quiser limpar notas também, pode fazer
      timesheetData.notes = '';

      _showJobNameError = false;
      _showDateError = false;
      _showJobDescError = false;
    });
  }

  bool _validateRequiredFields() {
    final jobNameEmpty = _jobNameController.text.trim().isEmpty;
    final dateEmpty = _dateController.text.trim().isEmpty;
    final jobDescEmpty = _jobDescController.text.trim().isEmpty;

    setState(() {
      _showJobNameError = jobNameEmpty;
      _showDateError = dateEmpty;
      _showJobDescError = jobDescEmpty;
    });

    return !(jobNameEmpty || dateEmpty || jobDescEmpty);
  }

  void _handleNext() {
    if (_validateRequiredFields()) {
      Navigator.pushNamed(
        context,
        '/add-workers',
        arguments: {
          'editMode': _editMode,
          'docId': _docId,
          'timesheetData': timesheetData,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: "Timesheet",
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Center(child: TitleBox(title: "New Time Sheet")),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                "Job's Info",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Campo obrigatório: Job's Name
            CustomInputField(
              controller: _jobNameController,
              label: "Job Name",
              hintText: "Job Name",
              error: _showJobNameError,
              focusNode: _jobNameFocus,
              onClearError: () {
                setState(() {
                  _showJobNameError = false;
                });
              },
            ),
            const SizedBox(height: 16),

            // DatePickerInput (também é obrigatório)
            DatePickerInput(
              controller: _dateController,
              label: "Date",
              hintText: "Date",
              error: _showDateError,
              focusNode: _dateFocus,
            ),
            const SizedBox(height: 16),

            // T.M.
            CustomInputField(
              controller: _tmController,
              label: "T.M.",
              hintText: "Territorial Manager",
            ),
            const SizedBox(height: 16),

            // Job's Size
            CustomInputField(
              controller: _jobSizeController,
              label: "Job Size",
              hintText: "Job Size",
            ),
            const SizedBox(height: 16),

            // Material (multiline)
            CustomMultilineInputField(
              controller: _materialController,
              label: "Material",
              hintText: "Material",
            ),
            const SizedBox(height: 16),

            // Job's Desc. (obrigatório)
            CustomMultilineInputField(
              controller: _jobDescController,
              label: "Job Desc.",
              hintText: "Job Description",
              error: _showJobDescError,
              focusNode: _jobDescFocus,
              onClearError: () {
                setState(() {
                  _showJobDescError = false;
                });
              },
            ),
            const SizedBox(height: 16),

            // Foreman
            CustomInputField(
              controller: _foremanController,
              label: "Foreman",
              hintText: "Foreman",
            ),
            const SizedBox(height: 16),

            // Vehicle
            CustomInputField(
              controller: _vehicleController,
              label: "Vehicle",
              hintText: "Vehicle's Number",
            ),
            const SizedBox(height: 20),

            // Botões
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CustomButton(
                  type: ButtonType.cancelButton,
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                ),
                Column(
                  children: [
                    CustomMiniButton(
                      type: MiniButtonType.clearMiniButton,
                      onPressed: _handleClear,
                    ),
                  ],
                ),
                CustomButton(
                  type: ButtonType.nextButton,
                  onPressed: _handleNext,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
