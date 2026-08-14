import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/features/moderator/social_png_delivery.dart';

class FakeSocialPngBrowserAdapter implements SocialPngBrowserAdapter {
  FakeSocialPngBrowserAdapter(
      {this.canShare = false, this.cancelShare = false});

  final bool canShare;
  final bool cancelShare;
  bool shareCalled = false;
  bool downloadCalled = false;
  Uint8List? receivedBytes;
  String? receivedFileName;
  String? receivedMimeType;

  void record(Uint8List bytes, String fileName, String mimeType) {
    receivedBytes = bytes;
    receivedFileName = fileName;
    receivedMimeType = mimeType;
  }

  @override
  bool canShareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) {
    record(bytes, fileName, mimeType);
    return canShare;
  }

  @override
  void downloadFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) {
    downloadCalled = true;
    record(bytes, fileName, mimeType);
  }

  @override
  Future<void> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    shareCalled = true;
    record(bytes, fileName, mimeType);
    if (cancelShare) throw const ShareCancelledException();
  }
}

void main() {
  final pngBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  const fileName = 'derdediv_programma_AB_speelronde_1.png';

  test('file sharing deelt uitsluitend dezelfde PNG bytes als image/png',
      () async {
    final adapter = FakeSocialPngBrowserAdapter(canShare: true);
    final result =
        await SocialPngDeliveryService(adapter).deliver(pngBytes, fileName);

    expect(result, SocialPngDeliveryResult.shared);
    expect(adapter.shareCalled, isTrue);
    expect(adapter.downloadCalled, isFalse);
    expect(adapter.receivedBytes, same(pngBytes));
    expect(adapter.receivedFileName, fileName);
    expect(adapter.receivedMimeType, 'image/png');
  });

  test('sharepayload bevat geen URL- of paginatekstpad', () async {
    final adapter = FakeSocialPngBrowserAdapter(canShare: true);
    await SocialPngDeliveryService(adapter).deliver(pngBytes, fileName);

    expect(adapter.receivedFileName, endsWith('.png'));
    expect(adapter.receivedFileName, isNot(contains('http')));
    expect(adapter.receivedMimeType, 'image/png');
  });

  test('desktop en browsers zonder file sharing krijgen downloadfallback',
      () async {
    final adapter = FakeSocialPngBrowserAdapter();
    final result =
        await SocialPngDeliveryService(adapter).deliver(pngBytes, fileName);

    expect(result, SocialPngDeliveryResult.downloaded);
    expect(adapter.shareCalled, isFalse);
    expect(adapter.downloadCalled, isTrue);
    expect(adapter.receivedBytes, same(pngBytes));
    expect(adapter.receivedMimeType, 'image/png');
  });

  test('annuleren van native share sheet is geen exportfout', () async {
    final adapter = FakeSocialPngBrowserAdapter(
      canShare: true,
      cancelShare: true,
    );
    final result =
        await SocialPngDeliveryService(adapter).deliver(pngBytes, fileName);

    expect(result, SocialPngDeliveryResult.cancelled);
    expect(adapter.shareCalled, isTrue);
    expect(adapter.downloadCalled, isFalse);
  });
}
