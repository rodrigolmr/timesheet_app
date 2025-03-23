// lib/screens/timesheet_view_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_button.dart';
import '../models/timesheet_data.dart';

class TimesheetViewScreen extends StatelessWidget {
  const TimesheetViewScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Recebe o docId (e possivelmente outros dados) via arguments
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String docId =
        args != null && args.containsKey('docId') ? args['docId'] : '';

    return BaseLayout(
      title: "Timesheet",
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Título principal
            const Center(
              child: TitleBox(title: "Timesheet"),
            ),
            const SizedBox(height: 20),

            // Row com Back e Edit buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomButton(
                  type: ButtonType.backButton,
                  onPressed: () {
                    Navigator.pop(context); // Volta para a tela anterior
                  },
                ),
                const SizedBox(width: 20),
                CustomButton(
                  type: ButtonType.editButton,
                  onPressed: () {
                    if (docId.isNotEmpty) {
                      Navigator.pushNamed(
                        context,
                        '/new-time-sheet',
                        arguments: {'editMode': true, 'docId': docId},
                      );
                    } else {
                      // Exibe mensagem de erro
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('ID do timesheet inválido para edição.')),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Se não tiver docId, exibimos uma mensagem de erro
            if (docId.isEmpty)
              const Text("Documento não encontrado ou ID vazio.")
            else
              // Carrega dados do Firestore via StreamBuilder
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('timesheets')
                    .doc(docId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Erro ao carregar: ${snapshot.error}');
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Se o doc não existir ou estiver sem dados
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Text(
                        "Este timesheet não foi encontrado no Firestore.");
                  }

                  // DocumentSnapshot
                  final doc = snapshot.data!;

                  final jobName = doc.get('jobName') ?? '';
                  final date = doc.get('date') ?? '';
                  final tm = doc.get('tm') ?? '';
                  final jobSize = doc.get('jobSize') ?? '';
                  final material = doc.get('material') ?? '';
                  final jobDesc = doc.get('jobDesc') ?? '';
                  final foreman = doc.get('foreman') ?? '';
                  final vehicle = doc.get('vehicle') ?? '';
                  final notes = doc.get('notes') ?? '';

                  // "workers" é salvo como List de Map<String, dynamic> no Firestore,
                  // mas precisamos convertê-lo corretamente para List<Map<String, String>>.
                  final List<dynamic> workersRaw = doc.get('workers') ?? [];
                  final List<Map<String, String>> workers =
                      workersRaw.map((item) {
                    // Aqui convertemos 'item' para Map<String,dynamic>, depois
                    // montamos Map<String,String> usando toString() para evitar erro.
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

                  // Monta objeto TimesheetData (opcionalmente)
                  final timesheetData = TimesheetData(
                    jobName: jobName,
                    date: date,
                    tm: tm,
                    jobSize: jobSize,
                    material: material,
                    jobDesc: jobDesc,
                    foreman: foreman,
                    vehicle: vehicle,
                    notes: notes,
                    workers: workers,
                  );

                  // Constrói o layout (mesmo estilo de Review)
                  return _buildReviewLayout(timesheetData);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Copiando o layout de "Review" para exibir os dados do timesheet
  Widget _buildReviewLayout(TimesheetData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Container principal
        Container(
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
        ),

        // Se houver nota, exibe fora do container
        if (data.notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
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
                        data.notes,
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
        ],
      ],
    );
  }

  // ============== Métodos Auxiliares p/ Layout ===============

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

  // Exibe tabela com workers
  Widget _buildWorkersTable(List<Map<String, String>> workers) {
    final rows = <TableRow>[
      // Cabeçalho
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
      // Dados
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

    // Acrescenta 4 linhas vazias
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
