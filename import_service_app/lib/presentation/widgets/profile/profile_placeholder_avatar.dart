import 'package:flutter/material.dart';

/// Аватар: опционально фото; иначе иконка пользователя в круге.
class ProfilePlaceholderAvatar extends StatelessWidget {
  const ProfilePlaceholderAvatar({
    super.key,
    required this.usePhoto,
    this.photoProvider,
    this.size = 128,
  });

  final bool usePhoto;
  final ImageProvider? photoProvider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (usePhoto && photoProvider != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black12),
          image: DecorationImage(image: photoProvider!, fit: BoxFit.cover),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      ),
      child: Icon(
        Icons.person_rounded,
        size: size * 0.45,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
