import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:derde_divisie/features/moderator/social_png_delivery_contract.dart';

SocialPngBrowserAdapter createSocialPngBrowserAdapter() =>
    WebSocialPngBrowserAdapter();

class WebSocialPngBrowserAdapter implements SocialPngBrowserAdapter {
  web.File _file(Uint8List bytes, String fileName, String mimeType) => web.File(
        <web.BlobPart>[bytes.toJS].toJS,
        fileName,
        web.FilePropertyBag(type: mimeType),
      );

  web.ShareData _shareData(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) =>
      web.ShareData(files: <web.File>[_file(bytes, fileName, mimeType)].toJS);

  @override
  bool canShareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) {
    try {
      return web.window.navigator.canShare(
        _shareData(bytes, fileName, mimeType),
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      await web.window.navigator
          .share(_shareData(bytes, fileName, mimeType))
          .toDart;
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('abort') || message.contains('cancel')) {
        throw const ShareCancelledException();
      }
      rethrow;
    }
  }

  @override
  void downloadFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) {
    final blob = web.Blob(
      <web.BlobPart>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;
    anchor.click();
    Timer(const Duration(seconds: 2), () => web.URL.revokeObjectURL(url));
  }
}
