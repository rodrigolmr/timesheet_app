import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum ButtonType {
  newButton,
  sheetsButton,
  receiptsButton,
  settingsButton,
  cancelButton,
  clearButton,
  nextButton,
  backButton,
  addWorkerButton,
  submitButton,
  editButton,
  pdfButton,
  addUserButton,
  loginButton,
  usersButton,
  workersButton,
  uploadReceiptButton,

  // Novo tipo para navegar até a tela de Cartões
  cardsButton,
}

class CustomButton extends StatelessWidget {
  final ButtonType type;
  final VoidCallback onPressed;

  const CustomButton({
    Key? key,
    required this.type,
    required this.onPressed,
  }) : super(key: key);

  Map<String, dynamic> _getButtonConfig() {
    switch (type) {
      case ButtonType.newButton:
        return {
          'label': 'New',
          'faIcon': FontAwesomeIcons.plus,
          'backgroundColor': const Color(0xFF17DB4E),
          'borderColor': const Color(0xFF17DB4E),
          'iconColor': Colors.white,
          'textColor': Colors.white,
          'height': 60.0,
          'width': 60.0,
          'iconSize': 24.0,
          'textSize': 12.0,
          'lineHeight': 1.0,
          'iconSpacing': 4.0,
          'hasIcon': true,
        };

      case ButtonType.sheetsButton:
        return {
          'label': 'Sheets',
          'faIcon': FontAwesomeIcons.fileExcel,
          'backgroundColor': const Color(0xFF6E44FF),
          'borderColor': const Color(0xFF6E44FF),
          'iconColor': Colors.white,
          'textColor': Colors.white,
          'height': 60.0,
          'width': 60.0,
          'iconSize': 24.0,
          'textSize': 12.0,
          'lineHeight': 1.0,
          'iconSpacing': 4.0,
          'hasIcon': true,
        };

      case ButtonType.receiptsButton:
        return {
          'label': 'Receipts',
          'faIcon': FontAwesomeIcons.fileInvoiceDollar,
          'backgroundColor': const Color(0xFFFF9800),
          'borderColor': const Color(0xFFFF9800),
          'iconColor': Colors.white,
          'textColor': Colors.white,
          'height': 60.0,
          'width': 60.0,
          'iconSize': 24.0,
          'textSize': 12.0,
          'lineHeight': 1.0,
          'iconSpacing': 4.0,
          'hasIcon': true,
        };

      case ButtonType.settingsButton:
        return {
          'label': 'Settings',
          'faIcon': FontAwesomeIcons.cogs,
          'backgroundColor': const Color(0xFF444444),
          'borderColor': const Color(0xFF444444),
          'iconColor': Colors.white,
          'textColor': Colors.white,
          'height': 60.0,
          'width': 60.0,
          'iconSize': 24.0,
          'textSize': 12.0,
          'lineHeight': 1.0,
          'iconSpacing': 4.0,
          'hasIcon': true,
        };

      case ButtonType.cancelButton:
        return {
          'label': 'Cancel',
          'faIcon': FontAwesomeIcons.timesCircle,
          'backgroundColor': const Color(0xFFDE4545),
          'borderColor': const Color(0xFFDE4545),
          'iconColor': Colors.white,
          'textColor': Colors.white,
          'height': 60.0,
          'width': 60.0,
          'iconSize': 24.0,
          'textSize': 12.0,
          'lineHeight': 1.0,
          'iconSpacing': 4.0,
          'hasIcon': true,
        };

      case ButtonType.clearButton:
        return {
          'label': 'Clear',
          'faIcon': FontAwesomeIcons.broom,
          'backgroundColor': const Color(0xFFFAB515),
          'borderColor': const Color(0xFFFAB515),
          'iconColor': Colors.white,
          'textColor': Colors.white,
          'height': 60.0,
          'width': 60.0,
          'iconSize': 24.0,
          'textSize': 12.0,
          'lineHeight': 1.0,
          'iconSpacing': 4.0,
          'hasIcon': true,
        };

      case ButtonType.nextButton:
        return {
          'label': 'Next',
          'faIcon': FontAwesomeIcons.arrowRight,
          'backgroundColor': const Color(0xFF0205D3),
          'borderColor': const Color(0xFF0205D3),
          'iconColor': Colors.white,
          'textColor': Colors.white,
          'height': 60.0,
          'width': 60.0,
          'iconSize': 24.0,
          'textSize': 12.0,
          'lineHeight': 1.0,
          'iconSpacing': 4.0,
          'hasIcon': true,
        };

      case ButtonType.backButton:
        return {
          'label': 'Back',
          'faIcon': FontAwesomeIcons.arrowLeft,
          'backgroundColor': const Color(0xFF0205D3),
          'borderColor': const Color(0xFF0205D3),
          'iconColor': Colors.white,
          'textColor': Colors.white,
          'height': 60.0,
          'width': 60.0,
          'iconSize': 24.0,
          'textSize': 12.0,
          'lineHeight': 1.0,
          'iconSpacing': 4.0,
          'hasIcon': true,
        };

      case ButtonType.addWorkerButton:
        return {
          'label': 'Add',
          'faIcon': FontAwesomeIcons.userPlus,
          'backgroundColor': const Color(0xFF17DB4E),
          'borderColor': const Color(0xFF17DB4E),
          'iconColor': Colors.white,
          'textColor': Colors.white,
          'height': 60.0,
          'width': 60.0,
          'iconSize': 24.0,
          'textSize': 12.0,
          'lineHeight': 1.0,
          'iconSpacing': 4.0,
          'hasIcon': true,
        };

      case ButtonType.submitButton:
        return {
          'label': 'Submit',
          'faIcon': FontAwesomeIcons.checkCircle,
          'backgroundColor': const Color(0xFF17DB4E),
          'borderColor': const Color(0xFF17DB4E),
          'iconColor': Colors.white,
          'textColor': Colors.white,
          'height': 60.0,
          'width': 60.0,
          'iconSize': 24.0,
          'textSize': 12.0,
          'lineHeight': 1.0,
          'iconSpacing': 4.0,
          'hasIcon': true,
        };

      case ButtonType.editButton:
        return {
          'label': 'Edit',
          'faIcon': FontAwesomeIcons.edit,
          'backgroundColor': const Color(0xFF2196F3),
          'borderColor': const Color(0xFF2196F3),
          'iconColor': Colors.white,
          'textColor': Colors.white,
          'height': 60.0,
          'width': 60.0,
          'iconSize': 24.0,
          'textSize': 12.0,
          'lineHeight': 1.0,
          'iconSpacing': 4.0,
          'hasIcon': true,
        };

      case ButtonType.pdfButton:
        return {
          'label': 'PDF',
          'faIcon': FontAwesomeIcons.filePdf,
          'backgroundColor': const Color(0xFFFF0000),
          'borderColor': const Color(0xFFFF0000),
          'iconColor': Colors.white,
          'textColor': Colors.white,
          'height': 60.0,
          'width': 60.0,
          'iconSize': 22.0,
          'textSize': 12.0,
          'lineHeight': 1.0,
          'iconSpacing': 4.0,
          'hasIcon': true,
        };

      case ButtonType.addUserButton:
        return {
          'label': 'Add user',
          'faIcon': FontAwesomeIcons.userPlus,
          'backgroundColor': const Color(0xFF17DB4E),
          'borderColor': const Color(0xFF17DB4E),
          'iconColor': Colors.white,
          'textColor': Colors.white,
          'height': 60.0,
          'width': 60.0,
          'iconSize': 22.0,
          'textSize': 10.0,
          'lineHeight': 1.0,
          'iconSpacing': 4.0,
          'hasIcon': true,
        };

      case ButtonType.loginButton:
        return {
          'label': 'Login',
          'faIcon': FontAwesomeIcons.signInAlt,
          'backgroundColor': const Color(0xFF17DB4E),
          'borderColor': const Color(0xFF17DB4E),
          'iconColor': Colors.white,
          'textColor': Colors.white,
          'height': 60.0,
          'width': 60.0,
          'iconSize': 24.0,
          'textSize': 12.0,
          'lineHeight': 1.0,
          'iconSpacing': 4.0,
          'hasIcon': true,
        };

      case ButtonType.usersButton:
        return {
          'label': 'Users',
          'faIcon': FontAwesomeIcons.users,
          'backgroundColor': const Color(0xFF009688),
          'borderColor': const Color(0xFF009688),
          'iconColor': Colors.white,
          'textColor': Colors.white,
          'height': 60.0,
          'width': 60.0,
          'iconSize': 24.0,
          'textSize': 12.0,
          'lineHeight': 1.0,
          'iconSpacing': 4.0,
          'hasIcon': true,
        };

      case ButtonType.workersButton:
        return {
          'label': 'Workers',
          'faIcon': FontAwesomeIcons.users,
          'backgroundColor': const Color(0xFF6B4423),
          'borderColor': const Color(0xFF6B4423),
          'iconColor': Colors.white,
          'textColor': Colors.white,
          'height': 60.0,
          'width': 60.0,
          'iconSize': 24.0,
          'textSize': 12.0,
          'lineHeight': 1.0,
          'iconSpacing': 4.0,
          'hasIcon': true,
        };

      case ButtonType.uploadReceiptButton:
        return {
          'label': 'Upload',
          'faIcon': FontAwesomeIcons.cloudUploadAlt,
          'backgroundColor': const Color(0xFF0277BD),
          'borderColor': const Color(0xFF0277BD),
          'iconColor': Colors.white,
          'textColor': Colors.white,
          'height': 60.0,
          'width': 60.0,
          'iconSize': 24.0,
          'textSize': 12.0,
          'lineHeight': 1.0,
          'iconSpacing': 4.0,
          'hasIcon': true,
        };

      // <<-- BOTÃO NOVO AQUI (cardsButton) -->
      case ButtonType.cardsButton:
        return {
          'label': 'Cards',
          'faIcon': FontAwesomeIcons.creditCard,
          'backgroundColor': const Color(0xFFD81B60), // cor de fundo (pink)
          'borderColor': const Color(0xFFD81B60), // borda da mesma cor
          'iconColor': Colors.white,
          'textColor': Colors.white,
          'height': 60.0,
          'width': 60.0,
          'iconSize': 24.0,
          'textSize': 12.0,
          'lineHeight': 1.0,
          'iconSpacing': 4.0,
          'hasIcon': true,
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
            width: 3.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5.0),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (config['hasIcon']) ...[
              FaIcon(
                config['faIcon'],
                size: config['iconSize'],
                color: config['iconColor'],
              ),
              SizedBox(height: config['iconSpacing']),
            ],
            Text(
              config['label'],
              style: TextStyle(
                fontSize: config['textSize'],
                fontWeight: FontWeight.bold,
                color: config['textColor'],
                height: config['lineHeight'],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
