import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageCompressor {
  /// Compresses and resizes an image file if it exceeds 1MB.
  /// Non-image files (like PDFs) are returned untouched.
  /// Heavy image decoding, resizing, and JPEG encoding are executed
  /// in a separate Isolate using Isolate.run to prevent Flutter UI stutter.
  static Future<File> compressIfNeeded(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    const supportedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'bmp'];
    if (!supportedExtensions.contains(ext)) {
      return file;
    }

    try {
      final size = await file.length();
      // If already under 5MB (well within the 10MB upload limit), keep original file to preserve pristine EXIF metadata
      if (size <= 5 * 1024 * 1024) {
        return file;
      }

      final bytes = await file.readAsBytes();

      // Offload CPU-intensive decoding, downsampling, and encoding to a background isolate
      final Uint8List? compressedBytes = await Isolate.run<Uint8List?>(() {
        final image = img.decodeImage(bytes);
        if (image == null) return null;

        img.Image resized = image;
        if (image.width > 1920 || image.height > 1080) {
          if (image.width >= image.height) {
            resized = img.copyResize(image, width: 1920);
          } else {
            resized = img.copyResize(image, height: 1080);
          }
          // Explicitly preserve EXIF metadata from original image
          resized.exif = image.exif;
        }

        final encoded = img.encodeJpg(resized, quality: 85);
        return Uint8List.fromList(encoded);
      });

      if (compressedBytes == null) {
        return file;
      }

      final tempDir = file.parent.path;
      final cleanBaseName = file.path.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
      final compressedPath = '$tempDir/scaled_${DateTime.now().millisecondsSinceEpoch}_$cleanBaseName.jpg';
      final compressedFile = File(compressedPath);
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    } catch (_) {
      // Fallback to original file if processing encounters an error
      return file;
    }
  }
}
