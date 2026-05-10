import 'package:flutter/material.dart';

/// Круглый аватар с картинкой из [imageProvider].
class ProfileAvatarCircle extends StatelessWidget {
  const ProfileAvatarCircle({
    super.key,
    required this.imageProvider,
    this.size = 128,
  });

  final ImageProvider imageProvider;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12),
        image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
      ),
    );
  }
}
