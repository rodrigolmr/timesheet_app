import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
import 'screens/cards_screen.dart';
import 'services/update_service.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

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
      theme: ThemeData(primarySwatch: Colors.blue),
      navigatorObservers: [routeObserver],
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
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final imageUrl = args?['imageUrl'] ?? '';
          return ReceiptViewerScreen(imageUrl: imageUrl);
        },
        '/cards': (context) => const CardsScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final UpdateService _updateService = UpdateService();
  bool _alreadyChecked = false;
  String _localVersion = "0.0.0";

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
        if (user == null) {
          return const LoginScreen();
        }

        if (!_alreadyChecked) {
          _checkVersionAfterLogin();
          _alreadyChecked = true;
        }

        return const HomeScreen();
      },
    );
  }

  Future<void> _checkVersionAfterLogin() async {
    print("[AuthWrapperState] _checkVersionAfterLogin called");
    final info = await PackageInfo.fromPlatform();
    _localVersion = info.version;
    print("[AuthWrapperState] localVersion = $_localVersion");

    final remoteData = await _updateService.fetchPlatformVersionInfo();
    if (remoteData == null) {
      print("[AuthWrapperState] remoteData == null, no update info found");
      return;
    }

    final remoteVersion = remoteData['versionName'] ?? "0.0.0";
    final downloadUrl = remoteData['downloadUrl'] ?? "";
    print(
      "[AuthWrapperState] remoteVersion = $remoteVersion, downloadUrl = $downloadUrl",
    );

    final isNewer =
        _updateService.isRemoteVersionNewer(_localVersion, remoteVersion);
    if (isNewer) {
      print("[AuthWrapperState] isNewer == true, showing popup");
      Future.microtask(() {
        _showUpdateDialog(remoteVersion, downloadUrl);
      });
    } else {
      print("[AuthWrapperState] isNewer == false, no popup");
    }
  }

  void _showUpdateDialog(String remoteVersion, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("New version available"),
          content: Text(
            "A new version ($remoteVersion) is available. "
            "Your current version is $_localVersion. Update now?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                print("[AuthWrapperState] User chose Later");
                Navigator.pop(ctx);
              },
              child: const Text("Later"),
            ),
            ElevatedButton(
              onPressed: () {
                print("[AuthWrapperState] User chose Update");
                Navigator.pop(ctx);
                _openUpdateLink(downloadUrl);
              },
              child: const Text("Update"),
            ),
          ],
        );
      },
    );
  }

  void _openUpdateLink(String url) async {
    if (url.isNotEmpty) {
      print("[AuthWrapperState] Opening update link: $url");
      await launchUrl(Uri.parse(url));
    } else {
      print("[AuthWrapperState] No download URL provided");
    }
  }
}
