class ProjectResource {
  final int id;
  final String kind; // 'link' or 'file'
  final String title;
  final String? url;
  final String? filename;
  final String? contentType;
  final DateTime createdAt;

  const ProjectResource({
    required this.id,
    required this.kind,
    required this.title,
    this.url,
    this.filename,
    this.contentType,
    required this.createdAt,
  });

  bool get isLink => kind == 'link';
  bool get isImage => contentType?.startsWith('image/') ?? false;

  factory ProjectResource.fromJson(Map<String, dynamic> json) {
    return ProjectResource(
      id: json['id'],
      kind: json['kind'] ?? 'link',
      title: json['title'] ?? '',
      url: json['url'],
      filename: json['filename'],
      contentType: json['content_type'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
