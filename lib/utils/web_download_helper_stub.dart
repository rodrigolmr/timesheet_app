class WebDownloadHelper {
  static void downloadJson(Map<String, dynamic> data, String filename) {
    throw UnsupportedError('Web download is not supported on this platform');
  }
  
  static void downloadMultipleJsonFiles(Map<String, List<Map<String, dynamic>>> collectionData) {
    throw UnsupportedError('Web download is not supported on this platform');
  }
}