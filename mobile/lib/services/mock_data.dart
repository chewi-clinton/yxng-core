import '../models/linked_platform.dart';
import '../models/project.dart';
import '../models/task.dart';

/// In-memory sample data used only when the backend is unreachable, so the
/// frontend can be previewed end-to-end before the API is wired up.
final List<Project> mockProjects = [
  Project(
    id: 1,
    title: 'Yxng Core mobile app',
    description:
        'Personal life-OS: projects, schedule, payments, and growth in one place.',
    techStack: const ['Flutter', 'Django', 'Gemini'],
    startDate: DateTime.now().subtract(const Duration(days: 3)),
    tasks: [
      Task(
        id: 101,
        title: 'Design onboarding flow',
        description: '',
        estimatedDuration: 90,
        order: 0,
        status: 'done',
        scheduledStart: DateTime.now().subtract(const Duration(days: 2)),
        scheduledEnd: DateTime.now().subtract(const Duration(days: 2, hours: -1)),
        aiGenerated: true,
      ),
      Task(
        id: 102,
        title: 'Build project list + detail screens',
        description: '',
        estimatedDuration: 180,
        order: 1,
        status: 'done',
        scheduledStart: DateTime.now().subtract(const Duration(days: 1)),
        scheduledEnd: DateTime.now().subtract(const Duration(days: 1, hours: -3)),
        aiGenerated: true,
      ),
      Task(
        id: 103,
        title: 'Wire up Chrome payment-capture extension',
        description: '',
        estimatedDuration: 120,
        order: 2,
        status: 'todo',
        scheduledStart: DateTime.now().add(const Duration(hours: 2)),
        scheduledEnd: DateTime.now().add(const Duration(hours: 4)),
        aiGenerated: true,
      ),
      Task(
        id: 104,
        title: 'Connect Django backend + Gemini AI service',
        description: '',
        estimatedDuration: 60,
        order: 3,
        status: 'todo',
        scheduledStart: DateTime.now().add(const Duration(days: 1)),
        scheduledEnd: DateTime.now().add(const Duration(days: 1, hours: 1)),
        aiGenerated: true,
      ),
    ],
  ),
  Project(
    id: 2,
    title: 'Learn AI automation',
    description: 'Telegram + WhatsApp bots for daily task automation.',
    techStack: const ['Python', 'n8n'],
    startDate: DateTime.now().subtract(const Duration(days: 10)),
    tasks: [
      Task(
        id: 201,
        title: 'Map out bot command structure',
        description: '',
        estimatedDuration: 45,
        order: 0,
        status: 'done',
        aiGenerated: true,
      ),
      Task(
        id: 202,
        title: 'Prototype Telegram webhook handler',
        description: '',
        estimatedDuration: 120,
        order: 1,
        status: 'todo',
        scheduledStart: DateTime.now().add(const Duration(hours: 6)),
        scheduledEnd: DateTime.now().add(const Duration(hours: 8)),
        aiGenerated: true,
      ),
    ],
  ),
];

int _nextProjectId = 3;
int _nextTaskId = 300;

Project createMockProject({
  required String title,
  List<String> techStack = const [],
  required DateTime startDate,
  DateTime? targetEndDate,
}) {
  final project = Project(
    id: _nextProjectId++,
    title: title,
    description: 'AI-planned project (offline preview).',
    techStack: techStack,
    startDate: startDate,
    targetEndDate: targetEndDate,
    tasks: [
      Task(
        id: _nextTaskId++,
        title: 'Scope out $title',
        description: '',
        estimatedDuration: 60,
        order: 0,
        status: 'todo',
        scheduledStart: startDate,
        scheduledEnd: startDate.add(const Duration(hours: 1)),
        aiGenerated: true,
      ),
      Task(
        id: _nextTaskId++,
        title: 'First implementation pass',
        description: '',
        estimatedDuration: 120,
        order: 1,
        status: 'todo',
        scheduledStart: startDate.add(const Duration(hours: 1)),
        scheduledEnd: startDate.add(const Duration(hours: 3)),
        aiGenerated: true,
      ),
    ],
  );
  mockProjects.add(project);
  return project;
}

/// Synthetic project used purely to hold ad-hoc reminders created from the
/// Schedule tab that aren't tied to a real project — not part of
/// [mockProjects] so it never shows up in the Projects list.
final Project personalProject = Project(
  id: -1,
  title: 'Personal',
  description: '',
  techStack: const [],
  startDate: DateTime.now(),
  tasks: [
    Task(
      id: 901,
      title: 'Renew passport application',
      description: '',
      estimatedDuration: 30,
      order: 0,
      status: 'todo',
      scheduledStart: DateTime.now().add(const Duration(days: 2, hours: 1)),
      scheduledEnd: DateTime.now().add(const Duration(days: 2, hours: 2)),
      aiGenerated: false,
    ),
  ],
);

Task addPersonalTask({
  required String title,
  required DateTime start,
  required DateTime end,
}) {
  final task = Task(
    id: _nextTaskId++,
    title: title,
    description: '',
    estimatedDuration: end.difference(start).inMinutes,
    order: personalProject.tasks.length,
    status: 'todo',
    scheduledStart: start,
    scheduledEnd: end,
    aiGenerated: false,
  );
  personalProject.tasks.add(task);
  return task;
}

/// Finds [taskId] across every mock project (including the personal one)
/// and applies [update]. Returns true if a task was found and updated.
bool mutateMockTask(int taskId, Task Function(Task old) update) {
  for (final project in [...mockProjects, personalProject]) {
    final index = project.tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      project.tasks[index] = update(project.tasks[index]);
      return true;
    }
  }
  return false;
}

final List<LinkedPlatform> mockLinkedPlatforms = [
  LinkedPlatform(
    id: 1,
    name: 'Netflix',
    cardLabel: 'Visa •••• 4242',
    amount: 15.99,
    renewsOn: DateTime.now().add(const Duration(days: 4)),
  ),
  LinkedPlatform(
    id: 2,
    name: 'Spotify',
    cardLabel: 'Mastercard •••• 8891',
    amount: 10.99,
    renewsOn: DateTime.now().add(const Duration(days: 12)),
  ),
  LinkedPlatform(
    id: 3,
    name: 'iCloud+',
    cardLabel: 'Visa •••• 4242',
    amount: 2.99,
    renewsOn: DateTime.now().add(const Duration(days: 1)),
  ),
  LinkedPlatform(
    id: 4,
    name: 'GitHub Copilot',
    cardLabel: 'Mastercard •••• 8891',
    amount: 10.00,
    renewsOn: DateTime.now().add(const Duration(days: 21)),
  ),
];

int _nextPlatformId = 5;

LinkedPlatform createMockLinkedPlatform({
  required String name,
  required String cardLabel,
  required double amount,
  required DateTime renewsOn,
  String source = 'manual',
}) {
  final platform = LinkedPlatform(
    id: _nextPlatformId++,
    name: name,
    cardLabel: cardLabel,
    amount: amount,
    renewsOn: renewsOn,
    source: source,
  );
  mockLinkedPlatforms.add(platform);
  return platform;
}
