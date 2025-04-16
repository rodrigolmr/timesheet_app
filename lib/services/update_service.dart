import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  final _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> fetchPlatformVersionInfo() async {
    print("[UpdateService] fetchPlatformVersionInfo() called");
    try {
      print("[UpdateService] Query doc('appConfig') in collection('config')");
      final doc = await _firestore.collection('config').doc('appConfig').get();
      print("[UpdateService] doc.exists => ${doc.exists}");
      if (!doc.exists) {
        print("[UpdateService] doc doesn't exist => null");
        return null;
      }

      final data = doc.data()!;
      print("[UpdateService] data => $data");

      if (Platform.isAndroid) {
        print("[UpdateService] Running on ANDROID");
        final versionName = data['androidVersionName'] ?? '0.0.0';
        final downloadUrl = data['androidDownloadUrl'] ?? '';
        print(
            "[UpdateService] androidVersionName=$versionName, androidDownloadUrl=$downloadUrl");
        return {
          'versionName': versionName,
          'downloadUrl': downloadUrl,
        };
      } else if (Platform.isIOS) {
        print("[UpdateService] Running on IOS");
        final versionName = data['iosVersionName'] ?? '0.0.0';
        final downloadUrl = data['iosDownloadUrl'] ?? '';
        print(
            "[UpdateService] iosVersionName=$versionName, iosDownloadUrl=$downloadUrl");
        return {
          'versionName': versionName,
          'downloadUrl': downloadUrl,
        };
      }

      print("[UpdateService] This is not Android/iOS -> returning null");
      return null;
    } catch (e) {
      print("[UpdateService] ERROR in fetchPlatformVersionInfo: $e");
      rethrow;
    }
  }

  bool isRemoteVersionNewer(String local, String remote) {
    print("[UpdateService] Comparing local=$local with remote=$remote");
    try {
      final localParts = local.split('.').map(int.parse).toList();
      final remoteParts = remote.split('.').map(int.parse).toList();
      for (int i = 0; i < localParts.length; i++) {
        if (remoteParts[i] > localParts[i]) {
          print("[UpdateService] remote is bigger at index $i => return true");
          return true;
        } else if (remoteParts[i] < localParts[i]) {
          print("[UpdateService] local is bigger at index $i => return false");
          return false;
        }
      }
      print("[UpdateService] versions are equal => return false");
      return false;
    } catch (e) {
      print("[UpdateService] ERROR in isRemoteVersionNewer: $e");
      return false;
    }
  }

  /// Método principal que checa atualização e, se necessário, executa o fluxo de update.
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final localVersion = packageInfo.version;
      print("[UpdateService] Local version: $localVersion");

      final remoteData = await fetchPlatformVersionInfo();
      if (remoteData == null) {
        print("[UpdateService] No remote update data found.");
        return;
      }
      final remoteVersion = remoteData['versionName'] ?? "0.0.0";
      final downloadUrl = remoteData['downloadUrl'] ?? "";
      if (!isRemoteVersionNewer(localVersion, remoteVersion)) {
        print("[UpdateService] No update available.");
        return;
      }
      await _showUpdateDialog(context, remoteVersion, downloadUrl);
    } catch (e) {
      print("[UpdateService] checkForUpdate error: $e");
    }
  }

  Future<void> _showUpdateDialog(
      BuildContext context, String remoteVersion, String downloadUrl) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("New version available"),
          content:
              Text("A new version ($remoteVersion) is available. Update now?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Later"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _handleUpdate(downloadUrl, context);
              },
              child: const Text("Update"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleUpdate(String downloadUrl, BuildContext context) async {
    if (Platform.isIOS) {
      // iOS: abre o link de atualização
      await _openIosUpdateLink(downloadUrl, context);
    } else if (Platform.isAndroid) {
      // Android: executa o download com progress dialog
      await _downloadAndOpenUpdate(downloadUrl, context);
    }
  }

  Future<void> _openIosUpdateLink(String url, BuildContext context) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri);
    } catch (e) {
      print("[UpdateService] Error opening iOS update link: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to open the update link.")));
    }
  }

  Future<void> _downloadAndOpenUpdate(String url, BuildContext context) async {
    if (url.isEmpty) return;

    // Verifica e solicita permissão para instalação em Android
    final status = await Permission.requestInstallPackages.status;
    if (!status.isGranted) {
      bool userAgrees = await _showInstallPermissionExplanation(context);
      if (!userAgrees) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Permission is required to update the app.")),
        );
        return;
      }
      final result = await Permission.requestInstallPackages.request();
      if (!result.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("Enable unknown sources installation in settings.")),
        );
        return;
      }
    }

    // Seleciona o diretório para salvar o arquivo
    Directory directory = Platform.isAndroid
        ? (await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory())
        : await getApplicationDocumentsDirectory();
    String filePath = "${directory.path}/update.apk";

    double progress = 0.0;
    StateSetter? dialogSetState;

    // Exibe o diálogo de progresso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          dialogSetState = setState;
          return AlertDialog(
            title: const Text("Downloading update..."),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 10),
                Text("${(progress * 100).toStringAsFixed(0)}%")
              ],
            ),
          );
        });
      },
    );

    try {
      await Dio().download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            double newProgress = received / total;
            dialogSetState?.call(() {
              progress = newProgress;
            });
          }
        },
      );
      Navigator.of(context, rootNavigator: true).pop(); // fecha o diálogo
      await OpenFile.open(filePath,
          type: "application/vnd.android.package-archive");
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      print("[UpdateService] Error downloading or opening file: $e");
    }
  }

  Future<bool> _showInstallPermissionExplanation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text("Permission needed"),
              content: const Text(
                  "Allow unknown app installation to update the app?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Proceed"),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}
