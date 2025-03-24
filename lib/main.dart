import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/new_user_screen.dart';
import 'screens/new_time_sheet_screen.dart';
import 'screens/review_time_sheet_screen.dart';
import 'screens/add_workers_screen.dart';
import 'screens/timesheets_screen.dart';
import 'screens/timesheet_view_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/users_screen.dart';
import 'screens/workers_screen.dart';
import 'screens/receipts_screen.dart';
import 'screens/preview_receipt_screen.dart';
import 'screens/receipt_viewer_screen.dart';

// IMPORTANDO A NOVA TELA
import 'screens/cards_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Timesheet App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/new-time-sheet': (context) => const NewTimeSheetScreen(),
        '/add-workers': (context) => const AddWorkersScreen(),
        '/review-time-sheet': (context) => const ReviewTimeSheetScreen(),
        '/timesheets': (context) => const TimesheetsScreen(),
        '/timesheet-view': (context) => const TimesheetViewScreen(),
        '/new-user': (context) => const NewUserScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/users': (context) => const UsersScreen(),
        '/workers': (context) => const WorkersScreen(),
        '/receipts': (context) => const ReceiptsScreen(),
        '/preview-receipt': (context) => const PreviewReceiptScreen(),
        '/receipt-viewer': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final imageUrl = args?['imageUrl'] ?? '';
          return ReceiptViewerScreen(imageUrl: imageUrl);
        },

        // ROTA PARA CARDS
        '/cards': (context) => const CardsScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        return user == null ? const LoginScreen() : const HomeScreen();
      },
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timesheet App'),
      ),
      body: const Center(
        child: Text('Hello, world!'),
      ),
    );
  }
}
