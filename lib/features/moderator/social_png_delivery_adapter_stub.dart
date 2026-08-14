import 'dart:typed_data';

import 'package:derde_divisie/features/moderator/social_png_delivery_contract.dart';

SocialPngBrowserAdapter createSocialPngBrowserAdapter() =>
    _UnsupportedSocialPngBrowserAdapter();

class _UnsupportedSocialPngBrowserAdapter implements SocialPngBrowserAdapter {
  @override
  bool canShareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) =>
      false;

  @override
  void downloadFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) =>
      throw UnsupportedError('PNG downloaden is alleen beschikbaar op web.');

  @override
  Future<void> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) =>
      throw UnsupportedError('PNG delen is alleen beschikbaar op web.');
}
