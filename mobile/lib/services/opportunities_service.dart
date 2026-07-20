import 'package:dio/dio.dart';

import '../models/opportunity.dart';

/// Pulls real, live listings from public job-board APIs — no scraping, no
/// backend server needed. Each result links directly to the real posting.
class OpportunitiesService {
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {'User-Agent': 'YxngCore/1.0'},
  ));

  static final _htmlTag = RegExp(r'<[^>]*>');
  static final _nonLatinLetter = RegExp(
    r'[Ѐ-ӿ؀-ۿऀ-ॿ぀-ヿ㐀-鿿가-힯]',
  );
  static final _junkPhrases = RegExp(
    r'no articles in this category|lorem ipsum',
    caseSensitive: false,
  );

  // Keyword match rather than a model call: classifying "is this a tech
  // role" from a title/category/tags is a solved deterministic problem, and
  // routing it through an LLM would mean either embedding an API key in the
  // mobile client (a real security risk) or depending on the backend AI
  // service, which isn't wired up yet. This is free, instant, and offline.
  static final _techKeywords = RegExp(
    r'\b(develop|engineer|engineering|software|programmer|program(ming)?|'
    r'devops|sysadmin|site reliability|\bsre\b|data scientist|data engineer|'
    r'data analy|machine learning|\bml\b|\bai\b|artificial intelligence|'
    r'backend|back-end|frontend|front-end|full ?stack|mobile dev|\bios\b|'
    r'\bandroid\b|flutter|react|angular|vue\.?js|node\.?js|python|java\b|'
    r'javascript|typescript|golang|go developer|go engineer|rust|kotlin|'
    r'swiftui|ios developer|\bphp\b|ruby|'
    r'\.net\b|c\+\+|c#|cloud engineer|aws|azure|gcp|kubernetes|docker|'
    r'security engineer|cybersecurity|penetration test|\bqa\b|quality assurance|'
    r'test automation|database admin|\bdba\b|architect|technical lead|tech lead|'
    r'\bapi\b|infrastructure|network engineer|embedded|firmware|game dev|'
    r'blockchain|web3|smart contract|solidity|ux engineer|product designer|'
    r'ui\/ux|ux\/ui)',
    caseSensitive: false,
  );

  bool _isTechRelated(String title, String extraSignal) {
    return _techKeywords.hasMatch('$title $extraSignal');
  }

  /// Cheap heuristic, not real language detection: rejects listings whose
  /// text leans heavily non-Latin-script, or that are obvious placeholder
  /// junk rather than a real posting.
  bool _looksLikeRealEnglishListing(String title, String description) {
    final plain = description.replaceAll(_htmlTag, ' ');
    if (plain.trim().length < 40) return false;
    if (_junkPhrases.hasMatch(plain)) return false;
    final combined = '$title $plain';
    final nonLatinCount = _nonLatinLetter.allMatches(combined).length;
    if (nonLatinCount > combined.length * 0.05) return false;
    return true;
  }

  Future<List<Opportunity>> fetchRemoteOk({int limit = 8}) async {
    try {
      final res = await _dio.get('https://remoteok.com/api');
      final raw = (res.data as List).whereType<Map>().where(
            (e) => e['id'] != null,
          );
      return raw
          .where((j) {
            final position = (j['position'] ?? '').toString();
            final description = (j['description'] ?? '').toString();
            final tags = ((j['tags'] as List?) ?? []).join(' ');
            return position.length > 4 &&
                _looksLikeRealEnglishListing(position, description) &&
                _isTechRelated(position, tags);
          })
          .take(limit)
          .map((j) {
            final tags = (j['tags'] as List?)?.whereType<String>().take(3);
            return Opportunity(
              title: (j['position'] ?? 'Remote role').toString(),
              org: (j['company'] ?? 'Unknown company').toString(),
              url: (j['url'] ?? 'https://remoteok.com').toString(),
              type: 'Remote job',
              tagline: tags != null && tags.isNotEmpty ? tags.join(' · ') : null,
              description: _cleanDescription((j['description'] ?? '').toString()),
            );
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Opportunity>> fetchRemotive({int limit = 8}) async {
    try {
      final res = await _dio.get(
        'https://remotive.com/api/remote-jobs',
        queryParameters: {'limit': limit},
      );
      final jobs = (res.data['jobs'] as List?) ?? [];
      return jobs
          .where((j) {
            final title = (j['title'] ?? '').toString();
            final description = (j['description'] ?? '').toString();
            final category = (j['category'] ?? '').toString();
            return _looksLikeRealEnglishListing(title, description) &&
                _isTechRelated(title, category);
          })
          .map((j) {
            return Opportunity(
              title: (j['title'] ?? 'Remote role').toString(),
              org: (j['company_name'] ?? 'Unknown company').toString(),
              url: (j['url'] ?? 'https://remotive.com').toString(),
              type: _titleCase((j['job_type'] ?? 'Remote job').toString()),
              tagline: (j['candidate_required_location'] ?? '').toString().isEmpty
                  ? null
                  : (j['candidate_required_location']).toString(),
              description: _cleanDescription((j['description'] ?? '').toString()),
            );
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Opportunity>> fetchJobicy({int limit = 8}) async {
    try {
      final res = await _dio.get(
        'https://jobicy.com/api/v2/remote-jobs',
        queryParameters: {'count': limit},
      );
      final jobs = (res.data['jobs'] as List?) ?? [];
      return jobs
          .where((j) {
            final title = (j['jobTitle'] ?? '').toString();
            final excerpt = (j['jobExcerpt'] ?? '').toString();
            final industry = ((j['jobIndustry'] as List?) ?? []).join(' ');
            return _looksLikeRealEnglishListing(title, excerpt) &&
                _isTechRelated(title, industry);
          })
          .map((j) {
            final types = (j['jobType'] as List?)?.whereType<String>();
            return Opportunity(
              title: (j['jobTitle'] ?? 'Remote role').toString(),
              org: (j['companyName'] ?? 'Unknown company').toString(),
              url: (j['url'] ?? 'https://jobicy.com').toString(),
              type: types != null && types.isNotEmpty
                  ? _titleCase(types.first)
                  : 'Remote job',
              tagline: (j['jobGeo'] ?? '').toString().isEmpty
                  ? null
                  : (j['jobGeo']).toString(),
              description: _cleanDescription((j['jobExcerpt'] ?? '').toString()),
            );
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _cleanDescription(String raw) {
    return raw
        .replaceAll(_htmlTag, ' ')
        .replaceAll(RegExp(r'&nbsp;|&amp;|&#39;|&quot;'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _titleCase(String s) {
    final cleaned = s.replaceAll('-', ' ').trim();
    if (cleaned.isEmpty) return 'Remote job';
    return cleaned
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Future<List<Opportunity>> fetchAll() async {
    final results = await Future.wait([
      fetchRemoteOk(),
      fetchRemotive(),
      fetchJobicy(),
    ]);
    return [...results[0], ...results[1], ...results[2]];
  }
}
