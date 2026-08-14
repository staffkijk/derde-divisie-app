import 'dart:typed_data';

import 'package:derde_divisie/features/moderator/social_png_delivery_adapter.dart';
import 'package:derde_divisie/features/moderator/social_png_delivery_contract.dart';

export 'package:derde_divisie/features/moderator/social_png_delivery_contract.dart';

class SocialPngDeliveryService {
  SocialPngDeliveryService([SocialPngBrowserAdapter? adapter])
      : _adapter = adapter ?? createSocialPngBrowserAdapter();

  static const mimeType = 'image/png';
  final SocialPngBrowserAdapter _adapter;

  Future<SocialPngDeliveryResult> deliver(
    Uint8List bytes,
    String fileName,
  ) async {
    final canShare = _adapter.canShareFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
    if (canShare) {
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
