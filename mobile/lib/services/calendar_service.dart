import 'api_client.dart';

class CalendarService {
  Future<bool> getStatus() async {
    try {
      final response = await apiClient.get('/calendar/status/');
      return response.data['connected'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getAuthUrl() async {
    try {
      final response = await apiClient.get('/calendar/connect/');
      return response.data['auth_url'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> disconnect() async {
    try {
      await apiClient.delete('/calendar/status/');
      return true;
    } catch (_) {
      return false;
    }
  }
}
