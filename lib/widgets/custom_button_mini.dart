import 'package:flutter/material.dart';

// Enum exclusivo para botões mini
enum MiniButtonType {
  saveMiniButton,
  cancelMiniButton,
  clearMiniButton,
  addMiniButton,
  noteMiniButton,
  sortMiniButton,
  deleteMiniButton, // Novo botão
  editMiniButton,   // Novo botão
}

class CustomMiniButton extends StatelessWidget {
  final MiniButtonType type; // Tipo do botão mini
  final VoidCallback onPressed; // Função ao clicar no botão

  const CustomMiniButton({
    Key? key,
    required this.type,
    required this.onPressed,
  }) : super(key: key);

  // Configuração do estilo para botões mini
  Map<String, dynamic> _getButtonConfig() {
    switch (type) {
      case MiniButtonType.saveMiniButton:
        return {
          'label': 'Save',
          'backgroundColor': const Color(0xFF17DB4E),
          'borderColor': const Color(0xFF17DB4E),
          'textColor': Colors.white,
          'width': 60.0,
          'height': 30.0,
        };
      case MiniButtonType.cancelMiniButton:
        return {
          'label': 'Cancel',
          'backgroundColor': const Color(0xFFDE4545),
          'borderColor': const Color(0xFFDE4545),
          'textColor': Colors.white,
          'width': 60.0,
          'height': 30.0,
        };
      case MiniButtonType.clearMiniButton:
        return {
          'label': 'Clear',
          'backgroundColor': const Color(0xFFFAB515),
          'borderColor': const Color(0xFFFAB515),
          'textColor': Colors.white,
          'width': 60.0,
          'height': 30.0,
        };
      case MiniButtonType.addMiniButton:
        return {
          'label': 'Add',
          'backgroundColor': const Color(0xFF17DB4E),
          'borderColor': const Color(0xFF17DB4E),
          'textColor': Colors.white,
          'width': 60.0,
          'height': 30.0,
        };
      case MiniButtonType.noteMiniButton:
        return {
          'label': 'Note',
          'backgroundColor': const Color(0xFF4287F5),
          'borderColor': const Color(0xFF4287F5),
          'textColor': Colors.white,
          'width': 60.0,
          'height': 30.0,
        };
      case MiniButtonType.sortMiniButton:
        return {
          'label': 'Sort',
          'backgroundColor': const Color(0xFF9C27B0),
          'borderColor': const Color(0xFF9C27B0),
          'textColor': Colors.white,
          'width': 60.0,
          'height': 30.0,
        };
      case MiniButtonType.deleteMiniButton: // Novo
        return {
          'label': 'Del',
          'backgroundColor': const Color(0xFFFF0000), // Vermelho
          'borderColor': const Color(0xFFFF0000),
          'textColor': Colors.white,
          'width': 60.0,
          'height': 30.0,
        };
      case MiniButtonType.editMiniButton: // Novo
        return {
          'label': 'Edit',
          'backgroundColor': const Color(0xFF2196F3), // Azul
          'borderColor': const Color(0xFF2196F3),
          'textColor': Colors.white,
          'width': 60.0,
          'height': 30.0,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _getButtonConfig();

    return SizedBox(
      width: config['width'],
      height: config['height'],
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: config['backgroundColor'],
          side: BorderSide(
            color: config['borderColor'],
            width: 4.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5.0),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Center(
          child: Text(
            config['label'],
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.bold,
              color: config['textColor'],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
