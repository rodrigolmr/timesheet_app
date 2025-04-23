import 'dart:io'; // Para verificar Platform.isMacOS
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // para formatar DateTime
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

  late TimesheetData timesheetData; // date agora é DateTime? no model

  bool _editMode = false;
  String _docId = '';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    // Observadores para manter timesheetData atualizado (exceto "date", que vem do DatePicker)
    _jobNameController.addListener(() {
      timesheetData.jobName = _jobNameController.text;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null) {
        _editMode = args['editMode'] ?? false;
        _docId = args['docId'] ?? '';
        timesheetData = args['timesheetData'] ?? TimesheetData();
      } else {
        timesheetData = TimesheetData();
      }

      if (_editMode && _docId.isNotEmpty) {
        _loadExistingTimesheet(_docId);
      } else {
        _populateFieldsFromTimesheetData();
      }

      _initialized = true;
    }
  }

  Future<void> _loadExistingTimesheet(String docId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('timesheets')
          .doc(docId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        // jobName
        _jobNameController.text = data['jobName'] ?? '';
        timesheetData.jobName = data['jobName'] ?? '';

        // data => se for Timestamp, converte para DateTime
        if (data['date'] is Timestamp) {
          final ts = data['date'] as Timestamp;
          timesheetData.date = ts.toDate();
          _dateController.text =
              DateFormat('M/d/yy, EEEE').format(timesheetData.date!);
        } else {
          timesheetData.date = null;
          _dateController.clear();
        }

        _tmController.text = data['tm'] ?? '';
        timesheetData.tm = data['tm'] ?? '';

        _jobSizeController.text = data['jobSize'] ?? '';
        timesheetData.jobSize = data['jobSize'] ?? '';

        _materialController.text = data['material'] ?? '';
        timesheetData.material = data['material'] ?? '';

        _jobDescController.text = data['jobDesc'] ?? '';
        timesheetData.jobDesc = data['jobDesc'] ?? '';

        _foremanController.text = data['foreman'] ?? '';
        timesheetData.foreman = data['foreman'] ?? '';

        _vehicleController.text = data['vehicle'] ?? '';
        timesheetData.vehicle = data['vehicle'] ?? '';

        timesheetData.notes = data['notes'] ?? '';
        timesheetData.userId = data['userId'] ?? '';

        // Workers
        final List<dynamic> workersRaw = data['workers'] ?? [];
        timesheetData.workers = workersRaw.map((item) {
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timesheet não encontrado.')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar timesheet: $error')),
      );
    }
  }

  void _populateFieldsFromTimesheetData() {
    _jobNameController.text = timesheetData.jobName;

    if (timesheetData.date != null) {
      _dateController.text =
          DateFormat('M/d/yy, EEEE').format(timesheetData.date!);
    } else {
      _dateController.clear();
    }

    _tmController.text = timesheetData.tm;
    _jobSizeController.text = timesheetData.jobSize;
    _materialController.text = timesheetData.material;
    _jobDescController.text = timesheetData.jobDesc;
    _foremanController.text = timesheetData.foreman;
    _vehicleController.text = timesheetData.vehicle;
  }

  @override
  void dispose() {
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

      timesheetData.jobName = '';
      timesheetData.date = null;
      timesheetData.tm = '';
      timesheetData.jobSize = '';
      timesheetData.material = '';
      timesheetData.jobDesc = '';
      timesheetData.foreman = '';
      timesheetData.vehicle = '';
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
    // Se for macOS, limitamos a largura em 600
    final bool isMacOS = Platform.isMacOS;
    final double fieldMaxWidth = isMacOS ? 600 : double.infinity;

    return BaseLayout(
      title: "Timesheet",
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          // Center para facilitar o alignment, mas poderia ser Column normal
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

              // JOB NAME
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: fieldMaxWidth),
                child: CustomInputField(
                  controller: _jobNameController,
                  label: "Job Name",
                  hintText: "Job Name",
                  error: _showJobNameError,
                ),
              ),
              const SizedBox(height: 16),

              // Date
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: fieldMaxWidth),
                child: DatePickerInput(
                  controller: _dateController,
                  label: "Date",
                  hintText: "Date",
                  error: _showDateError,
                  onDateSelected: (picked) {
                    timesheetData.date = picked;
                  },
                ),
              ),
              const SizedBox(height: 16),

              // T.M.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: fieldMaxWidth),
                child: CustomInputField(
                  controller: _tmController,
                  label: "T.M.",
                  hintText: "Territorial Manager",
                ),
              ),
              const SizedBox(height: 16),

              // Job Size
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: fieldMaxWidth),
                child: CustomInputField(
                  controller: _jobSizeController,
                  label: "Job Size",
                  hintText: "Job Size",
                ),
              ),
              const SizedBox(height: 16),

              // Material
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: fieldMaxWidth),
                child: CustomMultilineInputField(
                  controller: _materialController,
                  label: "Material",
                  hintText: "Material",
                ),
              ),
              const SizedBox(height: 16),

              // Job Desc
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: fieldMaxWidth),
                child: CustomMultilineInputField(
                  controller: _jobDescController,
                  label: "Job Desc.",
                  hintText: "Job Description",
                  error: _showJobDescError,
                ),
              ),
              const SizedBox(height: 16),

              // Foreman
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: fieldMaxWidth),
                child: CustomInputField(
                  controller: _foremanController,
                  label: "Foreman",
                  hintText: "Foreman",
                ),
              ),
              const SizedBox(height: 16),

              // Vehicle
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: fieldMaxWidth),
                child: CustomInputField(
                  controller: _vehicleController,
                  label: "Vehicle",
                  hintText: "Vehicle's Number",
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomButton(
                    type: ButtonType.cancelButton,
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/home');
                    },
                  ),
                  const SizedBox(width: 16),
                  CustomMiniButton(
                    type: MiniButtonType.clearMiniButton,
                    onPressed: _handleClear,
                  ),
                  const SizedBox(width: 16),
                  CustomButton(
                    type: ButtonType.nextButton,
                    onPressed: _handleNext,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
