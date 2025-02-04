import 'package:flutter/material.dart';
import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_button.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: "Time Sheet",
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const TitleBox(title: "Settings"),
            const SizedBox(height: 20),
            // Ambos os botões na mesma linha
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomButton(
                  type: ButtonType.usersButton,
                  onPressed: () {
                    Navigator.pushNamed(context, '/users');
                  },
                ),
                const SizedBox(width: 20),
                CustomButton(
                  type: ButtonType.workersButton,
                  onPressed: () {
                    Navigator.pushNamed(context, '/workers');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
