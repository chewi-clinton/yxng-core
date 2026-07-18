class Task {
  final int id;
  final String title;
  final String description;
  final int estimatedDuration;
  final int order;
  final String status;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final bool aiGenerated;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.estimatedDuration,
    required this.order,
    required this.status,
    this.scheduledStart,
    this.scheduledEnd,
    required this.aiGenerated,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      estimatedDuration: json['estimated_duration'],
      order: json['order'],
      status: json['status'],
      scheduledStart: json['scheduled_start'] != null
          ? DateTime.parse(json['scheduled_start'])
          : null,
      scheduledEnd: json['scheduled_end'] != null
          ? DateTime.parse(json['scheduled_end'])
          : null,
      aiGenerated: json['ai_generated'] ?? true,
    );
  }
}
