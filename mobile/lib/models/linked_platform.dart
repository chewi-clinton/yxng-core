enum PlatformIcon { streaming, music, cloud, software, other }

class LinkedPlatform {
  final int? id;
  final String name;
  final String cardLabel;
  final double amount;
  final DateTime renewsOn;
  final String source;

  const LinkedPlatform({
    this.id,
    required this.name,
    required this.cardLabel,
    required this.amount,
    required this.renewsOn,
    this.source = 'manual',
  });

  factory LinkedPlatform.fromJson(Map<String, dynamic> json) {
    return LinkedPlatform(
      id: json['id'],
      name: json['name'] ?? '',
      cardLabel: json['card_label'] ?? '',
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      renewsOn: DateTime.parse(json['renews_on']),
      source: json['source'] ?? 'manual',
    );
  }

  /// Derived client-side from the name — the backend doesn't store an icon,
  /// so a new platform (however it was added) still gets a sensible glyph.
  PlatformIcon get icon {
    final n = name.toLowerCase();
    if (n.contains('netflix') ||
        n.contains('prime') ||
        n.contains('hulu') ||
        n.contains('disney') ||
        n.contains('youtube')) {
      return PlatformIcon.streaming;
    }
    if (n.contains('spotify') || n.contains('music') || n.contains('tidal')) {
      return PlatformIcon.music;
    }
    if (n.contains('cloud') || n.contains('drive') || n.contains('dropbox')) {
      return PlatformIcon.cloud;
    }
    if (n.contains('copilot') ||
        n.contains('github') ||
        n.contains('code') ||
        n.contains('jetbrains')) {
      return PlatformIcon.software;
    }
    return PlatformIcon.other;
  }
}
