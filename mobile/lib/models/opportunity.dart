class Opportunity {
  final String title;
  final String org;
  final String url;
  final String type;
  final String? tagline;

  const Opportunity({
    required this.title,
    required this.org,
    required this.url,
    required this.type,
    this.tagline,
  });
}
