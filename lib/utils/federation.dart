class FederatedAddress {
  final String username;
  final String nodeHost;

  const FederatedAddress({required this.username, required this.nodeHost});

  static FederatedAddress? tryParse(String address) {
    final trimmed = address.trim();
    final atIndex = trimmed.indexOf('@');
    if (atIndex <= 0 || atIndex >= trimmed.length - 1) return null;
    return FederatedAddress(
      username: trimmed.substring(0, atIndex),
      nodeHost: trimmed.substring(atIndex + 1),
    );
  }

  bool isLocal(String nodeUrl) {
    try {
      final uri = Uri.parse(nodeUrl.trim());
      return uri.host.toLowerCase() == nodeHost.toLowerCase();
    } catch (_) {
      return false;
    }
  }

  String get full => '$username@$nodeHost';

  @override
  String toString() => full;
}
