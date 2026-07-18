import '../models/linked_platform.dart';
import 'api_client.dart';
import 'mock_data.dart';

class PaymentsService {
  Future<List<LinkedPlatform>> listPlatforms() async {
    try {
      final response = await apiClient.get('/payments/');
      return (response.data as List)
          .map((p) => LinkedPlatform.fromJson(p))
          .toList();
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 300));
      return mockLinkedPlatforms;
    }
  }

  Future<LinkedPlatform> addPlatform({
    required String name,
    required String cardLabel,
    required double amount,
    required DateTime renewsOn,
  }) async {
    try {
      final response = await apiClient.post(
        '/payments/',
        data: {
          'name': name,
          'card_label': cardLabel,
          'amount': amount.toStringAsFixed(2),
          'renews_on': renewsOn.toIso8601String().split('T').first,
          'source': 'manual',
        },
      );
      return LinkedPlatform.fromJson(response.data);
    } catch (_) {
      return createMockLinkedPlatform(
        name: name,
        cardLabel: cardLabel,
        amount: amount,
        renewsOn: renewsOn,
      );
    }
  }

  Future<void> deletePlatform(int id) async {
    try {
      await apiClient.delete('/payments/$id/');
    } catch (_) {
      mockLinkedPlatforms.removeWhere((p) => p.id == id);
    }
  }
}
