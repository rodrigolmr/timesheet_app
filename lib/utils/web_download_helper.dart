import 'dart:convert';
import 'dart:html' as html;

class WebDownloadHelper {
  static void downloadJson(Map<String, dynamic> data, String filename) {
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final bytes = utf8.encode(jsonString);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final anchor = html.AnchorElement()
      ..href = url
      ..download = filename
      ..style.display = 'none';
    
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }
  
  static void downloadMultipleJsonFiles(Map<String, List<Map<String, dynamic>>> collectionData) {
    // Criar um único arquivo JSON com todas as coleções
    final combinedData = {
      'exportDate': DateTime.now().toIso8601String(),
      'collections': collectionData,
    };
    
    final filename = 'database_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    downloadJson(combinedData, filename);
  }
}