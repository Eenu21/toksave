enum DownloadState {
  preparing,
  fetchingVideo,
  downloading,
  saving,
  completed,
  failed,
  cancelled,
}

class DownloadProgress {
  const DownloadProgress({
    this.state = DownloadState.preparing,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.message = 'Preparing...',
  });

  final DownloadState state;
  final int receivedBytes;
  final int totalBytes;
  final String message;

  int get percent => totalBytes <= 0
      ? 0
      : ((receivedBytes / totalBytes) * 100).round().clamp(0, 100);

  DownloadProgress copyWith({
    DownloadState? state,
    int? receivedBytes,
    int? totalBytes,
    String? message,
  }) {
    return DownloadProgress(
      state: state ?? this.state,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      message: message ?? this.message,
    );
  }
}
