import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; // layoutPdf deve existir aqui
import 'package:http/http.dart' as http;

class ReceiptPdfService {
  /// Gera PDF dos recibos e usa layoutPdf pra abrir a tela de impressão
  Future<void> generateReceiptsPdf(
    Map<String, Map<String, dynamic>> selectedReceipts,
  ) async {
    if (selectedReceipts.isEmpty) {
      throw Exception("Nenhum receipt selecionado!");
    }

    // Cria o doc
    final pdf = pw.Document();

    for (final entry in selectedReceipts.entries) {
      final data = entry.value;
      final date = data['date'] ?? '';
      final amount = data['amount'] ?? '';
      final description = data['description'] ?? '';
      final imageUrl = data['imageUrl'] ?? '';

      // Baixa imagem, se existir
      pw.MemoryImage? netImg;
      if (imageUrl.isNotEmpty) {
        try {
          final resp = await http.get(Uri.parse(imageUrl));
          if (resp.statusCode == 200) {
            netImg = pw.MemoryImage(resp.bodyBytes);
          }
        } catch (_) {
          netImg = null;
        }
      }

      // Cria uma página para cada recibo
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("RECEIPT",
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text("Date: $date", style: pw.TextStyle(fontSize: 16)),
                pw.Text("Amount: $amount", style: pw.TextStyle(fontSize: 16)),
                pw.Text("Description: $description",
                    style: pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 20),
                if (netImg != null)
                  pw.Center(
                    child: pw.Image(
                      netImg,
                      width: 300,
                      height: 300,
                      fit: pw.BoxFit.contain,
                    ),
                  )
                else
                  pw.Text("No image or failed to load: $imageUrl"),
              ],
            );
          },
        ),
      );
    }

    // Agora chamamos layoutPdf, igual no timesheet
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
