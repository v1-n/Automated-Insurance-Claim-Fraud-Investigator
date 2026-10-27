import 'dart:io';
import 'package:image/image.dart' as img;

class ImageCompressor {
  /// Compresses and resizes an image file if it exceeds 1MB.
  /// Non-image files (like PDFs) are returned untouched.
  static Future<File> compressIfNeeded(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    const supportedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'bmp'];
    if (!supportedExtensions.contains(ext)) {
      return file;
    }

    try {
      final size = await file.length();
      // If already under 1MB, keep as is
      if (size <= 1024 * 1024) {
        return file;
      }

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return file;

      // Downscale if exceeds 1920x1080 while preserving aspect ratio
      img.Image resized = image;
      if (image.width > 1920 || image.height > 1080) {
        if (image.width >= image.height) {
          resized = img.copyResize(image, width: 1920);
        } else {
          resized = img.copyResize(image, height: 1080);
        }
      }

      // Encode as JPEG with 80% quality (slashes 15MB down to ~400KB)
      final compressedBytes = img.encodeJpg(resized, quality: 80);

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
