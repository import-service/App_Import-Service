import 'dart:async';

import 'package:flutter/material.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/logging/app_log.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/core/util/vin_from_scan.dart';
import 'package:import_service_app/presentation/widgets/app_bar/brand_primary_app_bar.dart';
import 'package:import_service_app/presentation/widgets/scan/qr_scanner_overlay.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Сканер QR лобового стекла → возвращает VIN (или сырой текст) через [Navigator.pop].
class SvhQrScanPage extends StatefulWidget {
  const SvhQrScanPage({super.key});

  @override
  State<SvhQrScanPage> createState() => _SvhQrScanPageState();
}

class _SvhQrScanPageState extends State<SvhQrScanPage> {
  late final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    autoStart: true,
  );
  bool _handled = false;
  bool _torchOn = false;
  bool _timedOut = false;
  Timer? _timeoutTimer;

  static const Duration _noReadTimeout = Duration(seconds: 25);

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(_noReadTimeout, _onScanTimeout);
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onScanTimeout() {
    if (!mounted || _handled) return;
    setState(() => _timedOut = true);
    sl<AppFeedbackService>().show(
      sl<JsonStringsService>().text('svhQrScanFailed'),
      kind: AppFeedbackKind.warning,
    );
  }

  void _retryAfterTimeout() {
    setState(() {
      _timedOut = false;
      _handled = false;
    });
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_noReadTimeout, _onScanTimeout);
    unawaited(_controller.start());
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    String raw = '';
    for (final b in capture.barcodes) {
      final v = b.rawValue?.trim() ?? '';
      if (v.isEmpty) continue;
      raw = v;
      if (b.format == BarcodeFormat.qrCode) break;
    }
    if (raw.isEmpty) return;

    AppLog.trace('QR detect raw="$raw"', tag: 'SvhQr');
    _handled = true;
    _timeoutTimer?.cancel();
    final vin = extractVinFromScanPayload(raw) ?? raw.trim();
    AppLog.trace('QR resolved vin="$vin"', tag: 'SvhQr');
    if (!mounted) return;
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
          const QrScannerOverlay(),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _timedOut
                        ? s.text('svhQrScanFailed')
                        : s.text('svhQrScanHint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                    ),
                  ),
                  if (_timedOut) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _retryAfterTimeout,
                      child: Text(s.text('svhQrScanRetry')),
                    ),
                  ],
                  const SizedBox(height: 16),
                  IconButton(
                    icon: Icon(
                      _torchOn ? Icons.flash_on : Icons.flash_off,
                      color: _torchOn ? Colors.yellow : Colors.white,
                      size: 36,
                    ),
                    tooltip: 'Фонарик',
                    onPressed: () async {
                      await _controller.toggleTorch();
                      if (mounted) setState(() => _torchOn = !_torchOn);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
