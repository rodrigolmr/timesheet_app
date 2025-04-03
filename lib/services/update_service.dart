import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

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
}
