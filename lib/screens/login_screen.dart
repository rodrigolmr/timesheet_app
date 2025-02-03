import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/logo_text.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controladores de texto
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Flags de erro local (se o campo estiver vazio)
  bool _showEmailError = false;
  bool _showPasswordError = false;

  // Exibição de carregamento e mensagem de erro do Firebase
  bool _isLoading = false;
  String _errorMessage = '';

  bool _validateFields() {
    final emailEmpty = _emailController.text.trim().isEmpty;
    final passwordEmpty = _passwordController.text.trim().isEmpty;

    setState(() {
      _showEmailError = emailEmpty;
      _showPasswordError = passwordEmpty;
    });
    return !(emailEmpty || passwordEmpty);
  }

  Future<void> _handleLogin() async {
    if (!_validateFields()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      Navigator.pushReplacementNamed(context, '/home');
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
      case 'user-not-found':
        return 'User not found. Check your email.';
      case 'wrong-password':
        return 'Incorrect password. Try again.';
      case 'invalid-email':
        return 'Invalid email format.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      default:
        return 'Login error. Check your credentials.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // NÃO usamos BaseLayout aqui, apenas um Scaffold normal
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            const SizedBox(height: 70),
            const LogoText(),
            const SizedBox(height: 30),
            const Text(
              'Login',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Campo de Email
            CustomInputField(
              label: "Email",
              hintText: "Enter your email",
              controller: _emailController,
              error: _showEmailError,
              onClearError: () {
                setState(() {
                  _showEmailError = false;
                });
              },
            ),
            const SizedBox(height: 20),

            // Campo de Senha
            CustomInputField(
              label: "Password",
              hintText: "Enter your password",
              controller: _passwordController,
              error: _showPasswordError,
              onClearError: () {
                setState(() {
                  _showPasswordError = false;
                });
              },
            ),

            const SizedBox(height: 30),

            // Exibição de erro global do Firebase (ex.: user-not-found)
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),

            // Botão de login ou indicador de carregando
            _isLoading
                ? const CircularProgressIndicator()
                : CustomButton(
                    type: ButtonType.loginButton,
                    onPressed: _handleLogin,
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
