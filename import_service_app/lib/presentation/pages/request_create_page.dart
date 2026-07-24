import 'dart:async';

import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_app/core/auth/auth_service.dart';
import 'package:import_service_app/core/auth/auth_session_controller.dart';
import 'package:import_service_app/core/auth/session_preferences_keys.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/error/failures.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/data/demo/demo_profile_snapshot.dart';
import 'package:import_service_app/data/local/request_draft_attachments_space.dart';
import 'package:import_service_app/data/models/request_draft.dart';
import 'package:import_service_app/data/models/request_form_model.dart';
import 'package:import_service_app/data/models/registration_request_model.dart';
import 'package:import_service_app/domain/entities/create_vehicle_result.dart';
import 'package:import_service_app/domain/entities/request_files_batch_upload_result.dart';
import 'package:import_service_app/domain/repositories/cars_repository.dart';
import 'package:import_service_app/presentation/bloc/request_draft/request_draft_cubit.dart';
import 'package:import_service_app/presentation/helpers/masked_field_validation.dart';
import 'package:import_service_app/presentation/helpers/request_attach_failure_message.dart';
import 'package:import_service_app/presentation/helpers/session_auth_error.dart';
import 'package:import_service_app/presentation/helpers/vin_validation.dart';
import 'package:import_service_app/presentation/pages/request_files_upload_page.dart';
import 'package:import_service_app/presentation/widgets/app_bar/brand_primary_app_bar.dart';
import 'package:import_service_app/presentation/widgets/buttons/app_logout_outlined_wide_button.dart';
import 'package:import_service_app/presentation/widgets/buttons/app_primary_filled_wide_button.dart';
import 'package:import_service_app/presentation/widgets/buttons/app_primary_outlined_wide_button.dart';
import 'package:import_service_app/presentation/widgets/forms/fields/app_inn_field.dart';
import 'package:import_service_app/presentation/widgets/forms/fields/app_phone_ru_field.dart';
import 'package:import_service_app/presentation/widgets/forms/fields/app_snils_field.dart';
import 'package:import_service_app/presentation/widgets/forms/input_formatters/inn_input_formatter.dart';
import 'package:import_service_app/presentation/widgets/forms/input_formatters/phone_ru_input_formatter.dart';
import 'package:import_service_app/presentation/widgets/forms/input_formatters/snils_input_formatter.dart';
import 'package:import_service_app/presentation/widgets/forms/input_formatters/vin_input_formatter.dart';
import 'package:import_service_app/presentation/widgets/forms/request_labeled_input_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RequestCreatePage extends StatefulWidget {
  const RequestCreatePage({super.key, this.draftId});

  final String? draftId;

  @override
  State<RequestCreatePage> createState() => _RequestCreatePageState();
}

class _RequestCreatePageState extends State<RequestCreatePage> {
  final _companyNameController = TextEditingController();
  final _companyInnController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _personNameController = TextEditingController();
  final _personPhoneController = TextEditingController();
  final _personSnilsController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _vinController = TextEditingController();
  final _commentController = TextEditingController();

  late final String _draftId;
  Timer? _debounce;
  bool _explicitDraftSaved = false;
  bool _submitting = false;
  String? _submitRuntimeError;
  int _uploadDone = 0;
  int _uploadTotal = 0;
  String? _pendingRequestId;
  List<String> _failedUploadDocTypes = const [];
  OrganizationType _organizationType = OrganizationType.ooo;

  bool _hasSunroof = false;
  bool _hasAllWheelDrive = false;
  bool _wasInRussiaLast12Months = false;
  bool _hasOtherCars = false;

  RequestFilesPayload _files = const RequestFilesPayload(
    passportFrontPaths: [],
    passportAddressPaths: [],
    innPaths: [],
    snilsPaths: [],
    invoicePaths: [],
    contractPaths: [],
    paymentReceiptPaths: [],
    vinPlatePhotoPaths: [],
    odometerPhotoPaths: [],
    carFrontPhotoPaths: [],
    carRearPhotoPaths: [],
    additionalFile1Paths: [],
    additionalFile2Paths: [],
  );

  void _onAnyFieldChanged() {
    if (mounted) setState(() {});
    _scheduleSave();
  }

  RequestFormModel _buildForm() => RequestFormModel(
        organizationType: _organizationType,
        companyName: _companyNameController.text,
        companyInn: _innDigits(_companyInnController.text),
        companyEmail: _companyEmailController.text,
        companyPhone: _normalizePhoneForApi(_companyPhoneController.text),
        personFullName: _personNameController.text,
        personPhone: _normalizePhoneForApi(_personPhoneController.text),
        personSnils: _snilsDigits(_personSnilsController.text),
        carBrand: _brandController.text,
        carModel: _modelController.text,
        vin: _vinController.text.trim().toUpperCase(),
        hasSunroof: _hasSunroof,
        hasAllWheelDrive: _hasAllWheelDrive,
        wasInRussiaLast12Months: _wasInRussiaLast12Months,
        hasOtherCars: _hasOtherCars,
        comment: _commentController.text,
        passportFrontPaths: List<String>.from(_files.passportFrontPaths),
        passportAddressPaths: List<String>.from(_files.passportAddressPaths),
        innPaths: List<String>.from(_files.innPaths),
        snilsPaths: List<String>.from(_files.snilsPaths),
        invoicePaths: List<String>.from(_files.invoicePaths),
        contractPaths: List<String>.from(_files.contractPaths),
        paymentReceiptPaths: List<String>.from(_files.paymentReceiptPaths),
        vinPlatePhotoPaths: List<String>.from(_files.vinPlatePhotoPaths),
        odometerPhotoPaths: List<String>.from(_files.odometerPhotoPaths),
        carFrontPhotoPaths: List<String>.from(_files.carFrontPhotoPaths),
        carRearPhotoPaths: List<String>.from(_files.carRearPhotoPaths),
        additionalFile1Paths: List<String>.from(_files.additionalFile1Paths),
        additionalFile2Paths: List<String>.from(_files.additionalFile2Paths),
      );

  bool _shouldAutoPersist() => RequestFormModel.countFilledFields(_buildForm()) > 0;

  bool _validateForSubmit() {
    final s = sl<JsonStringsService>();
    final email = _companyEmailController.text.trim();
    final innDigits = _innDigits(_companyInnController.text);
    final vin = _vinController.text.trim().toUpperCase();
    final personPhoneDigits = _phoneDigits(_personPhoneController.text);
    final companyPhoneDigits = _phoneDigits(_companyPhoneController.text);
    final snilsRaw = _snilsDigits(_personSnilsController.text);

    final personName = _personNameController.text.trim();
    if (_companyNameController.text.trim().isEmpty ||
        innDigits.isEmpty ||
        personName.isEmpty ||
        _brandController.text.trim().isEmpty ||
        _modelController.text.trim().isEmpty ||
        email.isEmpty ||
        companyPhoneDigits.isEmpty ||
        personPhoneDigits.isEmpty ||
        snilsRaw.isEmpty ||
        vin.isEmpty) {
      sl<AppFeedbackService>().show(s.fieldRequiredError, kind: AppFeedbackKind.error);
      return false;
    }
    if (!_isValidEmail(email)) {
      sl<AppFeedbackService>().show(s.emailFormatError, kind: AppFeedbackKind.error);
      return false;
    }
    if (!_isValidInn(innDigits, _organizationType)) {
      sl<AppFeedbackService>().show(
        s.innFormatErrorFor(_organizationType),
        kind: AppFeedbackKind.error,
      );
      return false;
    }
    if (!isValidRuPhoneDigits(companyPhoneDigits) ||
        !isValidRuPhoneDigits(personPhoneDigits)) {
      sl<AppFeedbackService>().show(s.phoneFormatError, kind: AppFeedbackKind.error);
      return false;
    }
    if (snilsRaw.length != snilsDigitCount) {
      sl<AppFeedbackService>().show(s.text('snilsLengthError'), kind: AppFeedbackKind.error);
      return false;
    }
    if (!isValidSnilsDigits(snilsRaw)) {
      sl<AppFeedbackService>().show(s.text('snilsChecksumError'), kind: AppFeedbackKind.error);
      return false;
    }
    if (!_isValidVin(vin)) {
      sl<AppFeedbackService>().show(
        vinValidationMessage(vin, s) ?? s.text('vinFormatError'),
        kind: AppFeedbackKind.error,
      );
      return false;
    }
    if (!_files.allRequiredReady) {
      sl<AppFeedbackService>().show(
        s.text('requestFilesRequiredError'),
        kind: AppFeedbackKind.error,
      );
      return false;
    }
    return true;
  }

  bool get _isSubmitEnabled {
    final email = _companyEmailController.text.trim();
    final innDigits = _innDigits(_companyInnController.text);
    final vin = _vinController.text.trim().toUpperCase();
    final personPhoneDigits = _phoneDigits(_personPhoneController.text);
    final companyPhoneDigits = _phoneDigits(_companyPhoneController.text);
    final snilsRaw = _snilsDigits(_personSnilsController.text);
    final personName = _personNameController.text.trim();
    final hasRequiredText = _companyNameController.text.trim().isNotEmpty &&
        innDigits.isNotEmpty &&
        personName.isNotEmpty &&
        _brandController.text.trim().isNotEmpty &&
        _modelController.text.trim().isNotEmpty &&
        email.isNotEmpty &&
        companyPhoneDigits.isNotEmpty &&
        personPhoneDigits.isNotEmpty &&
        snilsRaw.isNotEmpty &&
        vin.isNotEmpty;
    if (!hasRequiredText) return false;
    final formatsOk = _isValidEmail(email) &&
        _isValidInn(innDigits, _organizationType) &&
        isValidRuPhoneDigits(companyPhoneDigits) &&
        isValidRuPhoneDigits(personPhoneDigits) &&
        isValidSnilsDigits(snilsRaw) &&
        _isValidVin(vin);
    return formatsOk && _files.allRequiredReady && !_submitting;
  }

  String? get _submitBlockReason {
    final s = sl<JsonStringsService>();
    String missing(String label) => 'Не заполнено поле: $label';

    final companyName = _companyNameController.text.trim();
    final companyInn = _innDigits(_companyInnController.text);
    final companyEmail = _companyEmailController.text.trim();
    final companyPhone = _phoneDigits(_companyPhoneController.text);
    final personName = _personNameController.text.trim();
    final personPhone = _phoneDigits(_personPhoneController.text);
    final personSnils = _snilsDigits(_personSnilsController.text);
    final carBrand = _brandController.text.trim();
    final carModel = _modelController.text.trim();
    final vin = _vinController.text.trim().toUpperCase();

    if (companyName.isEmpty) {
      return missing(
        _organizationType == OrganizationType.person
            ? s.text('requestPersonApplicantNameLabel')
            : s.text('requestCompanyNameLabel'),
      );
    }
    if (companyInn.isEmpty) return missing(s.innLabel);
    if (companyEmail.isEmpty) return missing(s.text('requestCompanyEmailLabel'));
    if (companyPhone.isEmpty) return missing(s.text('requestCompanyPhoneLabel'));
    if (personName.isEmpty) return missing(s.text('requestPersonNameLabel'));
    if (personPhone.isEmpty) return missing(s.text('requestPersonPhoneLabel'));
    if (personSnils.isEmpty) return missing(s.text('requestSnilsLabel'));
    if (carBrand.isEmpty) return missing(s.text('requestCarBrandLabel'));
    if (carModel.isEmpty) return missing(s.text('requestCarModelLabel'));
    if (vin.isEmpty) return missing(s.text('requestVinLabel'));

    if (!_isValidEmail(companyEmail)) return s.emailFormatError;
    if (!_isValidInn(companyInn, _organizationType)) {
      return s.innFormatErrorFor(_organizationType);
    }
    if (!isValidRuPhoneDigits(companyPhone) || !isValidRuPhoneDigits(personPhone)) {
      return s.phoneFormatError;
    }
    if (personSnils.length != snilsDigitCount) return s.text('snilsLengthError');
    if (!isValidSnilsDigits(personSnils)) return s.text('snilsChecksumError');
    if (!_isValidVin(vin)) {
      return vinValidationMessage(vin, s) ?? s.text('vinFormatError');
    }
    if (!_files.allRequiredReady) return s.text('requestFilesRequiredError');
    return null;
  }

  String _snilsDigits(String value) => snilsDigitsOnly(value);
  String _innDigits(String value) => innDigitsOnly(value);
  String _phoneDigits(String value) => ruPhoneDigitsOnly(value);

  String _normalizePhoneForApi(String value) => normalizeRuPhoneForApi(value);

  bool _isValidEmail(String email) {
    if (email.contains('..')) {
      return false;
    }
    const pattern = r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
    return RegExp(pattern).hasMatch(email);
  }

  bool _isValidVin(String vin) => isValidVin(vin);
  bool _isValidInn(String digits, OrganizationType orgType) =>
      isValidInnDigits(digits, orgType);

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted || !_shouldAutoPersist()) return;
      await _writeDraft();
    });
  }

  Future<void> _writeDraft() async {
    await sl<RequestDraftCubit>().upsert(
      RequestDraft(
        id: _draftId,
        updatedAt: DateTime.now(),
        form: _buildForm(),
      ),
    );
  }

  Future<void> _retryPendingUploads() async {
    final requestId = _pendingRequestId?.trim() ?? '';
    if (requestId.isEmpty || _failedUploadDocTypes.isEmpty) return;
    setState(() {
      _submitting = true;
      _submitRuntimeError = null;
      _uploadDone = 0;
      _uploadTotal = 0;
    });
    await _runUpload(
      upload: () => sl<CarsRepository>().retryPendingUploads(
        requestId: requestId,
        items: sl<CarsRepository>().fileUploadEntriesFromForm(
          _buildForm(),
          onlyDocTypes: _failedUploadDocTypes.toSet(),
        ),
        onUploadProgress: _onUploadProgress,
      ),
      onSuccess: _onUploadBatchSuccess,
    );
  }

  void _onUploadProgress(int done, int total) {
    if (!mounted) return;
    setState(() {
      _uploadDone = done;
      _uploadTotal = total;
    });
  }

  Future<void> _onUploadBatchSuccess() async {
    final strings = sl<JsonStringsService>();
    final prefs = sl<SharedPreferences>();
    await prefs.setString(
      SessionPreferencesKeys.authLastEmail,
      _companyEmailController.text.trim(),
    );
    await sl<RequestDraftCubit>().delete(_draftId);
    if (!mounted) return;
    setState(() {
      _submitRuntimeError = null;
      _pendingRequestId = null;
      _failedUploadDocTypes = const [];
    });
    sl<AppFeedbackService>().show(
      strings.text('requestCreateSuccess'),
      kind: AppFeedbackKind.success,
    );
    Navigator.of(context).pop();
  }

  Future<void> _runUpload({
    required Future<Either<Failure, RequestFilesBatchUploadResult>>
        Function() upload,
    required Future<void> Function() onSuccess,
  }) async {
    final strings = sl<JsonStringsService>();
    final result = await upload();
    if (!mounted) return;
    await result.fold<Future<void>>(
      (Failure f) async {
        if (isSessionAuthErrorMessage(f.message)) {
          await _handleSessionLost(strings);
          return;
        }
        final msg = _userFriendlySubmitError(f, strings);
        final isSizeLimit =
            resolveRequestFileSizeLimitMessage(f.message.trim(), strings) != null;
        if (mounted) {
          setState(() => _submitRuntimeError = msg);
        }
        sl<AppFeedbackService>().show(
          msg,
          kind: isSizeLimit ? AppFeedbackKind.warning : AppFeedbackKind.error,
        );
      },
      (RequestFilesBatchUploadResult batch) async {
        if (!batch.allSucceeded) {
          if (mounted) {
            setState(() {
              _pendingRequestId = batch.item.id;
              _failedUploadDocTypes = List<String>.from(batch.failedDocTypes);
              _submitRuntimeError = strings.text('requestCreatePartialUpload');
            });
          }
          sl<AppFeedbackService>().show(
            strings.text('requestCreatePartialUpload'),
            kind: AppFeedbackKind.warning,
          );
          return;
        }
        await onSuccess();
      },
    );
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _submitRequest() async {
    final strings = sl<JsonStringsService>();
    if (!_validateForSubmit()) return;

    _debounce?.cancel();
    setState(() {
      _submitting = true;
      _submitRuntimeError = null;
      _uploadDone = 0;
      _uploadTotal = 0;
      if (_pendingRequestId == null) {
        _failedUploadDocTypes = const [];
      }
    });

    if (_pendingRequestId != null &&
        _pendingRequestId!.isNotEmpty &&
        _failedUploadDocTypes.isNotEmpty) {
      await _retryPendingUploads();
      return;
    }

    final Either<Failure, CreateVehicleResult> result =
        await sl<CarsRepository>().createVehicle(
      _buildForm(),
      onUploadProgress: _onUploadProgress,
    );
    if (!mounted) return;
    await result.fold<Future<void>>(
      (Failure f) async {
        if (isSessionAuthErrorMessage(f.message)) {
          await _handleSessionLost(strings);
          if (mounted) setState(() => _submitting = false);
          return;
        }
        final msg = _userFriendlySubmitError(f, strings);
        if (mounted) {
          setState(() => _submitRuntimeError = msg);
        }
        sl<AppFeedbackService>().show(msg, kind: AppFeedbackKind.error);
        if (mounted) setState(() => _submitting = false);
      },
      (CreateVehicleResult created) async {
        if (!created.allFilesUploaded) {
          if (mounted) {
            setState(() {
              _pendingRequestId = created.item.id;
              _failedUploadDocTypes = List<String>.from(created.failedDocTypes);
              _submitRuntimeError = strings.text('requestCreatePartialUpload');
            });
          }
          sl<AppFeedbackService>().show(
            strings.text('requestCreatePartialUpload'),
            kind: AppFeedbackKind.warning,
          );
          if (mounted) setState(() => _submitting = false);
          return;
        }
        await _onUploadBatchSuccess();
        if (mounted) setState(() => _submitting = false);
      },
    );
  }

  String _userFriendlySubmitError(Failure f, JsonStringsService s) {
    final raw = f.message.trim();
    if (isSessionAuthErrorMessage(raw)) {
      return sessionAuthErrorMessage(s);
    }
    final sizeMsg = resolveRequestFileSizeLimitMessage(raw, s);
    if (sizeMsg != null) return sizeMsg;
    final low = raw.toLowerCase();
    if (low.contains('payload too large') ||
        low.contains('body too large') ||
        low.contains('fst_err_ctp_body_too_large') ||
        low.contains('request body is too large')) {
      return 'Слишком большой размер файлов. Сожмите фото и повторите отправку.';
    }
    if (f is ServerFailure && raw.isNotEmpty) {
      return raw;
    }
    return s.text('requestCreateSubmitError');
  }

  Future<void> _handleSessionLost(JsonStringsService strings) async {
    _debounce?.cancel();
    await _writeDraft();
    final msg = sessionAuthErrorMessage(strings);
    if (mounted) {
      setState(() => _submitRuntimeError = msg);
    }
    sl<AppFeedbackService>().show(msg, kind: AppFeedbackKind.warning);
    await sl<AuthService>().clearLocalSession();
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _saveDraftExplicit() async {
    _debounce?.cancel();
    _explicitDraftSaved = true;
    await _writeDraft();
    if (!mounted) return;
    sl<AppFeedbackService>().show(
      sl<JsonStringsService>().text('requestDraftSaved'),
      kind: AppFeedbackKind.success,
      clearSnackBars: false,
    );
  }

  void _clampInnToOrgType() =>
      clampInnController(_companyInnController, _organizationType);

  /// Черновик: физлицо / авто / файлы — из draft; юрлицо всегда из профиля.
  void _applyDraft(RequestFormModel f) {
    _personNameController.text = f.personFullName;
    _personPhoneController.text = PhoneRuInputFormatter.formatDisplay(f.personPhone);
    _personSnilsController.text = SnilsInputFormatter.formatDigits(f.personSnils);
    _brandController.text = f.carBrand;
    _modelController.text = f.carModel;
    _vinController.text = f.vin;
    _commentController.text = f.comment;
    _hasSunroof = f.hasSunroof;
    _hasAllWheelDrive = f.hasAllWheelDrive;
    _wasInRussiaLast12Months = f.wasInRussiaLast12Months;
    _hasOtherCars = f.hasOtherCars;
    _files = RequestFilesPayload(
      passportFrontPaths: f.passportFrontPaths,
      passportAddressPaths: f.passportAddressPaths,
      innPaths: f.innPaths,
      snilsPaths: f.snilsPaths,
      invoicePaths: f.invoicePaths,
      contractPaths: f.contractPaths,
      paymentReceiptPaths: f.paymentReceiptPaths,
      vinPlatePhotoPaths: f.vinPlatePhotoPaths,
      odometerPhotoPaths: f.odometerPhotoPaths,
      carFrontPhotoPaths: f.carFrontPhotoPaths,
      carRearPhotoPaths: f.carRearPhotoPaths,
      additionalFile1Paths: f.additionalFile1Paths,
      additionalFile2Paths: f.additionalFile2Paths,
    );
    _prefillOrgFromProfile(sl<AuthSessionController>());
    setState(() {});
  }

  /// Только поля организации из сессии (read-only в UI). Физлицо «на кого» не трогаем.
  void _prefillOrgFromProfile(AuthSessionController session) {
    final isDemo = session.isDemo;
    final companyName =
        isDemo ? DemoProfileSnapshot.companyName : (session.companyName ?? '');
    final inn = isDemo ? DemoProfileSnapshot.inn : (session.inn ?? '');
    final parsed = OrganizationTypeInn.tryParse(session.orgType);
    if (parsed != null) {
      _organizationType = parsed;
    } else if (inn.trim().length == 12) {
      _organizationType = OrganizationType.ip;
    } else if (inn.trim().length == 10) {
      _organizationType = OrganizationType.ooo;
    }
    final email = isDemo ? DemoProfileSnapshot.email : (session.email ?? '');
    final phone =
        isDemo ? DemoProfileSnapshot.phoneDisplay : (session.phone ?? '');

    _companyNameController.text = companyName.trim();
    _companyInnController.text = InnInputFormatter.formatDigits(
      inn,
      maxDigits: _organizationType.innMaxDigits,
    );
    _companyEmailController.text = email.trim();
    _companyPhoneController.text = PhoneRuInputFormatter.formatDisplay(phone);
    _clampInnToOrgType();
  }

  @override
  void initState() {
    super.initState();
    _draftId = widget.draftId ?? 'request_draft_${DateTime.now().millisecondsSinceEpoch}';
    _companyNameController.addListener(_onAnyFieldChanged);
    _companyInnController.addListener(_onAnyFieldChanged);
    _companyEmailController.addListener(_onAnyFieldChanged);
    _companyPhoneController.addListener(_onAnyFieldChanged);
    _personNameController.addListener(_onAnyFieldChanged);
    _personPhoneController.addListener(_onAnyFieldChanged);
    _personSnilsController.addListener(_onAnyFieldChanged);
    _brandController.addListener(_onAnyFieldChanged);
    _modelController.addListener(_onAnyFieldChanged);
    _vinController.addListener(_onAnyFieldChanged);
    _commentController.addListener(_onAnyFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(RequestDraftAttachmentsSpace.ensureDraftDirectory(_draftId));
      if (widget.draftId != null) {
        final d = sl<RequestDraftCubit>().draftById(widget.draftId!);
        if (d != null) {
          _applyDraft(d.form);
        } else {
          _prefillOrgFromProfile(sl<AuthSessionController>());
        }
      } else {
        _prefillOrgFromProfile(sl<AuthSessionController>());
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _companyNameController.removeListener(_onAnyFieldChanged);
    _companyInnController.removeListener(_onAnyFieldChanged);
    _companyEmailController.removeListener(_onAnyFieldChanged);
    _companyPhoneController.removeListener(_onAnyFieldChanged);
    _personNameController.removeListener(_onAnyFieldChanged);
    _personPhoneController.removeListener(_onAnyFieldChanged);
    _personSnilsController.removeListener(_onAnyFieldChanged);
    _brandController.removeListener(_onAnyFieldChanged);
    _modelController.removeListener(_onAnyFieldChanged);
    _vinController.removeListener(_onAnyFieldChanged);
    _commentController.removeListener(_onAnyFieldChanged);
    if (!_explicitDraftSaved && RequestFormModel.countFilledFields(_buildForm()) == 0) {
      unawaited(sl<RequestDraftCubit>().delete(_draftId));
    }
    _companyNameController.dispose();
    _companyInnController.dispose();
    _companyEmailController.dispose();
    _companyPhoneController.dispose();
    _personNameController.dispose();
    _personPhoneController.dispose();
    _personSnilsController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _vinController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = sl<JsonStringsService>();
    final isWide = MediaQuery.of(context).size.width >= 1000;
    return Scaffold(
      appBar: BrandPrimaryAppBar(title: s.text('requestCreateTitle')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RequestLabeledInputField(
                label: _organizationType == OrganizationType.person
                    ? s.text('requestPersonApplicantNameLabel')
                    : s.text('requestCompanyNameLabel'),
                hintText: _organizationType == OrganizationType.person
                    ? s.text('requestPersonApplicantNameHint')
                    : s.text('requestCompanyNameHint'),
                controller: _companyNameController,
                textCapitalization: TextCapitalization.words,
                readOnly: true,
              ),
              const SizedBox(height: 14),
              AppInnField(
                label: s.innLabel,
                controller: _companyInnController,
                organizationType: _organizationType,
                validate: false,
                readOnly: true,
              ),
              const SizedBox(height: 14),
              RequestLabeledInputField(
                label: s.text('requestCompanyEmailLabel'),
                hintText: s.emailLabel,
                controller: _companyEmailController,
                keyboardType: TextInputType.emailAddress,
                readOnly: true,
              ),
              const SizedBox(height: 14),
              AppPhoneRuField(
                label: s.text('requestCompanyPhoneLabel'),
                controller: _companyPhoneController,
                validate: false,
                readOnly: true,
              ),
              const SizedBox(height: 14),
              RequestLabeledInputField(
                label: s.text('requestPersonNameLabel'),
                hintText: s.text('requestPersonNameHint'),
                controller: _personNameController,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              AppPhoneRuField(
                label: s.text('requestPersonPhoneLabel'),
                controller: _personPhoneController,
                validate: false,
              ),
              const SizedBox(height: 14),
              AppSnilsField(
                label: s.text('requestSnilsLabel'),
                controller: _personSnilsController,
                validate: false,
              ),
              const SizedBox(height: 14),
              RequestLabeledInputField(
                label: s.text('requestCarBrandLabel'),
                hintText: s.text('requestCarBrandHint'),
                controller: _brandController,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              RequestLabeledInputField(
                label: s.text('requestCarModelLabel'),
                hintText: s.text('requestCarModelHint'),
                controller: _modelController,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              RequestLabeledInputField(
                label: s.text('requestVinLabel'),
                hintText: s.text('requestVinHint'),
                controller: _vinController,
                inputFormatters: [VinInputFormatter()],
              ),
              const SizedBox(height: 14),
              _yesNoField(
                label: s.text('requestSunroofLabel'),
                markRequired: true,
                value: _hasSunroof,
                onChanged: (v) {
                  setState(() => _hasSunroof = v);
                  _scheduleSave();
                },
              ),
              const SizedBox(height: 14),
              _yesNoField(
                label: s.text('requestAllWheelDriveLabel'),
                markRequired: true,
                value: _hasAllWheelDrive,
                onChanged: (v) {
                  setState(() => _hasAllWheelDrive = v);
                  _scheduleSave();
                },
              ),
              const SizedBox(height: 14),
              _yesNoField(
                label: s.text('requestImported12MonthsLabel'),
                markRequired: true,
                value: _wasInRussiaLast12Months,
                onChanged: (v) {
                  setState(() => _wasInRussiaLast12Months = v);
                  _scheduleSave();
                },
              ),
              const SizedBox(height: 14),
              _yesNoField(
                label: s.text('requestHasOtherCarsLabel'),
                markRequired: true,
                value: _hasOtherCars,
                onChanged: (v) {
                  setState(() => _hasOtherCars = v);
                  _scheduleSave();
                },
              ),
              const SizedBox(height: 14),
              RequestLabeledInputField(
                label: s.text('requestCommentLabel'),
                hintText: s.text('requestCommentHint'),
                controller: _commentController,
                markRequired: false,
                minLines: 3,
                maxLines: 5,
              ),
              const SizedBox(height: 18),
              if (!isWide) ..._buildFilesAndActions(s) else _buildWideFilesPanel(s),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFilesAndActions(JsonStringsService s) {
    return [
      OutlinedButton.icon(
        onPressed: _openFilesPage,
        icon: Icon(
          Icons.check_circle,
          color: _files.allRequiredReady ? Colors.green : Colors.grey,
        ),
        label: Text(s.text('requestFilesOpenButton')),
      ),
      const SizedBox(height: 6),
      AppPrimaryFilledWideButton(
        label: _failedUploadDocTypes.isNotEmpty
            ? s.text('requestCreateRetryUpload')
            : s.text('requestSubmitButton'),
        onPressed: (_submitting || !_isSubmitEnabled) ? null : _submitRequest,
        isLoading: _submitting,
        height: 56,
      ),
      if (_submitting && _uploadTotal > 0) ...[
        const SizedBox(height: 8),
        Text(
          _uploadDone >= _uploadTotal
              ? 'Создаем заявку...'
              : s
                  .text('requestCreateUploadProgress')
                  .replaceAll('{done}', '$_uploadDone')
                  .replaceAll('{total}', '$_uploadTotal'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF4A4A4A),
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
      if (_submitRuntimeError != null && _submitRuntimeError!.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          _submitRuntimeError!,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
      if (!_submitting && !_isSubmitEnabled && _submitBlockReason != null) ...[
        const SizedBox(height: 8),
        Text(
          _submitBlockReason!,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
      const SizedBox(height: 12),
      AppPrimaryOutlinedWideButton(
        label: s.text('requestSaveDraftButton'),
        onPressed: _saveDraftExplicit,
        height: 56,
      ),
      const SizedBox(height: 12),
      AppLogoutOutlinedWideButton(
        label: s.actionCancel,
        onPressed: () => Navigator.of(context).pop(),
        height: 56,
      ),
    ];
  }

  Widget _buildWideFilesPanel(JsonStringsService s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildFilesAndActions(s),
      ),
    );
  }

  Future<void> _openFilesPage() async {
    final result = await Navigator.of(context).push<RequestFilesPayload>(
      MaterialPageRoute<RequestFilesPayload>(
        builder: (_) => RequestFilesUploadPage(
          draftId: _draftId,
          initial: _files,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _files = result);
    _scheduleSave();
  }

  Widget _yesNoField({
    required String label,
    bool markRequired = true,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final s = sl<JsonStringsService>();
    final baseStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: const Color(0xFF7C7C7C),
          fontWeight: FontWeight.w500,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: baseStyle,
            children: [
              TextSpan(text: label),
              if (markRequired)
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: <ButtonSegment<bool>>[
            ButtonSegment<bool>(value: true, label: Text(s.text('answerYes'))),
            ButtonSegment<bool>(value: false, label: Text(s.text('answerNo'))),
          ],
          selected: <bool>{value},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ],
    );
  }
}
