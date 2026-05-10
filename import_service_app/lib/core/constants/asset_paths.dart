import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Единая точка хранения путей ассетов.
abstract final class AssetPaths {
  static const String _imagesDir = 'assets/images';
  static const String _svgDir = 'assets/svg';

  /// Возвращает путь вида `assets/images/<fileName>`.
  static String image(String fileName) => '$_imagesDir/$fileName';

  /// Возвращает путь вида `assets/svg/<fileName>`.
  static String svg(String fileName) => '$_svgDir/$fileName';

  /// Короткий хелпер для raster-изображений.
  static Image raster(
    String fileName, {
    Key? imageKey,
    double? width,
    double? height,
    BoxFit? fit,
  }) {
    return Image.asset(
      image(fileName),
      key: imageKey,
      width: width,
      height: height,
      fit: fit,
    );
  }

  /// Короткий хелпер для SVG.
  static SvgPicture vector(
    String fileName, {
    Key? svgKey,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return SvgPicture.asset(
      svg(fileName),
      key: svgKey,
      width: width,
      height: height,
      fit: fit,
    );
  }
}
