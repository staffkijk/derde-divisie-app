import 'package:flutter/material.dart';

class ModeratorMenuScreen extends StatelessWidget {
  const ModeratorMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moderatorpaneel')),
      body: const Center(child: Text('Hier komen de opties voor moderators')),
    );
  }
}
