import 'package:flutter/material.dart';

import '../widgets/bottom_nav.dart';
import 'project_list_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import 'skills_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _projectsTabKey = GlobalKey<ProjectsTabState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: [
            ProjectsTab(key: _projectsTabKey),
            const ScheduleTab(),
            const SkillsTab(),
            const SettingsTab(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: YBottomNav(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          onAdd: () => _projectsTabKey.currentState?.showCreateSheet(),
        ),
      ),
    );
  }
}
