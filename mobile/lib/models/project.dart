import 'task.dart';

class Project {
  final int id;
  final String title;
  final String description;
  final List<String> techStack;
  final DateTime startDate;
  final DateTime? targetEndDate;
  final bool considerOtherProjects;
  final List<Task> tasks;
  final int? taskCount;

  Project({
    required this.id,
    required this.title,
    required this.description,
    required this.techStack,
    required this.startDate,
    this.targetEndDate,
    this.considerOtherProjects = false,
    this.tasks = const [],
    this.taskCount,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      techStack: List<String>.from(json['tech_stack'] ?? const []),
      startDate: DateTime.parse(json['start_date']),
      targetEndDate: json['target_end_date'] != null
          ? DateTime.parse(json['target_end_date'])
          : null,
      considerOtherProjects: json['consider_other_projects'] ?? false,
      tasks: json['tasks'] != null
          ? (json['tasks'] as List).map((t) => Task.fromJson(t)).toList()
          : const [],
      taskCount: json['task_count'],
    );
  }
}
