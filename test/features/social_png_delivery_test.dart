import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:derde_divisie/features/moderator/social_media_card_screen.dart';
import 'package:derde_divisie/features/moderator/social_png_save_dialog.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/features/moderator/social_png_delivery.dart';

class FakeSocialPngBrowserAdapter implements SocialPngBrowserAdapter {
  FakeSocialPngBrowserAdapter(
      {this.canShare = false,
      this.cancelShare = false,
      this.isIOS = true,
      this.failShare = false});

  @override
  final bool isIOS;
  final bool failShare;
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
    if (failShare) throw StateError('Share blocked');
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

  test('desktop downloadt ook als Web Share beschikbaar is', () async {
    final adapter = FakeSocialPngBrowserAdapter(isIOS: false, canShare: true);
    final result =
        await SocialPngDeliveryService(adapter).deliver(pngBytes, fileName);
    expect(result, SocialPngDeliveryResult.downloaded);
    expect(adapter.downloadCalled, isTrue);
    expect(adapter.shareCalled, isFalse);
  });

  for (final width in [360.0, 412.0]) {
    testWidgets('iOS opent PNG-deelknop na voorbereiden op $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final bytes = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=');
      final adapter = FakeSocialPngBrowserAdapter(canShare: true);
      final service = SocialPngDeliveryService(adapter);
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => TextButton(
                  onPressed: () => downloadSocialPng(context, bytes, fileName,
                      service: service),
                  child: const Text('PNG opslaan')))));
      await tester.tap(find.text('PNG opslaan'));
      await tester.pumpAndSettle();
      expect(find.byType(SocialPngSaveDialog), findsOneWidget);
      expect(adapter.shareCalled, isFalse);
      await tester.tap(find.text('PNG delen'));
      // The share API is invoked directly from the tap, before another frame.
      expect(adapter.shareCalled, isTrue);
      await tester.pumpAndSettle();
      expect(adapter.downloadCalled, isFalse);
      expect(adapter.receivedBytes, same(bytes));
      expect(adapter.receivedMimeType, 'image/png');
      expect(find.byType(SocialPngSaveDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scenario in ['unsupported', 'cancelled', 'failed']) {
    testWidgets('iOS $scenario heeft een bruikbare vervolgactie',
        (tester) async {
      final bytes = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=');
      final adapter = FakeSocialPngBrowserAdapter(
          canShare: scenario != 'unsupported',
          cancelShare: scenario == 'cancelled',
          failShare: scenario == 'failed');
      await tester.pumpWidget(MaterialApp(
          home: SocialPngSaveDialog(
              bytes: bytes,
              fileName: fileName,
              service: SocialPngDeliveryService(adapter))));
      await tester.pumpAndSettle();
      if (scenario != 'unsupported') {
        await tester.tap(find.text('PNG delen'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(SocialPngSaveDialog), findsOneWidget);
      expect(adapter.downloadCalled, isFalse);
      expect(
          find.text(scenario == 'cancelled' ? 'PNG delen' : 'PNG downloaden'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

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
