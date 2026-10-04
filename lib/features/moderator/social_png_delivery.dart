import 'dart:typed_data';

import 'package:derde_divisie/features/moderator/social_png_delivery_adapter.dart';
import 'package:derde_divisie/features/moderator/social_png_delivery_contract.dart';

export 'package:derde_divisie/features/moderator/social_png_delivery_contract.dart';

class SocialPngDeliveryService {
  SocialPngDeliveryService([SocialPngBrowserAdapter? adapter])
      : _adapter = adapter ?? createSocialPngBrowserAdapter();

  static const mimeType = 'image/png';
  final SocialPngBrowserAdapter _adapter;

  bool get isIOS => _adapter.isIOS;

  bool canShare(Uint8List bytes, String fileName) =>
      isIOS &&
      _adapter.canShareFile(
          bytes: bytes, fileName: fileName, mimeType: mimeType);

  void download(Uint8List bytes, String fileName) => _adapter.downloadFile(
      bytes: bytes, fileName: fileName, mimeType: mimeType);

  Future<SocialPngDeliveryResult> deliver(
    Uint8List bytes,
    String fileName,
  ) async {
    if (canShare(bytes, fileName)) {
      try {
        await _adapter.shareFile(
          bytes: bytes,
          fileName: fileName,
          mimeType: mimeType,
        );
        return SocialPngDeliveryResult.shared;
      } on ShareCancelledException {
        return SocialPngDeliveryResult.cancelled;
      }
    }
    _adapter.downloadFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
    return SocialPngDeliveryResult.downloaded;
  }
}
