class AppException implements Exception {
  const AppException({
    required this.message,
    this.userMessage,
    this.isUserFacing = true,
  });

  final String message;
  final String? userMessage;
  final bool isUserFacing;

  @override
  String toString() => message;
}
