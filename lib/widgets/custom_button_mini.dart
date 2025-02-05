import 'package:flutter/material.dart';

enum MiniButtonType {
  saveMiniButton,
  cancelMiniButton,
  clearMiniButton,
  addMiniButton,
  noteMiniButton,
  sortMiniButton,
  deleteMiniButton,
  editMiniButton,
  rangeMiniButton,
  ascMiniButton,
  descMiniButton,
  applyMiniButton,
  clearAllMiniButton,
  closeMiniButton,
  selectAllMiniButton, // <--- Adicionado
  deselectAllMiniButton, // <--- Adicionado
}

class CustomMiniButton extends StatelessWidget {
  final MiniButtonType type;
  final VoidCallback onPressed;

  const CustomMiniButton({
    Key? key,
    required this.type,
    required this.onPressed,
  }) : super(key: key);

  static const double _miniButtonHeight = 25.0;
  static const double _defaultButtonWidth = 60.0;
  static const double _buttonBorderWidth = 4.0;
  static const double _fontSize = 14.0;
  static const double _borderRadius = 5.0;

  Map<String, dynamic> _getButtonConfig() {
    switch (type) {
      case MiniButtonType.saveMiniButton:
        return {
          'label': 'Save',
          'backgroundColor': const Color(0xFF17DB4E),
          'borderColor': const Color(0xFF17DB4E),
          'textColor': Colors.white,
          'width': _defaultButtonWidth,
          'height': _miniButtonHeight,
        };
      case MiniButtonType.cancelMiniButton:
        return {
          'label': 'Cancel',
          'backgroundColor': const Color(0xFFDE4545),
          'borderColor': const Color(0xFFDE4545),
          'textColor': Colors.white,
          'width': _defaultButtonWidth,
          'height': _miniButtonHeight,
        };
      case MiniButtonType.clearMiniButton:
        return {
          'label': 'Clear',
          'backgroundColor': const Color(0xFFFAB515),
          'borderColor': const Color(0xFFFAB515),
          'textColor': Colors.white,
          'width': _defaultButtonWidth,
          'height': _miniButtonHeight,
        };
      case MiniButtonType.addMiniButton:
        return {
          'label': 'Add',
          'backgroundColor': const Color(0xFF17DB4E),
          'borderColor': const Color(0xFF17DB4E),
          'textColor': Colors.white,
          'width': _defaultButtonWidth,
          'height': _miniButtonHeight,
        };
      case MiniButtonType.noteMiniButton:
        return {
          'label': 'Note',
          'backgroundColor': const Color(0xFF4287F5),
          'borderColor': const Color(0xFF4287F5),
          'textColor': Colors.white,
          'width': _defaultButtonWidth,
          'height': _miniButtonHeight,
        };
      case MiniButtonType.sortMiniButton:
        return {
          'label': 'Sort',
          'backgroundColor': const Color(0xFF9C27B0),
          'borderColor': const Color(0xFF9C27B0),
          'textColor': Colors.white,
          'width': _defaultButtonWidth,
          'height': _miniButtonHeight,
        };
      case MiniButtonType.deleteMiniButton:
        return {
          'label': 'Del',
          'backgroundColor': const Color(0xFFFF0000),
          'borderColor': const Color(0xFFFF0000),
          'textColor': Colors.white,
          'width': _defaultButtonWidth,
          'height': _miniButtonHeight,
        };
      case MiniButtonType.editMiniButton:
        return {
          'label': 'Edit',
          'backgroundColor': const Color(0xFF2196F3),
          'borderColor': const Color(0xFF2196F3),
          'textColor': Colors.white,
          'width': _defaultButtonWidth,
          'height': _miniButtonHeight,
        };
      case MiniButtonType.rangeMiniButton:
        return {
          'label': 'Range',
          'backgroundColor': const Color(0xFF0277BD),
          'borderColor': const Color(0xFF0277BD),
          'textColor': Colors.white,
          'width': _defaultButtonWidth,
          'height': _miniButtonHeight,
        };
      case MiniButtonType.ascMiniButton:
        return {
          'label': 'Asc',
          'backgroundColor': const Color(0xFF0205D3),
          'borderColor': const Color(0xFF0205D3),
          'textColor': Colors.white,
          'width': 45.0,
          'height': _miniButtonHeight,
        };
      case MiniButtonType.descMiniButton:
        return {
          'label': 'Desc',
          'backgroundColor': const Color(0xFF0205D3),
          'borderColor': const Color(0xFF0205D3),
          'textColor': Colors.white,
          'width': 50.0,
          'height': _miniButtonHeight,
        };
      case MiniButtonType.applyMiniButton:
        return {
          'label': 'Apply',
          'backgroundColor': const Color(0xFF17DB4E),
          'borderColor': const Color(0xFF17DB4E),
          'textColor': Colors.white,
          'width': _defaultButtonWidth,
          'height': _miniButtonHeight,
        };
      case MiniButtonType.clearAllMiniButton:
        return {
          'label': 'Clear',
          'backgroundColor': const Color(0xFFFF0000),
          'borderColor': const Color(0xFFFF0000),
          'textColor': Colors.white,
          'width': _defaultButtonWidth,
          'height': _miniButtonHeight,
        };
      case MiniButtonType.closeMiniButton:
        return {
          'label': 'Close',
          'backgroundColor': const Color(0xFF757575),
          'borderColor': const Color(0xFF757575),
          'textColor': Colors.white,
          'width': _defaultButtonWidth,
          'height': _miniButtonHeight,
        };
      case MiniButtonType.selectAllMiniButton:
        return {
          'label': 'All',
          'backgroundColor': const Color(0xFF0205D3),
          'borderColor': const Color(0xFF0205D3),
          'textColor': Colors.white,
          'width': 50.0,
          'height': _miniButtonHeight,
        };
      case MiniButtonType.deselectAllMiniButton:
        return {
          'label': 'None',
          'backgroundColor': const Color(0xFF9E9E9E),
          'borderColor': const Color(0xFF9E9E9E),
          'textColor': Colors.white,
          'width': 50.0,
          'height': _miniButtonHeight,
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
            width: _buttonBorderWidth,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Center(
          child: Text(
            config['label'],
            style: TextStyle(
              fontSize: _fontSize,
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
