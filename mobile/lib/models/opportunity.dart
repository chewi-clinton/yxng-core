class Opportunity {
  final String title;
  final String org;
  final String url;
  final String type;
  final String? tagline;
  final String description;

  const Opportunity({
    required this.title,
    required this.org,
    required this.url,
    required this.type,
    this.tagline,
    this.description = '',
  });
}
