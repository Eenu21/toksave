import 'dart:io';

import 'package:flutter/services.dart';

import '../core/errors/app_exception.dart';

class GalleryService {
  static const MethodChannel _channel = MethodChannel('toksave/gallery');

  Future<String?> saveMedia({
    required String filePath,
    required String displayName,
    required bool isAudio,
  }) async {
    if (!Platform.isAndroid) return null;

    try {
      return await _channel.invokeMethod<String>('saveMedia', {
        'filePath': filePath,
        'displayName': displayName,
        'isAudio': isAudio,
      });
    } on PlatformException catch (error) {
      throw AppException(
        message: 'Could not save video to the Android gallery: ${error.code}',
        userMessage:
            error.message ?? 'Could not save the video to your Gallery.',
      );
    }
  }

  Future<void> deleteMedia(String? contentUri) async {
    if (!Platform.isAndroid || contentUri == null) return;
    await _channel.invokeMethod<void>('deleteVideo', {
      'contentUri': contentUri,
    });
  }
}
