import 'dart:typed_data';

enum SocialPngDeliveryResult { shared, downloaded, cancelled }

class ShareCancelledException implements Exception {
  const ShareCancelledException();
}

abstract class SocialPngBrowserAdapter {
  bool canShareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  });

  Future<void> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  });

  void downloadFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  });
}
