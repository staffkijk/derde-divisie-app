import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'wedstrijd.dart';

class VoorspellingWidget extends StatefulWidget {
  final Wedstrijd wedstrijd;
  final DateTime? deadline;

  const VoorspellingWidget({
    super.key,
    required this.wedstrijd,
    required this.deadline,
  });

  @override
  State<VoorspellingWidget> createState() => _VoorspellingWidgetState();
}

class _VoorspellingWidgetState extends State<VoorspellingWidget> {
  late final TextEditingController _thuisController;
  late final TextEditingController _uitController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool get isBuitenDeadline {
    if (widget.deadline == null) return false;
    return DateTime.now().isAfter(widget.deadline!);
  }

  @override
  void initState() {
    super.initState();
    _thuisController = TextEditingController();
    _uitController = TextEditingController();
    _laadVoorspelling();
  }

  Future<void> _laadVoorspelling() async {
    final gebruiker = _auth.currentUser;
    if (gebruiker == null) return;

    final docId = '${gebruiker.uid}_${widget.wedstrijd.id}';
    final doc = await _firestore.collection('voorspellingen').doc(docId).get();

    if (doc.exists) {
      final data = doc.data()!;
      if (mounted) {
        setState(() {
          _thuisController.text = data['scoreThuis'] ?? '';
          _uitController.text = data['scoreUit'] ?? '';
        });
      }
    }
  }

  Future<void> _slaVoorspellingOp() async {
    final gebruiker = _auth.currentUser;
    if (gebruiker == null) return;

    final docId = '${gebruiker.uid}_${widget.wedstrijd.id}';
    final voorspelling = {
      'gebruikerId': gebruiker.uid,
      'wedstrijdId': widget.wedstrijd.id,
      'scoreThuis': _thuisController.text,
      'scoreUit': _uitController.text,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('voorspellingen').doc(docId).set(voorspelling);
  }

  @override
  void dispose() {
    _slaVoorspellingOp(); // automatisch opslaan bij verlaten
    _thuisController.dispose();
    _uitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('${widget.wedstrijd.thuis} - ${widget.wedstrijd.uit}'),
      subtitle: Text(
        'Datum: ${widget.wedstrijd.datum.toLocal().toIso8601String().substring(0, 10)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            child: TextField(
              controller: _thuisController,
              keyboardType: TextInputType.number,
              enabled: !isBuitenDeadline,
              onChanged: (_) => _slaVoorspellingOp(),
              decoration: const InputDecoration(
                hintText: '0',
                isDense: true,
              ),
            ),
          ),
          const Text(' - '),
          SizedBox(
            width: 40,
            child: TextField(
              controller: _uitController,
              keyboardType: TextInputType.number,
              enabled: !isBuitenDeadline,
              onChanged: (_) => _slaVoorspellingOp(),
              decoration: const InputDecoration(
                hintText: '0',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
