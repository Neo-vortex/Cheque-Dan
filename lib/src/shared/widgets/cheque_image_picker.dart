import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Doc scanner import — guarded so it doesn't break non-mobile builds
// ═══════════════════════════════════════════════════════════════════════════
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';

class ChequeImagePicker extends StatelessWidget {
  final List<String> imagePaths;
  final Function(List<String>) onChanged;
  final int maxImages;

  const ChequeImagePicker({
    super.key,
    required this.imagePaths,
    required this.onChanged,
    this.maxImages = 4,
  });

  Future<void> _pickFromGallery(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final remaining = maxImages - imagePaths.length;
      final files = await picker.pickMultiImage(imageQuality: 90, limit: remaining);
      if (files.isEmpty) return;
      final paths = [...imagePaths, ...files.map((f) => f.path)];
      onChanged(paths.take(maxImages).toList());
    } catch (e) {
      _showError(context, 'خطا در انتخاب تصویر');
    }
  }

  Future<void> _pickFromCamera(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
          source: ImageSource.camera, imageQuality: 90);
      if (file == null) return;
      onChanged([...imagePaths, file.path]);
    } catch (e) {
      _showError(context, 'خطا در دوربین');
    }
  }

  Future<void> _scanDocument(BuildContext context) async {
    try {
      // getScannedDocumentAsImages returns dynamic (List at runtime)
      final dynamic result = await FlutterDocScanner()
          .getScannedDocumentAsImages(page: 4);
      if (result == null) return;
      final List<String> scanned = (result as List)
          .map((p) => p.toString())
          .toList();
      if (scanned.isEmpty) return;
      final paths = [...imagePaths, ...scanned];
      onChanged(paths.take(maxImages).toList());
    } catch (e) {
      _showError(context, 'خطا در اسکن سند');
    }
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.returned),
    );
  }

  void _removeImage(int index) {
    final updated = List<String>.from(imagePaths)..removeAt(index);
    onChanged(updated);
  }

  void _showFullscreen(BuildContext context, String path, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImagePreviewScreen(
          path: path,
          onDelete: () {
            _removeImage(index);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = imagePaths.length < maxImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thumbnails grid
        if (imagePaths.isNotEmpty) ...[
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imagePaths.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) => _Thumbnail(
                path: imagePaths[i],
                onTap: () => _showFullscreen(ctx, imagePaths[i], i),
                onDelete: () => _removeImage(i),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        // Action buttons
        if (canAdd)
          Row(
            children: [
              _ActionBtn(
                icon: Icons.photo_library_outlined,
                label: 'گالری',
                onTap: () => _pickFromGallery(context),
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                icon: Icons.camera_alt_outlined,
                label: 'دوربین',
                onTap: () => _pickFromCamera(context),
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                icon: Icons.document_scanner_outlined,
                label: 'اسکن',
                onTap: () => _scanDocument(context),
                highlight: true,
              ),
            ],
          ),
        if (imagePaths.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${imagePaths.length} از $maxImages تصویر',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textHint),
            ),
          ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String path;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _Thumbnail({
    required this.path,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(path),
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 90,
                height: 90,
                color: AppColors.surfaceVariant,
                child: const Icon(Icons.broken_image_outlined,
                    color: AppColors.textHint),
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onDelete();
              },
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: highlight
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: highlight ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 20,
                  color: highlight
                      ? AppColors.primary
                      : AppColors.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: highlight
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FULL SCREEN PREVIEW
// ═══════════════════════════════════════════════════════════════════════════

class _ImagePreviewScreen extends StatelessWidget {
  final String path;
  final VoidCallback onDelete;

  const _ImagePreviewScreen({required this.path, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('پیش‌نمایش تصویر'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.returned),
            onPressed: () {
              HapticFeedback.mediumImpact();
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('حذف تصویر'),
                  content: const Text('آیا از حذف این تصویر مطمئن هستید؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('انصراف'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete();
                      },
                      child: const Text('حذف',
                          style: TextStyle(color: AppColors.returned)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 80,
            ),
          ),
        ),
      ),
    );
  }
}
