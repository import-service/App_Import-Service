import 'package:flutter/material.dart';
import 'package:import_service_app/core/constants/asset_paths.dart';

/// Логотип на экране входа: ширина [widthFactor] от ширины экрана.
class LoginBrandLogo extends StatelessWidget {
  const LoginBrandLogo({super.key, this.widthFactor = 0.5});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width * widthFactor;
    return Center(
      child: Image.asset(
        AssetPaths.image('logo_main.png'),
        width: w,
        fit: BoxFit.contain,
      ),
    );
  }
}
