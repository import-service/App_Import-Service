import 'package:flutter/material.dart';
import 'package:import_service_app/core/constants/asset_paths.dart';

/// Аватар профиля: опционально фото; иначе логотип Import Service.
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

  static const String _brandLogoFile = 'logo_import_service.png';

  @override
  Widget build(BuildContext context) {
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
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12),
        color: Colors.white,
      ),
      child: Image.asset(
        AssetPaths.image(_brandLogoFile),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
