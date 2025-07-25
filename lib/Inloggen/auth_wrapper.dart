import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home_screen.dart';
import 'login_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool? isModerator; // ✅ <-- hier toevoegen

  @override
  void initState() {
    super.initState();
    _checkModeratorStatus();
  }

  Future<void> _checkModeratorStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        isModerator = false;
      });
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      setState(() {
        isModerator = userDoc.get('isModerator') == true;
      });
    } catch (e) {
      setState(() {
        isModerator = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        if (isModerator == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return HomeScreen(isModerator: isModerator!); // ✅ hier werkt het nu
      },
    );
  }
}
