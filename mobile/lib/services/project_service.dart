import '../models/project.dart';
import '../models/task.dart';
import 'api_client.dart';
import 'mock_data.dart';

class ProjectService {
  Future<List<Project>> listProjects() async {
    try {
      final response = await apiClient.get('/projects/');
      return (response.data as List).map((p) => Project.fromJson(p)).toList();
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 400));
      return mockProjects;
    }
  }

  Future<Project> createProject({
    required String title,
    String description = '',
    List<String> techStack = const [],
    required DateTime startDate,
    DateTime? targetEndDate,
    bool considerOtherProjects = false,
  }) async {
    try {
      final response = await apiClient.post(
        '/projects/',
        data: {
          'title': title,
          'description': description,
          'tech_stack': techStack,
          'start_date': startDate.toIso8601String().split('T').first,
          if (targetEndDate != null)
            'target_end_date': targetEndDate.toIso8601String().split('T').first,
          'consider_other_projects': considerOtherProjects,
        },
      );
      return Project.fromJson(response.data);
    } catch (_) {
      await Future.delayed(const Duration(seconds: 1));
      return createMockProject(
        title: title,
        techStack: techStack,
        startDate: startDate,
        targetEndDate: targetEndDate,
      );
    }
  }

  Future<Project> getProject(int id) async {
    try {
      final response = await apiClient.get('/projects/$id/');
      return Project.fromJson(response.data);
    } catch (_) {
      if (id == personalProject.id) return personalProject;
      return mockProjects.firstWhere((p) => p.id == id);
    }
  }

  Future<void> deleteProject(int id) async {
    try {
      await apiClient.delete('/projects/$id/');
    } catch (_) {
      mockProjects.removeWhere((p) => p.id == id);
    }
  }

  Future<void> updateTaskStatus(int taskId, String status) async {
    try {
      await apiClient.patch('/projects/tasks/$taskId/', data: {'status': status});
    } catch (_) {
      mutateMockTask(taskId, (old) => _withTask(old, status: status));
    }
  }

  Future<void> rescheduleTask(
    int taskId,
    DateTime newStart,
    DateTime newEnd,
  ) async {
    try {
      await apiClient.patch(
        '/projects/tasks/$taskId/',
        data: {
          'scheduled_start': newStart.toIso8601String(),
          'scheduled_end': newEnd.toIso8601String(),
        },
      );
    } catch (_) {
      mutateMockTask(
        taskId,
        (old) => _withTask(old, start: newStart, end: newEnd),
      );
    }
  }

  /// Reminders/tasks not tied to a real project, shown on the Schedule tab.
  /// This has no backend equivalent yet — it's a local-only preview feature.
  Future<List<Task>> listPersonalTasks() async {
    return personalProject.tasks;
  }

  Future<Task> addReminder({
    required String title,
    required DateTime start,
    required DateTime end,
  }) async {
    return addPersonalTask(title: title, start: start, end: end);
  }

  Task _withTask(Task old, {String? status, DateTime? start, DateTime? end}) {
    return Task(
      id: old.id,
      title: old.title,
      description: old.description,
      estimatedDuration: old.estimatedDuration,
      order: old.order,
      status: status ?? old.status,
      scheduledStart: start ?? old.scheduledStart,
      scheduledEnd: end ?? old.scheduledEnd,
      aiGenerated: old.aiGenerated,
    );
  }
}
