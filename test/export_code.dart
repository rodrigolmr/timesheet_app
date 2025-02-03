import 'dart:io';

void main() {
  final directory =
      Directory('lib'); // Caminho da pasta principal dos seus arquivos .dart
  final outputFile =
      File('project_code_dump.txt'); // Arquivo onde o código será salvo

  if (!directory.existsSync()) {
    print("Diretório 'lib' não encontrado.");
    return;
  }

  final buffer = StringBuffer();
  buffer.writeln("// ============================");
  buffer.writeln("// Código exportado do projeto");
  buffer.writeln("// ============================\n");

  directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .forEach((file) {
    buffer.writeln(
        "// ==========================================================");
    buffer.writeln("// File: ${file.path}");
    buffer.writeln(
        "// ==========================================================");
    buffer.writeln(File(file.path).readAsStringSync());
    buffer.writeln("\n");
  });

  outputFile.writeAsStringSync(buffer.toString());
  print("Código exportado para 'project_code_dump.txt'");
}
