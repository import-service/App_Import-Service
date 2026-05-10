import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_unified_image_picker/flutter_unified_image_picker.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/data/local/request_draft_attachments_space.dart';
import 'package:import_service_app/presentation/widgets/app_bar/brand_primary_app_bar.dart';
import 'package:import_service_app/presentation/widgets/buttons/app_primary_filled_wide_button.dart';
import 'package:import_service_app/presentation/widgets/forms/request_photo_row_field.dart';

class RequestFilesPayload {
  const RequestFilesPayload({
    required this.passportFrontPaths,
    required this.passportAddressPaths,
    required this.innPaths,
    required this.snilsPaths,
    required this.invoicePaths,
    required this.contractPaths,
    required this.paymentReceiptPaths,
    required this.vinPlatePhotoPaths,
    required this.odometerPhotoPaths,
    required this.carFrontPhotoPaths,
    required this.carRearPhotoPaths,
    required this.additionalFile1Paths,
    required this.additionalFile2Paths,
  });

  final List<String> passportFrontPaths;
  final List<String> passportAddressPaths;
  final List<String> innPaths;
  final List<String> snilsPaths;
  final List<String> invoicePaths;
  final List<String> contractPaths;
  final List<String> paymentReceiptPaths;
  final List<String> vinPlatePhotoPaths;
  final List<String> odometerPhotoPaths;
  final List<String> carFrontPhotoPaths;
  final List<String> carRearPhotoPaths;
  final List<String> additionalFile1Paths;
  final List<String> additionalFile2Paths;

  bool get allRequiredReady =>
      passportFrontPaths.isNotEmpty &&
      passportAddressPaths.isNotEmpty &&
      innPaths.isNotEmpty &&
      snilsPaths.isNotEmpty &&
      invoicePaths.isNotEmpty &&
      contractPaths.isNotEmpty &&
      paymentReceiptPaths.isNotEmpty &&
      vinPlatePhotoPaths.isNotEmpty &&
      odometerPhotoPaths.isNotEmpty &&
      carFrontPhotoPaths.isNotEmpty &&
      carRearPhotoPaths.isNotEmpty;
}

class RequestFilesUploadPage extends StatefulWidget {
  const RequestFilesUploadPage({
    super.key,
    required this.draftId,
    required this.initial,
  });

  final String draftId;
  final RequestFilesPayload initial;

  @override
  State<RequestFilesUploadPage> createState() => _RequestFilesUploadPageState();
}

class _RequestFilesUploadPageState extends State<RequestFilesUploadPage> {
  late final List<String> _passportFrontPaths =
      List<String>.from(widget.initial.passportFrontPaths);
  late final List<String> _passportAddressPaths =
      List<String>.from(widget.initial.passportAddressPaths);
  late final List<String> _innPaths = List<String>.from(widget.initial.innPaths);
  late final List<String> _snilsPaths =
      List<String>.from(widget.initial.snilsPaths);
  late final List<String> _invoicePaths =
      List<String>.from(widget.initial.invoicePaths);
  late final List<String> _contractPaths =
      List<String>.from(widget.initial.contractPaths);
  late final List<String> _paymentReceiptPaths =
      List<String>.from(widget.initial.paymentReceiptPaths);
  late final List<String> _vinPlatePhotoPaths =
      List<String>.from(widget.initial.vinPlatePhotoPaths);
  late final List<String> _odometerPhotoPaths =
      List<String>.from(widget.initial.odometerPhotoPaths);
  late final List<String> _carFrontPhotoPaths =
      List<String>.from(widget.initial.carFrontPhotoPaths);
  late final List<String> _carRearPhotoPaths =
      List<String>.from(widget.initial.carRearPhotoPaths);
  late final List<String> _additionalFile1Paths =
      List<String>.from(widget.initial.additionalFile1Paths);
  late final List<String> _additionalFile2Paths =
      List<String>.from(widget.initial.additionalFile2Paths);

  Future<void> _addPhotoTo(List<String> target) async {
    final path = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (ctx) => Theme(
          data: Theme.of(ctx).copyWith(
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            iconButtonTheme: IconButtonThemeData(
              style: ButtonStyle(
                padding: WidgetStateProperty.all(EdgeInsets.zero),
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          child: const CameraView(hideGalleryInSheet: false),
        ),
      ),
    );
    if (!mounted || path == null || path.isEmpty) return;
    final stored = await RequestDraftAttachmentsSpace.ingestPickedFile(
      draftId: widget.draftId,
      sourcePath: path,
    );
    if (!mounted || stored.isEmpty) return;
    setState(() => target.add(stored));
  }

  void _removePhotoFrom(List<String> target, int index) {
    if (index < 0 || index >= target.length) return;
    final path = target[index];
    setState(() => target.removeAt(index));
    unawaited(
      RequestDraftAttachmentsSpace.tryDeleteFileUnderAttachmentsRoot(path),
    );
  }

  void _complete() {
    Navigator.of(context).pop(
      RequestFilesPayload(
        passportFrontPaths: _passportFrontPaths,
        passportAddressPaths: _passportAddressPaths,
        innPaths: _innPaths,
        snilsPaths: _snilsPaths,
        invoicePaths: _invoicePaths,
        contractPaths: _contractPaths,
        paymentReceiptPaths: _paymentReceiptPaths,
        vinPlatePhotoPaths: _vinPlatePhotoPaths,
        odometerPhotoPaths: _odometerPhotoPaths,
        carFrontPhotoPaths: _carFrontPhotoPaths,
        carRearPhotoPaths: _carRearPhotoPaths,
        additionalFile1Paths: _additionalFile1Paths,
        additionalFile2Paths: _additionalFile2Paths,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = sl<JsonStringsService>();
    return Scaffold(
      appBar: BrandPrimaryAppBar(title: s.text('requestFilesTitle')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              _row(s.text('reqPassportFrontLabel'), _passportFrontPaths, markRequired: true),
              _row(s.text('reqPassportAddressLabel'), _passportAddressPaths, markRequired: true),
              _row(s.text('reqInnFileLabel'), _innPaths, markRequired: true),
              _row(s.text('reqSnilsFileLabel'), _snilsPaths, markRequired: true),
              _row(s.text('reqInvoiceFileLabel'), _invoicePaths, markRequired: true),
              _row(s.text('reqContractFileLabel'), _contractPaths, markRequired: true),
              _row(s.text('reqPaymentReceiptFileLabel'), _paymentReceiptPaths, markRequired: true),
              _row(s.text('reqVinPlateFileLabel'), _vinPlatePhotoPaths, markRequired: true),
              _row(s.text('reqOdometerFileLabel'), _odometerPhotoPaths, markRequired: true),
              _row(s.text('reqCarFrontFileLabel'), _carFrontPhotoPaths, markRequired: true),
              _row(s.text('reqCarRearFileLabel'), _carRearPhotoPaths, markRequired: true),
              _row(s.text('reqAdditionalFile1Label'), _additionalFile1Paths, markRequired: false),
              _row(s.text('reqAdditionalFile2Label'), _additionalFile2Paths, markRequired: false),
              const SizedBox(height: 16),
              AppPrimaryFilledWideButton(
                label: s.text('requestFilesDoneButton'),
                onPressed: _complete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    String title,
    List<String> target, {
    required bool markRequired,
  }) {
    final s = sl<JsonStringsService>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: RequestPhotoRowField(
        title: title,
        addLabel: s.text('requestUploadButton'),
        photoPaths: target,
        onAddTap: () => _addPhotoTo(target),
        onRemoveTap: (index) => _removePhotoFrom(target, index),
        markRequired: markRequired,
      ),
    );
  }
}
