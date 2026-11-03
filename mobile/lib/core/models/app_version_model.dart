class AppVersionModel {
  final String latestVersion;
  final int latestBuildNumber;
  final int minRequiredBuildNumber;
  final bool forceUpdate;
  final String title;
  final String message;
  final String releaseNotes;
  final String downloadUrl;

  AppVersionModel({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.minRequiredBuildNumber,
    required this.forceUpdate,
    required this.title,
    required this.message,
    required this.releaseNotes,
    required this.downloadUrl,
  });

  factory AppVersionModel.fromJson(Map<String, dynamic> json) {
    return AppVersionModel(
      latestVersion: json['latest_version']?.toString() ?? '1.0.0',
      latestBuildNumber: (json['latest_build_number'] as num?)?.toInt() ?? 1,
      minRequiredBuildNumber: (json['min_required_build_number'] as num?)?.toInt() ?? 1,
      forceUpdate: json['force_update'] == true,
      title: json['title']?.toString() ?? 'Update Required',
      message: json['message']?.toString() ?? 'A newer version of PhytoDoctor is available.',
      releaseNotes: json['release_notes']?.toString() ?? '',
      downloadUrl: json['download_url']?.toString() ?? 'https://phytodoctor-api.onrender.com/api/v1/system/download-apk',
    );
  }
}

