class ResumeInfo {
  final String filename;
  final DateTime uploadedAt;

  const ResumeInfo({required this.filename, required this.uploadedAt});

  factory ResumeInfo.fromJson(Map<String, dynamic> json) {
    return ResumeInfo(
      filename: json['filename'] ?? '',
      uploadedAt: DateTime.parse(json['uploaded_at']),
    );
  }
}
