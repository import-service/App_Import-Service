import 'package:flutter/material.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/core/util/vin_from_scan.dart';
import 'package:import_service_app/presentation/widgets/app_bar/brand_primary_app_bar.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Сканер QR лобового стекла → возвращает VIN (или сырой текст) через [Navigator.pop].
class SvhQrScanPage extends StatefulWidget {
  const SvhQrScanPage({super.key});

  @override
  State<SvhQrScanPage> createState() => _SvhQrScanPageState();
}

class _SvhQrScanPageState extends State<SvhQrScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue?.trim() ?? '')
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    if (raw.isEmpty) return;
    _handled = true;
    final vin = extractVinFromScanPayload(raw) ?? raw;
    Navigator.of(context).pop(vin);
  }

  @override
  Widget build(BuildContext context) {
    final s = sl<JsonStringsService>();
    return Scaffold(
      appBar: BrandPrimaryAppBar(title: s.text('svhQrScanTitle')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Text(
                s.text('svhQrScanHint'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
