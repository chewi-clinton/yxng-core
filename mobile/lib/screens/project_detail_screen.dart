import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/progress_bar.dart';

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final _projectService = ProjectService();
  late Future<Project> _projectFuture;

  @override
  void initState() {
    super.initState();
    _projectFuture = _projectService.getProject(widget.projectId);
  }

  Future<void> _toggleDone(Task task) async {
    final completing = task.status != 'done';
    final newStatus = completing ? 'done' : 'todo';
    await _projectService.updateTaskStatus(task.id, newStatus);
    setState(() {
      _projectFuture = _projectService.getProject(widget.projectId);
    });
    if (completing) _showCompletionCelebration();
  }

  void _showCompletionCelebration() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => IgnorePointer(
        child: Center(
          child: Lottie.asset(
            'assets/lottie/task_complete_checkmark.json',
            width: 160,
            repeat: false,
            onLoaded: (composition) {
              Future.delayed(composition.duration, () => entry.remove());
            },
          ),
        ),
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<Project>(
        future: _projectFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Couldn\'t load project.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          final project = snapshot.data!;
          final doneCount =
              project.tasks.where((t) => t.status == 'done').length;
          final progress = project.tasks.isEmpty
              ? 0.0
              : doneCount / project.tasks.length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            children: [
              Text(
                project.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.textPrimary,
                  height: 1.15,
                ),
              ),
              if (project.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  project.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
              if (project.techStack.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: project.techStack
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            t,
                            style: const TextStyle(
                              color: AppColors.accentSoft,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 28),
              Row(
                children: [
                  const Text(
                    'Tasks',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$doneCount / ${project.tasks.length} done',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              YProgressBar(value: progress),
              const SizedBox(height: 16),
              ...project.tasks.map(
                (task) => _TaskTile(
                  task: task,
                  onToggle: () => _toggleDone(task),
                ),
              ),
              if (project.tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'No tasks yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;

  const _TaskTile({required this.task, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final done = task.status == 'done';
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 0.6),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: done ? AppColors.accent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done ? AppColors.accent : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: done
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      color: done
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    task.scheduledStart != null
                        ? '${task.scheduledStart} – ${task.scheduledEnd}'
                        : 'Unscheduled',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
