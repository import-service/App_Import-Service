import 'dart:io';

import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

/// Горизонтальный ряд: кнопка «+» и превью. [maxPhotos] — лимит (1 для заявки v2).
class RequestPhotoRowField extends StatelessWidget {
  const RequestPhotoRowField({
    super.key,
    required this.title,
    required this.addLabel,
    required this.photoPaths,
    required this.onAddTap,
    required this.onRemoveTap,
    this.markRequired = true,
    this.maxPhotos,
  });

  final String title;
  final String addLabel;
  final List<String> photoPaths;
  final VoidCallback onAddTap;
  final ValueChanged<int> onRemoveTap;
  final bool markRequired;
  /// `1` — один файл на слот (кнопка «+» скрыта, пока файл есть).
  final int? maxPhotos;

  bool get _canAddMore {
    if (maxPhotos == 1) return photoPaths.isEmpty;
    if (maxPhotos != null) return photoPaths.length < maxPhotos!;
    return true;
  }

  int get _visiblePhotoCount {
    if (maxPhotos == 1 && photoPaths.isNotEmpty) return 1;
    if (maxPhotos != null) {
      return photoPaths.length.clamp(0, maxPhotos!);
    }
    return photoPaths.length;
  }

  @override
  Widget build(BuildContext context) {
    final labelBase = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: const Color(0xFF7C7C7C),
          fontWeight: FontWeight.w700,
        );
    final itemCount = (_canAddMore ? 1 : 0) + _visiblePhotoCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: labelBase,
            children: [
              TextSpan(text: title),
              if (markRequired)
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (_canAddMore && index == 0) {
                return _AddPhotoTile(label: addLabel, onTap: onAddTap);
              }
              final photoIndex = _canAddMore ? index - 1 : index;
              final path = photoPaths[photoIndex];
              return _PhotoTile(
                path: path,
                onRemoveTap: () => onRemoveTap(photoIndex),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F7FD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD7E6F6)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: AppTheme.primaryBlue, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.path, required this.onRemoveTap});

  final String path;
  final VoidCallback onRemoveTap;

  @override
  Widget build(BuildContext context) {
    final imageWidget = _isRemoteUrl(path)
        ? Image.network(
            path,
            width: 140,
            height: 104,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _errorTile(),
          )
        : Image.file(
            File(path),
            width: 140,
            height: 104,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _errorTile(),
          );

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imageWidget,
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemoveTap,
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static bool _isRemoteUrl(String value) {
    final v = value.trim().toLowerCase();
    return v.startsWith('http://') || v.startsWith('https://');
  }

  static Widget _errorTile() {
    return Container(
      width: 140,
      height: 104,
      color: const Color(0xFFEFEFEF),
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}
