import 'package:dio/dio.dart';

import '../models/roadmap.dart';
import 'api_client.dart';
import 'mock_data.dart';

/// Thrown when the backend was reached but Gemini failed to generate a
/// roadmap (HTTP 502 from the AI service) — surfaced to the user instead of
/// silently substituting fake milestones, unlike the offline/no-backend
/// fallback used elsewhere in this app.
class RoadmapGenerationException implements Exception {
  final String message;
  RoadmapGenerationException(this.message);

  @override
  String toString() => message;
}

bool _isNoBackendReachable(DioException e) {
  return e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.unknown;
}

class RoadmapService {
  Future<List<Roadmap>> listRoadmaps() async {
    try {
      final response = await apiClient.get('/skills/');
      return (response.data as List).map((r) => Roadmap.fromJson(r)).toList();
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 300));
      return mockRoadmaps;
    }
  }

  Future<Roadmap> getRoadmap(int id) async {
    try {
      final response = await apiClient.get('/skills/$id/');
      return Roadmap.fromJson(response.data);
    } catch (_) {
      return mockRoadmaps.firstWhere((r) => r.id == id);
    }
  }

  Future<Roadmap> createRoadmap({
    required String title,
    DateTime? targetDate,
  }) async {
    try {
      final response = await apiClient.post(
        '/skills/',
        data: {
          'title': title,
          if (targetDate != null)
            'target_date': targetDate.toIso8601String().split('T').first,
        },
      );
      return Roadmap.fromJson(response.data);
    } on DioException catch (e) {
      if (_isNoBackendReachable(e)) {
        await Future.delayed(const Duration(milliseconds: 800));
        return createMockRoadmap(title: title, targetDate: targetDate);
      }
      final data = e.response?.data;
      final detail = data is Map ? data['detail']?.toString() : null;
      throw RoadmapGenerationException(
        detail ?? "Couldn't generate your roadmap. Try again.",
      );
    }
  }

  Future<void> deleteRoadmap(int id) async {
    try {
      await apiClient.delete('/skills/$id/');
    } catch (_) {
      mockRoadmaps.removeWhere((r) => r.id == id);
    }
  }

  Future<void> updateMilestoneStatus({
    required int roadmapId,
    required int milestoneIndex,
    int? milestoneId,
    required String status,
  }) async {
    if (milestoneId == null) {
      mutateMockMilestone(roadmapId, milestoneIndex, status);
      return;
    }
    try {
      await apiClient.patch(
        '/skills/milestones/$milestoneId/',
        data: {'status': status},
      );
    } catch (_) {
      mutateMockMilestone(roadmapId, milestoneIndex, status);
    }
  }
}
