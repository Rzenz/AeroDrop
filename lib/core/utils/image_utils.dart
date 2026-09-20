import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/neu_button.dart';
import '../widgets/neu_feedback.dart';

class ImageValidationResult {
  final bool isValid;
  final String? mimeType; // 'image/jpeg', 'image/png', or 'image/webp'
  final String? fileExtension; // '.jpg', '.png', or '.webp'
  final String? errorMessage;

  const ImageValidationResult({
    required this.isValid,
    this.mimeType,
    this.fileExtension,
    this.errorMessage,
  });

  factory ImageValidationResult.valid({
    required String mimeType,
    required String fileExtension,
  }) =>
      ImageValidationResult(
        isValid: true,
        mimeType: mimeType,
        fileExtension: fileExtension,
      );

  factory ImageValidationResult.invalid(String errorMessage) =>
      ImageValidationResult(
        isValid: false,
        errorMessage: errorMessage,
      );
}

ImageValidationResult checkImageBytes(Uint8List bytes) {
  const maxBytes = 5 * 1024 * 1024; // 5 MB
  if (bytes.length > maxBytes) {
    return ImageValidationResult.invalid(
      'Image is too large. Please choose an image under 5 MB.',
    );
  }

  // GIF check: 'GIF8' (0x47, 0x49, 0x46, 0x38)
  if (bytes.length >= 4 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38) {
    return ImageValidationResult.invalid(
      "GIF images aren't supported. Please choose a JPG, PNG, or WebP image.",
    );
  }

  // JPEG check: FF D8 FF
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return ImageValidationResult.valid(
      mimeType: 'image/jpeg',
      fileExtension: '.jpg',
    );
  }

  // PNG check: 89 50 4E 47 0D 0A 1A 0A
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return ImageValidationResult.valid(
      mimeType: 'image/png',
      fileExtension: '.png',
    );
  }

  // WebP check: bytes 0..3 == 'RIFF' and bytes 8..11 == 'WEBP'
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return ImageValidationResult.valid(
      mimeType: 'image/webp',
      fileExtension: '.webp',
    );
  }

  return ImageValidationResult.invalid(
    'Unsupported image format. Please choose a JPG, PNG, or WebP image.',
  );
}

Future<ImageValidationResult> checkImageFile(XFile file) async {
  try {
    final bytes = await file.readAsBytes();
    return checkImageBytes(bytes);
  } catch (e) {
    return ImageValidationResult.invalid(
      'Unsupported image format. Please choose a JPG, PNG, or WebP image.',
    );
  }
}

class ImageUtils {
  static ImageValidationResult validateImageBytes(Uint8List bytes) =>
      checkImageBytes(bytes);

  static Future<ImageValidationResult> validateImage(XFile file) =>
      checkImageFile(file);

  static Future<XFile?> pickAndCropImage({
    BuildContext? context,
    required ImageSource source,
    String title = 'Adjust Photo',
    bool isCircle = false,
  }) async {
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
      );
    } catch (e) {
      debugPrint('Image pick error: $e');
      return null;
    }

    if (picked == null) return null;

    final initialValidation = await checkImageFile(picked);
    if (!initialValidation.isValid) {
      if (context != null && context.mounted) {
        showNeuSnack(
          context,
          initialValidation.errorMessage ??
              'Unsupported image format. Please choose a JPG, PNG, or WebP image.',
          tone: NeuToneKind.error,
        );
      }
      return null;
    }

    if (context != null && context.mounted) {
      final bytes = await picked.readAsBytes();
      if (!context.mounted) return null;

      final croppedBytes = await showDialog<Uint8List?>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ImageCropDialog(
          imageBytes: bytes,
          title: title,
          isCircle: isCircle,
        ),
      );

      if (croppedBytes == null) return null;

      final cropValidation = checkImageBytes(croppedBytes);
      if (!cropValidation.isValid) {
        if (context.mounted) {
          showNeuSnack(
            context,
            cropValidation.errorMessage ??
                'Unsupported image format. Please choose a JPG, PNG, or WebP image.',
            tone: NeuToneKind.error,
          );
        }
        return null;
      }

      return XFile.fromData(
        croppedBytes,
        mimeType: cropValidation.mimeType ?? 'image/png',
        name:
            'cropped_${DateTime.now().millisecondsSinceEpoch}${cropValidation.fileExtension ?? '.png'}',
      );
    }

    return picked;
  }
}

class ImageCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String title;
  final bool isCircle;

  const ImageCropDialog({
    super.key,
    required this.imageBytes,
    required this.title,
    this.isCircle = false,
  });

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  final GlobalKey _cropKey = GlobalKey();
  bool _processing = false;

  Future<void> _confirmCrop() async {
    if (_processing) return;
    setState(() => _processing = true);

    try {
      await Future.delayed(const Duration(milliseconds: 50));
      final boundary =
          _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.of(context).pop(widget.imageBytes);
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null && mounted) {
        Navigator.of(context).pop(byteData.buffer.asUint8List());
      } else if (mounted) {
        Navigator.of(context).pop(widget.imageBytes);
      }
    } catch (e) {
      debugPrint('Crop rendering failed: $e');
      if (mounted) Navigator.of(context).pop(widget.imageBytes);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const cropSize = 260.0;

    return Dialog(
      backgroundColor: AppColors.base,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.brXl),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.crop_rotate_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    widget.title,
                    style: AppTextStyles.heading(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textSecondary,
                  onPressed: () => Navigator.of(context).pop(null),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Crop viewport
            Container(
              width: cropSize,
              height: cropSize,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: widget.isCircle
                    ? null
                    : BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: widget.isCircle
                    ? BorderRadius.circular(cropSize / 2)
                    : BorderRadius.circular(14),
                child: RepaintBoundary(
                  key: _cropKey,
                  child: Container(
                    color: Colors.black,
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      boundaryMargin: const EdgeInsets.all(cropSize),
                      child: Center(
                        child: Image.memory(
                          widget.imageBytes,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Drag to reposition • Pinch or scroll to zoom',
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: NeuButton(
                    text: 'Cancel',
                    variant: NeuButtonVariant.neutral,
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: NeuButton(
                    text: 'Apply',
                    isLoading: _processing,
                    onPressed: _confirmCrop,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
