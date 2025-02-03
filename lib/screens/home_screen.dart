import 'package:flutter/material.dart';
import '../widgets/logo_text.dart';
import '../widgets/base_layout.dart';
import '../widgets/custom_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: "Timesheet",
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 70),
            const LogoText(),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 15,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  CustomButton(
                    type: ButtonType.sheetsButton,
                    onPressed: () {
                      Navigator.pushNamed(context, '/timesheets');
                    },
                  ),
                  CustomButton(
                    type: ButtonType.receiptsButton,
                    onPressed: () {
                      // Direciona para a nova página
                      Navigator.pushNamed(context, '/receipts');
                    },
                  ),
                  CustomButton(
                    type: ButtonType.settingsButton,
                    onPressed: () {
                      Navigator.pushNamed(context, '/settings');
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
}
