import 'dart:io'; // Para verificar Platform.isMacOS
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/base_layout.dart';
import '../widgets/title_box.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/custom_button.dart';

class NewUserScreen extends StatefulWidget {
  const NewUserScreen({Key? key}) : super(key: key);

  @override
  State<NewUserScreen> createState() => _NewUserScreenState();
}

class _NewUserScreenState extends State<NewUserScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = 'User';
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _registerUser() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      setState(() {
        _errorMessage = "Passwords do not match.";
        _isLoading = false;
      });
      return;
    }
    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'userId': userCredential.user!.uid,
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
      });
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getFirebaseErrorMessage(e.code);
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getFirebaseErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'invalid-email':
        return 'Invalid email format.';
      default:
        return 'Error registering user. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se for macOS, limitamos a largura em 600
    final bool isMacOS = Platform.isMacOS;
    final double fieldMaxWidth = isMacOS ? 600 : double.infinity;

    return BaseLayout(
      title: "Timesheet",
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const TitleBox(title: "New User"),
            const SizedBox(height: 20),

            // First name
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: fieldMaxWidth),
              child: CustomInputField(
                label: "First name",
                hintText: "Enter your first name",
                controller: _firstNameController,
              ),
            ),
            const SizedBox(height: 16),

            // Last name
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: fieldMaxWidth),
              child: CustomInputField(
                label: "Last name",
                hintText: "Enter your last name",
                controller: _lastNameController,
              ),
            ),
            const SizedBox(height: 16),

            // Email
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: fieldMaxWidth),
              child: CustomInputField(
                label: "Email",
                hintText: "Enter your email",
                controller: _emailController,
              ),
            ),
            const SizedBox(height: 16),

            // Password
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: fieldMaxWidth),
              child: CustomInputField(
                label: "Password",
                hintText: "Enter your password",
                controller: _passwordController,
              ),
            ),
            const SizedBox(height: 16),

            // Confirm password
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: fieldMaxWidth),
              child: CustomInputField(
                label: "Confirm password",
                hintText: "Re-enter your password",
                controller: _confirmPasswordController,
              ),
            ),
            const SizedBox(height: 16),

            // Role dropdown
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: fieldMaxWidth),
              child: SizedBox(
                width: double.infinity,
                child: DropdownButtonFormField<String>(
                  value: _selectedRole,
                  items: <String>['User', 'Admin']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: const TextStyle(fontSize: 16)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedRole = newValue ?? 'User';
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Role',
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                    floatingLabelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF0205D3),
                    ),
                    hintText: 'Select',
                    hintStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFFFFDD0),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF0205D3), width: 1),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF0205D3), width: 2),
                    ),
                    border: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF0205D3), width: 1),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),

            // Botão
            _isLoading
                ? const CircularProgressIndicator()
                : ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: fieldMaxWidth),
                    child: CustomButton(
                      type: ButtonType.addUserButton,
                      onPressed: _registerUser,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
