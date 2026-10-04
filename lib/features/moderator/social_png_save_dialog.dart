import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'social_png_delivery.dart';

class SocialPngSaveDialog extends StatefulWidget {
  const SocialPngSaveDialog({
    super.key,
    required this.bytes,
    required this.fileName,
    required this.service,
  });

  final Uint8List bytes;
  final String fileName;
  final SocialPngDeliveryService service;

  @override
  State<SocialPngSaveDialog> createState() => _SocialPngSaveDialogState();
}

class _SocialPngSaveDialogState extends State<SocialPngSaveDialog> {
  bool sharing = false;
  String? error;

  Future<void> share() async {
    setState(() {
      sharing = true;
      error = null;
    });
    try {
      // Do not await rendering, network requests or analytics before this call.
      final result =
          await widget.service.deliver(widget.bytes, widget.fileName);
      if (mounted && result != SocialPngDeliveryResult.cancelled) {
        Navigator.of(context).pop(result);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'Delen is niet gelukt. Probeer opnieuw of download de PNG.');
      }
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  void download() {
    try {
      widget.service.download(widget.bytes, widget.fileName);
      Navigator.of(context).pop(SocialPngDeliveryResult.downloaded);
    } catch (_) {
      setState(() => error = 'Downloaden is niet gelukt. Probeer opnieuw.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canShare = widget.service.canShare(widget.bytes, widget.fileName);
    return AlertDialog(
      title: const Text('PNG opslaan'),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.memory(widget.bytes, fit: BoxFit.contain),
            const SizedBox(height: 16),
            Text(canShare
                ? 'Tik op PNG delen en kies Bewaar afbeelding in het deelmenu om de afbeelding in Foto’s op te slaan.'
                : 'Deze browser kan geen afbeeldingsbestand delen. Download de PNG, open het bestand in Downloads en kies Delen om de afbeelding te bewaren.'),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: sharing ? null : () => Navigator.of(context).pop(),
            child: const Text('Sluiten')),
        if (!canShare || error != null)
          TextButton(
              onPressed: sharing ? null : download,
              child: const Text('PNG downloaden')),
        if (canShare)
          FilledButton.icon(
              onPressed: sharing ? null : share,
              icon: const Icon(Icons.ios_share),
              label: const Text('PNG delen')),
      ],
    );
  }
}
