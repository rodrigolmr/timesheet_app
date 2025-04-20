import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReceiptPdfService {
  /// Gera o PDF dos recibos, exibindo apenas as informações:
  /// - Cartão usado (campo "cardLabel")
  /// - Data
  /// - Amount
  /// - Description
  ///
  /// As informações são organizadas em duas colunas (duas linhas cada) com fonte tamanho 10.
  /// A imagem ocupa o maior espaço possível dentro da página.
  Future<void> generateReceiptsPdf(
      Map<String, Map<String, dynamic>> selectedReceipts) async {
    if (selectedReceipts.isEmpty) {
      throw Exception("Nenhum receipt selecionado!");
    }
    final pdf = pw.Document();

    for (final entry in selectedReceipts.entries) {
      final data = entry.value;
      final dynamic rawDate = data['date'];
      String date = '';
      if (rawDate is Timestamp) {
        date = DateFormat("M/d/yy, EEEE").format(rawDate.toDate());
      } else if (rawDate is String) {
        date = rawDate;
      }
      final amount = data['amount']?.toString() ?? '';
      final description = data['description'] ?? '';
      final cardLabel = data['cardLabel'] ?? '';
      final imageUrl = data['imageUrl'] ?? '';

      // Formata o amount para evitar dois "$"
      final formattedAmount = amount.startsWith("\$") ? amount : "\$$amount";

      // Baixa a imagem, se existir.
      pw.MemoryImage? netImg;
      if (imageUrl.isNotEmpty) {
        try {
          final resp = await http.get(Uri.parse(imageUrl));
          if (resp.statusCode == 200) {
            netImg = pw.MemoryImage(resp.bodyBytes);
          }
        } catch (e) {
          netImg = null;
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Informações organizadas em duas colunas com duas linhas cada.
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Card: $cardLabel",
                              style: pw.TextStyle(fontSize: 10)),
                          pw.Text("Date: $date",
                              style: pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Amount: $formattedAmount",
                              style: pw.TextStyle(fontSize: 10)),
                          pw.Text("Desc: $description",
                              style: pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                // A imagem ocupa o maior espaço possível.
                pw.Expanded(
                  child: netImg != null
                      ? pw.Image(
                          netImg,
                          fit: pw.BoxFit.contain,
                        )
                      : pw.Container(
                          alignment: pw.Alignment.center,
                          child: pw.Text(
                              "No image or failed to load: $imageUrl",
                              style: pw.TextStyle(fontSize: 10)),
                        ),
                ),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
