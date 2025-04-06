import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http; // Para checar internet
import '../widgets/logo_text.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showEmailError = false;
  bool _showPasswordError = false;

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
      // Loga no terminal do macOS/Android/etc.
      print('Auth error code=${e.code}, message=${e.message}');

      if (e.code == 'network-request-failed') {
        // Tenta ver se realmente não há internet
        final hasConnection = await _testInternetConnection();
        if (!hasConnection) {
          setState(() {
            _errorMessage = 'No internet connection. Check your network.';
          });
        } else {
          // Aparentemente tem internet, mas ainda deu "network-request-failed"
          // Pode ser firewall / sandbox / horário do mac desatualizado, etc.
          setState(() {
            _errorMessage = 'Network request failed, but internet seems up.\n'
                'Possibly firewall or sandbox blocking Firebase requests.';
          });
        }
      } else {
        // Se não for erro de rede, usamos o switch normal
        setState(() {
          _errorMessage = _getFirebaseErrorMessage(e.code);
        });
      }
    } catch (e) {
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
        return 'Login error. Check your credentials. ($errorCode)';
    }
  }

  /// Teste simples de conectividade fazendo GET em "www.google.com"
  /// Retorna `true` se statusCode==200, caso contrário `false`.
  Future<bool> _testInternetConnection() async {
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Scaffold normal, não usamos BaseLayout aqui
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

            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),

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
