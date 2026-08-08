import 'package:flutter/widgets.dart';

class NotificationAuthGate extends StatelessWidget {
  const NotificationAuthGate({
    super.key,
    required this.loggedIn,
    required this.child,
  });

  final bool loggedIn;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!loggedIn) return const SizedBox.shrink();
    return child;
  }
}
