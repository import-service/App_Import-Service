import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';

/// Горизонтальный ряд фото по URL (детализация заявки).
class RequestDetailPhotoUrlsRow extends StatelessWidget {
  const RequestDetailPhotoUrlsRow({
    super.key,
    required this.urls,
    required this.onTileTap,
  });

  final List<String> urls;
  final void Function(int index) onTileTap;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final u = urls[i].trim();
          return Material(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => onTileTap(i),
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _PhotoTile(u: u),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.u});

  final String u;

  @override
  Widget build(BuildContext context) {
    final isNetwork = u.startsWith('http://') || u.startsWith('https://');
    if (isNetwork) {
      return Image.network(
        u,
        width: 104,
        height: 88,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
        loadingBuilder: (c, w, p) {
          if (p == null) return w;
          return SizedBox(
            width: 104,
            height: 88,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                ),
              ),
            ),
          );
        },
      );
    }
    if (u.startsWith('assets/')) {
      return Image.asset(
        u,
        width: 104,
        height: 88,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 104,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.requestCardBorder),
        color: AppTheme.pageBackground,
      ),
      child: Icon(
        Icons.broken_image_outlined,
        size: 32,
        color: AppTheme.textSecondary.withValues(alpha: 0.5),
      ),
    );
  }
}
