// lib/screens/review_time_sheet_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_button_mini.dart';
import '../models/timesheet_data.dart';

class ReviewTimeSheetScreen extends StatefulWidget {
  const ReviewTimeSheetScreen({Key? key}) : super(key: key);

  @override
  State<ReviewTimeSheetScreen> createState() => _ReviewTimeSheetScreenState();
}

class _ReviewTimeSheetScreenState extends State<ReviewTimeSheetScreen> {
  bool _showNoteField = false;
  final TextEditingController _noteController = TextEditingController();

  Future<void> _submitTimesheet(
    TimesheetData timesheetData,
    bool editMode,
    String docId,
  ) async {
    try {
      final collection = FirebaseFirestore.instance.collection('timesheets');
      if (editMode && docId.isNotEmpty) {
        // Update
        await collection.doc(docId).update({
          'jobName': timesheetData.jobName,
          'date': timesheetData.date,
          'tm': timesheetData.tm,
          'jobSize': timesheetData.jobSize,
          'material': timesheetData.material,
          'jobDesc': timesheetData.jobDesc,
          'foreman': timesheetData.foreman,
          'vehicle': timesheetData.vehicle,
          'notes': timesheetData.notes,
          'workers': timesheetData.workers,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new
        await collection.add({
          'jobName': timesheetData.jobName,
          'date': timesheetData.date,
          'tm': timesheetData.tm,
          'jobSize': timesheetData.jobSize,
          'material': timesheetData.material,
          'jobDesc': timesheetData.jobDesc,
          'foreman': timesheetData.foreman,
          'vehicle': timesheetData.vehicle,
          'notes': timesheetData.notes,
          'workers': timesheetData.workers,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timesheet salvo com sucesso!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar o timesheet: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final bool editMode = args != null ? (args['editMode'] ?? false) : false;
    final String docId = args != null ? (args['docId'] ?? '') : '';
    final TimesheetData? timesheetData =
        args != null ? (args['timesheetData'] as TimesheetData?) : null;

    return BaseLayout(
      title: "Time Sheet",
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Center(child: TitleBox(title: "Review")),
            const SizedBox(height: 20),

            // Botão BACK
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomButton(
                  type: ButtonType.backButton,
                  onPressed: () {
                    // Volta para AddWorkersScreen, mas usando pushNamed
                    if (timesheetData != null) {
                      Navigator.pushNamed(
                        context,
                        '/add-workers',
                        arguments: {
                          'editMode': editMode,
                          'docId': docId,
                          'timesheetData': timesheetData,
                        },
                      );
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (timesheetData == null)
              const Text("No Timesheet Data found.")
            else
              _buildReviewLayout(timesheetData),

            if (timesheetData != null && timesheetData.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 292,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Note: ",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              timesheetData.notes,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Botão para abrir/editar nota
            if (!_showNoteField)
              CustomMiniButton(
                type: MiniButtonType.noteMiniButton,
                onPressed: () {
                  setState(() {
                    _showNoteField = true;
                    if (timesheetData != null) {
                      _noteController.text = timesheetData.notes;
                    }
                  });
                },
              )
            else
              Column(
                children: [
                  Container(
                    width: 290,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFD0),
                      border: Border.all(
                        color: const Color(0xFF0205D3),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: TextField(
                      controller: _noteController,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "Add a note",
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomMiniButton(
                        type: MiniButtonType.cancelMiniButton,
                        onPressed: () {
                          setState(() {
                            _showNoteField = false;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      CustomMiniButton(
                        type: MiniButtonType.clearMiniButton,
                        onPressed: () {
                          setState(() {
                            _noteController.clear();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      CustomMiniButton(
                        type: MiniButtonType.saveMiniButton,
                        onPressed: () {
                          if (timesheetData != null) {
                            timesheetData.notes = _noteController.text;
                          }
                          setState(() {
                            _showNoteField = false;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),

            const SizedBox(height: 20),

            // SUBMIT
            SizedBox(
              width: 330,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomButton(
                    type: ButtonType.submitButton,
                    onPressed: () async {
                      if (timesheetData != null) {
                        await _submitTimesheet(timesheetData, editMode, docId);
                        // Depois de salvar, volta para Home
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/home',
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewLayout(TimesheetData data) {
    return Container(
      width: 292,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleTimeSheet("TIME SHEET"),
          _drawHorizontalLine(),
          _buildLineJobName("JOB NAME:", data.jobName),
          _drawHorizontalLine(),
          _buildLineDateTmRow(data.date, data.tm),
          _drawHorizontalLine(),
          _buildLineJobSize("JOB SIZE:", data.jobSize),
          _drawHorizontalLine(),
          _buildLineMaterialRow("MATERIAL:", data.material),
          _drawHorizontalLine(),
          _buildLineJobDesc("JOB DESC.:", data.jobDesc),
          _drawHorizontalLine(),
          _buildLineForemanVehicle(data.foreman, data.vehicle),
          _drawHorizontalLine(),
          if (data.workers.isEmpty)
            _buildLineText("No Workers added.", "")
          else
            _buildWorkersTable(data.workers),
        ],
      ),
    );
  }

  Widget _buildTitleTimeSheet(String text) {
    return Container(
      width: 290,
      height: 24,
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _drawHorizontalLine() {
    return Container(height: 0.5, color: Colors.black);
  }

  Widget _buildLineJobName(String label, String value) {
    return SizedBox(
      height: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 227,
            child: Text(
              value,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineDateTmRow(String dateValue, String tmValue) {
    return SizedBox(
      height: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              "DATE:",
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 133,
            child: Text(
              dateValue,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(width: 0.5, color: Colors.black),
          SizedBox(
            width: 31,
            child: Text(
              "T.M.:",
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              tmValue,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineJobSize(String label, String value) {
    return SizedBox(
      height: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 234,
            child: Text(
              value,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineMaterialRow(String label, String value) {
    return SizedBox(
      height: 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 66,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 224,
            child: Text(
              value,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.left,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineJobDesc(String label, String value) {
    return SizedBox(
      height: 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 66,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 224,
            child: Text(
              value,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.left,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineForemanVehicle(String foreman, String vehicle) {
    return SizedBox(
      height: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              "FOREMAN:",
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 118,
            child: Text(
              foreman,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(width: 0.5, color: Colors.black),
          SizedBox(
            width: 52,
            child: Text(
              "VEHICLE:",
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              vehicle,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineText(String label, String value, {bool multiLine = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      constraints: const BoxConstraints(minHeight: 18),
      child: Row(
        crossAxisAlignment:
            multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkersTable(List<Map<String, String>> workers) {
    final rows = <TableRow>[
      TableRow(
        decoration: const BoxDecoration(color: Color(0xFFEFEFEF)),
        children: [
          _buildHeaderCell("NAME", fontSize: 11, textAlign: TextAlign.center),
          _buildHeaderCell("START", fontSize: 8, textAlign: TextAlign.center),
          _buildHeaderCell("FINISH", fontSize: 8, textAlign: TextAlign.center),
          _buildHeaderCell("HOUR", fontSize: 8, textAlign: TextAlign.center),
          _buildHeaderCell("TRAVEL", fontSize: 7, textAlign: TextAlign.center),
          _buildHeaderCell("MEAL", fontSize: 8, textAlign: TextAlign.center),
        ],
      ),
      for (final w in workers)
        TableRow(
          children: [
            _buildDataCell(w['name'] ?? '',
                fontSize: 11, textAlign: TextAlign.left),
            _buildDataCell(w['start'] ?? '',
                fontSize: 11, textAlign: TextAlign.center),
            _buildDataCell(w['finish'] ?? '',
                fontSize: 11, textAlign: TextAlign.center),
            _buildDataCell(w['hours'] ?? '',
                fontSize: 11, textAlign: TextAlign.center),
            _buildDataCell(w['travel'] ?? '',
                fontSize: 11, textAlign: TextAlign.center),
            _buildDataCell(w['meal'] ?? '',
                fontSize: 11, textAlign: TextAlign.center),
          ],
        ),
    ];

    // Adiciona 4 linhas vazias
    for (int i = 0; i < 4; i++) {
      rows.add(
        TableRow(
          children: [
            for (int c = 0; c < 6; c++)
              _buildDataCell('', fontSize: 11, textAlign: TextAlign.left),
          ],
        ),
      );
    }

    return SizedBox(
      width: 290,
      child: Table(
        border: TableBorder(
          top: const BorderSide(width: 0, color: Colors.transparent),
          left: const BorderSide(width: 0, color: Colors.transparent),
          right: const BorderSide(width: 0, color: Colors.transparent),
          bottom: const BorderSide(width: 0, color: Colors.transparent),
          horizontalInside: const BorderSide(width: 0.5, color: Colors.black),
          verticalInside: const BorderSide(width: 0.5, color: Colors.black),
        ),
        columnWidths: const {
          0: FixedColumnWidth(120),
          1: FixedColumnWidth(40),
          2: FixedColumnWidth(40),
          3: FixedColumnWidth(30),
          4: FixedColumnWidth(33),
          5: FixedColumnWidth(28),
        },
        children: rows,
      ),
    );
  }

  Widget _buildHeaderCell(String text,
      {required double fontSize, required TextAlign textAlign}) {
    return Container(
      alignment: Alignment.center,
      height: 18,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Barlow',
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF3B3B3B),
        ),
        textAlign: textAlign,
      ),
    );
  }

  Widget _buildDataCell(String text,
      {required double fontSize, required TextAlign textAlign}) {
    return Container(
      alignment: Alignment.center,
      height: 18,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Barlow',
          fontSize: fontSize,
          color: const Color(0xFF3B3B3B),
        ),
        textAlign: textAlign,
      ),
    );
  }
}
