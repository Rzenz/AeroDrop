import 'dart:typed_data';
import 'package:aerodrop/core/utils/image_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  group('checkImageBytes & checkImageFile format tests', () {
    test('accepts valid JPEG bytes and returns image/jpeg with .jpg', () async {
      final jpegBytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      ]);

      final syncResult = checkImageBytes(jpegBytes);
      expect(syncResult.isValid, isTrue);
      expect(syncResult.mimeType, 'image/jpeg');
      expect(syncResult.fileExtension, '.jpg');
      expect(syncResult.errorMessage, isNull);

      final file = XFile.fromData(jpegBytes, name: 'photo.jpeg');
      final asyncResult = await checkImageFile(file);
      expect(asyncResult.isValid, isTrue);
      expect(asyncResult.mimeType, 'image/jpeg');
      expect(asyncResult.fileExtension, '.jpg');
    });

    test('accepts valid PNG bytes and returns image/png with .png', () async {
      final pngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      ]);

      final syncResult = checkImageBytes(pngBytes);
      expect(syncResult.isValid, isTrue);
      expect(syncResult.mimeType, 'image/png');
      expect(syncResult.fileExtension, '.png');
      expect(syncResult.errorMessage, isNull);

      final file = XFile.fromData(pngBytes, name: 'graphic.png');
      final asyncResult = await checkImageFile(file);
      expect(asyncResult.isValid, isTrue);
      expect(asyncResult.mimeType, 'image/png');
    });

    test('accepts valid WebP bytes and returns image/webp with .webp', () async {
      final webpBytes = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, // 'RIFF'
        0x20, 0x00, 0x00, 0x00, // file size
        0x57, 0x45, 0x42, 0x50, // 'WEBP'
        0x56, 0x50, 0x38, 0x20, // 'VP8 '
      ]);

      final syncResult = checkImageBytes(webpBytes);
      expect(syncResult.isValid, isTrue);
      expect(syncResult.mimeType, 'image/webp');
      expect(syncResult.fileExtension, '.webp');
      expect(syncResult.errorMessage, isNull);

      final file = XFile.fromData(webpBytes, name: 'banner.webp');
      final asyncResult = await checkImageFile(file);
      expect(asyncResult.isValid, isTrue);
      expect(asyncResult.mimeType, 'image/webp');
    });

    test('rejects GIF89a format with dedicated GIF error message', () async {
      final gifBytes = Uint8List.fromList([
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00,
      ]);

      final syncResult = checkImageBytes(gifBytes);
      expect(syncResult.isValid, isFalse);
      expect(
        syncResult.errorMessage,
        "GIF images aren't supported. Please choose a JPG, PNG, or WebP image.",
      );

      // Even if disguised as .jpg or .png extension, magic bytes detect and reject GIF
      final file = XFile.fromData(gifBytes, name: 'disguised_animation.jpg');
      final asyncResult = await checkImageFile(file);
      expect(asyncResult.isValid, isFalse);
      expect(
        asyncResult.errorMessage,
        "GIF images aren't supported. Please choose a JPG, PNG, or WebP image.",
      );
    });

    test('rejects GIF87a format with dedicated GIF error message', () {
      final gif87Bytes = Uint8List.fromList([
        0x47, 0x49, 0x46, 0x38, 0x37, 0x61, 0x01, 0x00, 0x01, 0x00,
      ]);

      final result = checkImageBytes(gif87Bytes);
      expect(result.isValid, isFalse);
      expect(
        result.errorMessage,
        "GIF images aren't supported. Please choose a JPG, PNG, or WebP image.",
      );
    });

    test('rejects random bytes and unsupported formats (PDF, BMP, text)', () async {
      final randomBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
      final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]); // %PDF-1.4
      final bmpBytes = Uint8List.fromList([0x42, 0x4D, 0x36, 0x00, 0x00, 0x00]); // BM

      for (final bytes in [randomBytes, pdfBytes, bmpBytes, Uint8List(0)]) {
        final result = checkImageBytes(bytes);
        expect(result.isValid, isFalse);
        expect(
          result.errorMessage,
          'Unsupported image format. Please choose a JPG, PNG, or WebP image.',
        );
      }
    });

    test('rejects files larger than 5 MB with size error message', () {
      // 5 MB = 5 * 1024 * 1024 = 5,242,880 bytes
      const maxAllowed = 5 * 1024 * 1024;
      final oversizedBytes = Uint8List(maxAllowed + 1);

      final result = checkImageBytes(oversizedBytes);
      expect(result.isValid, isFalse);
      expect(
        result.errorMessage,
        'Image is too large. Please choose an image under 5 MB.',
      );
    });
  });

  group('ImageUtils static wrapper delegation tests', () {
    test('ImageUtils.validateImageBytes delegates correctly without recursion', () {
      final jpegBytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      ]);
      final result = ImageUtils.validateImageBytes(jpegBytes);
      expect(result.isValid, isTrue);
      expect(result.mimeType, 'image/jpeg');
      expect(result.fileExtension, '.jpg');

      final invalid = ImageUtils.validateImageBytes(Uint8List.fromList([1, 2, 3]));
      expect(invalid.isValid, isFalse);
    });

    test('ImageUtils.validateImage delegates correctly without recursion', () async {
      final pngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      ]);
      final file = XFile.fromData(pngBytes, name: 'test.png');
      final result = await ImageUtils.validateImage(file);
      expect(result.isValid, isTrue);
      expect(result.mimeType, 'image/png');
      expect(result.fileExtension, '.png');

      final invalidFile = XFile.fromData(
        Uint8List.fromList([0x47, 0x49, 0x46, 0x38]),
        name: 'test.gif',
      );
      final invalidResult = await ImageUtils.validateImage(invalidFile);
      expect(invalidResult.isValid, isFalse);
      expect(
        invalidResult.errorMessage,
        "GIF images aren't supported. Please choose a JPG, PNG, or WebP image.",
      );
    });
  });
}
