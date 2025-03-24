import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _fullName = "";
  String _email = "";
  String _role = "User";
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoadingUser = false;
        });
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final firstName = data["firstName"] ?? "";
        final lastName = data["lastName"] ?? "";
        final fullName = (firstName + " " + lastName).trim();
        final email = data["email"] ?? user.email ?? "";
        final role = data["role"] ?? "User";

        setState(() {
          _fullName = fullName.isEmpty ? "Unknown user" : fullName;
          _email = email;
          _role = role;
          _isLoadingUser = false;
        });
      } else {
        setState(() {
          _fullName = user.email ?? "Unknown";
          _email = user.email ?? "no-email";
          _role = "User";
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      setState(() {
        _fullName = "Error loading user";
        _email = "";
        _role = "";
        _isLoadingUser = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: "Timesheet",
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const TitleBox(title: "Settings"),
            const SizedBox(height: 20),
            _isLoadingUser
                ? const Center(child: CircularProgressIndicator())
                : _buildUserInfoBox(),
            const SizedBox(height: 20),

            // Exibe a Row apenas se for Admin:
            if (_role == "Admin")
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
                  const SizedBox(width: 20),
                  // Novo botão "Cards"
                  CustomButton(
                    type: ButtonType.cardsButton,
                    onPressed: () {
                      Navigator.pushNamed(context, '/cards');
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoBox() {
    return Container(
      width: 330,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFD0),
        border: Border.all(
          color: const Color(0xFF0205D3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fullName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0205D3),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _email,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _role, // "Admin" ou "User"
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
