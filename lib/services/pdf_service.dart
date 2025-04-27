import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/local_timesheet_service.dart';

class PdfService {
  Future<void> generateTimesheetPdf(List<String> docIds) async {
    if (docIds.isEmpty) {
      throw Exception("Nenhum timesheet selecionado!");
    }

    try {
      final pdf = pw.Document();

      for (var docId in docIds) {
        // Buscar do Hive o LocalTimesheet correspondente
        final item = _getLocalTimesheet(docId);
        if (item == null) {
          // Se não achar, pode ignorar ou dar erro
          continue;
        }

        // Conversão de data
        final dateStr = DateFormat("M/d/yy, EEEE").format(item.date);

        final jobName = item.jobName;
        final tm = item.tm;
        final jobSize = item.jobSize;
        final material = item.material;
        final jobDesc = item.jobDesc;
        final foreman = item.foreman;
        final vehicle = item.vehicle;
        final notes = item.notes;

        // Parse workers
        // Lembrando que item.workers é getter que decodifica JSON
        final workers = item.workers.map((w) {
          return {
            'name': w['name'] ?? '',
            'start': w['start'] ?? '',
            'finish': w['finish'] ?? '',
            'hours': w['hours'] ?? '',
            'travel': w['travel'] ?? '',
            'meal': w['meal'] ?? '',
          };
        }).toList();

        // Constrói o PDF
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.letter,
            margin: const pw.EdgeInsets.all(20),
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Column(
                  children: [
                    _buildTitle(),
                    _buildJobDetails(
                      jobName,
                      dateStr,
                      tm,
                      jobSize,
                      material,
                      jobDesc,
                      foreman,
                      vehicle,
                    ),
                    _buildTable(workers),
                    if (notes.isNotEmpty) _buildNotes(notes),
                  ],
                ),
              );
            },
          ),
        );
      }

      final bytes = await pdf.save();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/timesheets.pdf');
      await file.writeAsBytes(bytes);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      throw Exception("Erro ao gerar PDF: $e");
    }
  }

  // Método helper para encontrar o LocalTimesheet pelo docId
  LocalTimesheet? _getLocalTimesheet(String docId) {
    final box = LocalTimesheetService.box;
    try {
      return box.values.firstWhere((ts) => ts.docId == docId);
    } catch (_) {
      return null;
    }
  }

  pw.Widget _buildTitle() {
    return pw.Container(
      width: 500,
      height: 50,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
        ),
      ),
      child: pw.Text(
        'TIMESHEET',
        style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _buildJobDetails(
    String jobName,
    String date,
    String tm,
    String jobSize,
    String material,
    String jobDesc,
    String foreman,
    String vehicle,
  ) {
    return pw.Container(
      width: 500,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.5),
      ),
      child: pw.Column(
        children: [
          _buildRow1Col("Job name:", jobName),
          _buildRow2Cols("Date:", date, "T. M.:", tm),
          _buildRow1Col("Job size:", jobSize),
          _buildRow1ColExpandable("Material:", material),
          _buildRow1ColExpandable("Job description:", jobDesc),
          _buildRow2Cols("Foreman:", foreman, "Vehicle:", vehicle),
        ],
      ),
    );
  }

  pw.Widget _buildRow1Col(String label, String value) {
    return pw.Container(
      height: 22,
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 500,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Row(
              children: [
                pw.Text(label,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(width: 4),
                pw.Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildRow1ColExpandable(String label, String value) {
    return pw.Container(
      constraints: pw.BoxConstraints(minHeight: 22),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 4),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  pw.Widget _buildRow2Cols(
      String label1, String value1, String label2, String value2) {
    return pw.Container(
      height: 22,
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 250,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Row(
              children: [
                pw.Text(label1,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(width: 4),
                pw.Text(value1),
              ],
            ),
          ),
          pw.Container(
            width: 250,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Row(
              children: [
                pw.Text(label2,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(width: 4),
                pw.Text(value2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTable(List<Map<String, dynamic>> workers) {
    final headers = ['Name', 'Start', 'Finish', 'Hours', 'Travel', 'Meal'];
    final data = workers.map((w) {
      return [
        w['name'] ?? '',
        w['start'] ?? '',
        w['finish'] ?? '',
        w['hours'] ?? '',
        w['travel'] ?? '',
        w['meal'] ?? '',
      ];
    }).toList();

    while (data.length < 7) {
      data.add(['', '', '', '', '', '']);
    }

    return pw.Container(
      width: 500,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.5),
      ),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
        columnWidths: {
          0: pw.FixedColumnWidth(200),
          1: pw.FixedColumnWidth(60),
          2: pw.FixedColumnWidth(60),
          3: pw.FixedColumnWidth(60),
          4: pw.FixedColumnWidth(60),
          5: pw.FixedColumnWidth(60),
        },
        children: [
          pw.TableRow(
            children: headers.map((h) {
              return pw.Container(
                height: 22,
                alignment: pw.Alignment.center,
                child: pw.Text(
                  h,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              );
            }).toList(),
          ),
          ...data.map((row) {
            return pw.TableRow(
              children: row.map((cell) {
                return pw.Container(
                  height: 22,
                  alignment: pw.Alignment.center,
                  child: pw.Text(cell),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  pw.Widget _buildNotes(String notes) {
    return pw.Container(
      width: 500,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.black, width: 0.5),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Note:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(notes),
          ),
        ],
      ),
    );
  }
}
