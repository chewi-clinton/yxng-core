class Milestone {
  final int? id;
  final String title;
  final String description;
  final int order;
  final String status;

  const Milestone({
    this.id,
    required this.title,
    this.description = '',
    this.order = 0,
    this.status = 'todo',
  });

  bool get done => status == 'done';

  factory Milestone.fromJson(Map<String, dynamic> json) {
    return Milestone(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      order: json['order'] ?? 0,
      status: json['status'] ?? 'todo',
    );
  }
}

class Roadmap {
  final int id;
  final String title;
  final DateTime? targetDate;
  final List<Milestone> milestones;
  final int? milestoneCount;
  final int? completedCount;

  const Roadmap({
    required this.id,
    required this.title,
    this.targetDate,
    this.milestones = const [],
    this.milestoneCount,
    this.completedCount,
  });

  double get progress {
    if (milestones.isNotEmpty) {
      return milestones.where((m) => m.done).length / milestones.length;
    }
    if (milestoneCount != null && milestoneCount! > 0) {
      return (completedCount ?? 0) / milestoneCount!;
    }
    return 0;
  }

  String get stage {
    if (milestones.isNotEmpty) {
      for (final m in milestones) {
        if (!m.done) return m.title;
      }
      return 'Completed! 🎉';
    }
    if (milestoneCount != null && milestoneCount! > 0) {
      return '${completedCount ?? 0}/$milestoneCount milestones done';
    }
    return 'Tap to see milestones';
  }

  Roadmap copyWith({List<Milestone>? milestones}) {
    return Roadmap(
      id: id,
      title: title,
      targetDate: targetDate,
      milestones: milestones ?? this.milestones,
      milestoneCount: milestoneCount,
      completedCount: completedCount,
    );
  }

  factory Roadmap.fromJson(Map<String, dynamic> json) {
    return Roadmap(
      id: json['id'],
      title: json['title'] ?? '',
      targetDate:
          json['target_date'] != null ? DateTime.parse(json['target_date']) : null,
      milestones: (json['milestones'] as List?)
              ?.map((m) => Milestone.fromJson(m))
              .toList() ??
          const [],
      milestoneCount: json['milestone_count'],
      completedCount: json['completed_count'],
    );
  }
}
