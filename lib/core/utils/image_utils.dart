import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';

class ImageUtils {
  static Future<XFile?> pickAndCropImage({
    required ImageSource source,
    String title = 'Crop Image',
  }) async {
    final picker = ImagePicker();

    // Windows desktop platform compatibility:
    // ImageCropper does not support Windows natively and throws PlatformException.
    // Pick the image directly without cropper on Windows.
    if (!kIsWeb && Platform.isWindows) {
      try {
        final image = await picker.pickImage(source: source);
        return image;
      } catch (e) {
        debugPrint('Windows image picker error: $e');
        return null;
      }
    }

    final image = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (image == null) return null;

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: title,
            toolbarColor: AppColors.bgDark,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: title,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        return XFile(croppedFile.path);
      }
    } catch (e) {
      debugPrint('Image cropping error, falling back to original image: $e');
      return image;
    }
    return null;
  }
}
