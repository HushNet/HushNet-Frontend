import 'dart:convert';

class Node {
  final String apiBaseUrl;
  final String countryCode;
  final String countryName;
  final Map<String, dynamic> features;
  final String host;
  final String ip;
  final int? lastLatencyMs;
  final String lastSeenAt;
  final String name;
  final String protocolVersion;
  final String status;

  Node({
    required this.apiBaseUrl,
    required this.countryCode,
    required this.countryName,
    required this.features,
    required this.host,
    required this.ip,
    required this.lastLatencyMs,
    required this.lastSeenAt,
    required this.name,
    required this.protocolVersion,
    required this.status,
  });

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      apiBaseUrl: json['api_base_url']?.toString() ?? '',
      countryCode: json['country_code']?.toString() ?? '',
      countryName: json['country_name']?.toString() ?? '',
      features: Map<String, dynamic>.from(json['features'] ?? {}),
      host: json['host']?.toString() ?? '',
      ip: json['ip']?.toString() ?? '',
      lastLatencyMs: json['last_latency_ms'] is int
          ? json['last_latency_ms'] as int
          : int.tryParse(json['last_latency_ms']?.toString() ?? ''),
      lastSeenAt: json['last_seen_at']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      protocolVersion: json['protocol_version']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

List<Node> parseNodes(String responseBody) {
  final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
  final nodesJson = decoded['nodes'] as List<dynamic>? ?? [];

  return nodesJson
      .map((e) => Node.fromJson(e as Map<String, dynamic>))
      .toList();
}
