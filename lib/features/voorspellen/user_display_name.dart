const _userNameFields = ['username', 'usernameLower', 'usernameKey'];

String resolveUserDisplayName(
  Map<String, dynamic> data, {
  String fallback = 'Onbekend',
}) {
  for (final field in _userNameFields) {
    final value = data[field];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return fallback;
}
