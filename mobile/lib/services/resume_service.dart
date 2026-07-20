import 'package:dio/dio.dart';

import '../models/resume.dart';
import 'api_client.dart';

/// No offline/mock fallback here, unlike most other services in this app —
/// faking "your resume was uploaded" or "here's your tailored resume" when
/// nothing actually happened would be actively misleading for something
/// this personal. Failures are surfaced as real errors instead.
class ResumeException implements Exception {
  final String message;
  ResumeException(this.message);

  @override
  String toString() => message;
}

String _extractDetail(DioException e, String fallback) {
  final data = e.response?.data;
  final detail = data is Map ? data['detail']?.toString() : null;
  return detail ?? fallback;
}

class ResumeService {
  Future<ResumeInfo?> getResume() async {
    try {
      final response = await apiClient.get('/profile/resume/');
      if (response.data == null) return null;
      return ResumeInfo.fromJson(response.data);
    } on DioException catch (e) {
      throw ResumeException(_extractDetail(e, "Couldn't check your resume status."));
    }
  }

  Future<ResumeInfo> uploadResume({
    required String filePath,
    required String filename,
  }) async {
    try {
      final response = await apiClient.post(
        '/profile/resume/',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(filePath, filename: filename),
        }),
      );
      return ResumeInfo.fromJson(response.data);
    } on DioException catch (e) {
      throw ResumeException(_extractDetail(e, "Couldn't upload your resume. Try again."));
    }
  }

  Future<void> deleteResume() async {
    try {
      await apiClient.delete('/profile/resume/');
    } on DioException catch (e) {
      throw ResumeException(_extractDetail(e, "Couldn't delete your resume."));
    }
  }

  Future<String> tailorResume({
    required String jobTitle,
    required String jobOrg,
    required String jobDescription,
  }) async {
    try {
      final response = await apiClient.post(
        '/profile/resume/tailor/',
        data: {
          'job_title': jobTitle,
          'job_org': jobOrg,
          'job_description': jobDescription,
        },
      );
      return response.data['tailored_resume'] as String;
    } on DioException catch (e) {
      throw ResumeException(
        _extractDetail(e, "Couldn't tailor your resume for this job. Try again."),
      );
    }
  }
}
