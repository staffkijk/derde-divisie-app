import 'package:flutter/material.dart';
import 'package:derde_divisie/core/widgets/derde_div_logo.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  static const _background = Color(0xFF050807);
  static const _green = Color(0xFF3BAE5D);
  static const _text = Color(0xFFE7EEE9);
  static const _muted = Color(0xFF9DADA4);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logoWidth = constraints.maxWidth >= 980
            ? 210.0
            : constraints.maxWidth >= 640
                ? 180.0
                : 156.0;

        return Scaffold(
          backgroundColor: _background,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              color: _background,
              gradient: RadialGradient(
                center: Alignment.center,
                radius: .58,
                colors: [
                  Color(0x332F8F3B),
                  Color(0x140F2B1D),
                  _background,
                ],
                stops: [0, .48, 1],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DerdeDivLogo.full(width: logoWidth),
                    const SizedBox(height: 28),
                    const Text(
                      'Alles over de Derde Divisie',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        color: _green,
                        backgroundColor: Color(0x223BAE5D),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Laden...',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
