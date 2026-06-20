import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/derde_divisie_logo_icon.png', height: 100),
            const SizedBox(height: 30),
            const CircularProgressIndicator(), // <== DIT IS DE DRAAIENDE LAADBALK
            const SizedBox(height: 20),
            const Text(
              'Even geduld...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
