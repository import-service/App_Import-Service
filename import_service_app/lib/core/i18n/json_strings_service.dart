import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';

/// Загрузка строк из `assets/i18n/<lang>.json`.
///
/// Поддерживаются только языки, для которых есть JSON-файлы.
final class JsonStringsService {
  Map<String, dynamic> _data = const <String, dynamic>{};

  Future<void> load(Locale locale) async {
    final lang = _resolveLanguageCode(locale);
    final raw = await rootBundle.loadString('assets/i18n/$lang.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid i18n JSON root (expected object).');
    }
    _data = decoded;
  }

  String text(String key) {
    final value = _data[key];
    if (value is! String) {
      throw StateError('Missing i18n key "$key"');
    }
    return value;
  }

  String get appTitle => text('appTitle');
  String get authTitle => text('authTitle');
  String get loginLabel => text('loginLabel');
  String get passwordLabel => text('passwordLabel');
  String get loginButton => text('loginButton');
  String get demoLoginButton => text('demoLoginButton');
  String get notClientYet => text('notClientYet');
  String get submitRequestButton => text('submitRequestButton');

  String get settingsTitle => text('settingsTitle');
  String get languagePickerTitle => text('languagePickerTitle');
  String get languageRussian => text('languageRussian');
  String get languageChinese => text('languageChinese');

  String get requestSheetTitle => text('requestSheetTitle');
  String get requestSheetSubtitle => text('requestSheetSubtitle');
  String get orgTypeOoo => text('orgTypeOoo');
  String get orgTypeIp => text('orgTypeIp');
  String get companyNameLabel => text('companyNameLabel');
  String get fullNameLabel => text('fullNameLabel');
  String get innLabel => text('innLabel');
  String get phoneLabel => text('phoneLabel');
  String get emailLabel => text('emailLabel');

  String get fieldRequiredError => text('fieldRequiredError');
  String get innFormatError => text('innFormatError');
  String get phoneFormatError => text('phoneFormatError');
  String get emailFormatError => text('emailFormatError');
  String get requestUnknownError => text('requestUnknownError');
  String get loginUnknownError => text('loginUnknownError');
  String get logoutUnknownError => text('logoutUnknownError');
  String get logoutButton => text('logoutButton');
  String get logoutConfirmTitle => text('logoutConfirmTitle');
  String get logoutConfirmMessage => text('logoutConfirmMessage');
  String get actionCancel => text('actionCancel');
  String get actionConfirmLogout => text('actionConfirmLogout');
  String get profileLoginLabel => text('profileLoginLabel');
  String get profileRoleLabel => text('profileRoleLabel');
  String get profileUnknownError => text('profileUnknownError');
  String get profileTabTitle => text('profileTabTitle');
  String get carsTabTitle => text('carsTabTitle');
  String get profileManagerLabel => text('profileManagerLabel');
  String get profilePhoneLabel => text('profilePhoneLabel');
  String get profileEmailLabel => text('profileEmailLabel');
  String get profileCompanyLabel => text('profileCompanyLabel');
  String get profileInnLabel => text('profileInnLabel');
  String get profileNoDataText => text('profileNoDataText');
  String get carsNoDataText => text('carsNoDataText');
  String get carsSearchHint => text('carsSearchHint');
  String get carsSearchClearA11y => text('carsSearchClearA11y');
  String get carStatusInWork => text('carStatusInWork');
  String get carStatusOnWay => text('carStatusOnWay');
  String get carStatusDelivered => text('carStatusDelivered');
  String get carStatusNew => text('carStatusNew');
  String get requestDetailNotFound => text('requestDetailNotFound');
  String get requestDetailStatusLabel => text('requestDetailStatusLabel');
  String get requestDocumentPack => text('requestDocumentPack');
  String get requestDocumentPackInfo => text('requestDocumentPackInfo');
  String get requestDocumentUpload => text('requestDocumentUpload');
  String get requestTestModeLabel => text('requestTestModeLabel');
  String get requestDetailOwner => text('requestDetailOwner');
  String get requestDetailVehicle => text('requestDetailVehicle');
  String get requestDetailEngine => text('requestDetailEngine');
  String get requestDetailVin => text('requestDetailVin');
  String get requestDetailFinances => text('requestDetailFinances');
  String get requestDetailPhoto => text('requestDetailPhoto');
  String get requestDetailServerFiles => text('requestDetailServerFiles');
  String get requestDetailUploadReceipt => text('requestDetailUploadReceipt');
  String get requestDetailOpenReceipt => text('requestDetailOpenReceipt');
  String get requestDetailReceiptCaption => text('requestDetailReceiptCaption');
  String get requestDetailTransitSubStatusLoading => text('requestDetailTransitSubStatusLoading');
  String get requestDetailDeliveredSubStatusSw => text('requestDetailDeliveredSubStatusSw');
  String get requestDetailFinanceDuty => text('requestDetailFinanceDuty');
  String get requestDetailFinanceRecycling => text('requestDetailFinanceRecycling');
  String get requestDetailPhotoPlaceholderA11y => text('requestDetailPhotoPlaceholderA11y');
  String get requestDetailChatA11y => text('requestDetailChatA11y');
  String get demoActionUnavailable => text('demoActionUnavailable');

  String requestDetailStatusSince(String date) =>
      text('requestDetailStatusSince').replaceAll('{date}', date);

  String get requestCardGoToChat => text('requestCardGoToChat');
  String get chatPageTitle => text('chatPageTitle');
  String get chatInputPlaceholder => text('chatInputPlaceholder');
  String get chatDemoAutoReply => text('chatDemoAutoReply');
  String get chatUnavailable => text('chatUnavailable');
  String get chatEmptyHint => text('chatEmptyHint');
  String get chatInDevelopment => text('chatInDevelopment');
  String get appFeatureInDevelopment => text('appFeatureInDevelopment');
  String requestDraftsFab(int count) =>
      text('requestDraftsFab').replaceAll('{count}', count.toString());
  String get requestDraftsSheetTitle => text('requestDraftsSheetTitle');
  String get requestDraftsFieldsProgress => text('requestDraftsFieldsProgress');
  String get requestDraftsDeleteTitle => text('requestDraftsDeleteTitle');
  String get requestDraftsDeleteMessage => text('requestDraftsDeleteMessage');
  String get requestDraftsDeleteConfirm => text('requestDraftsDeleteConfirm');
  String get carsFilterTooltip => text('carsFilterTooltip');
  String get carsAddButtonTooltip => text('carsAddButtonTooltip');
  String get demoClientName => text('demoClientName');
  String get noDataTitle => text('noDataTitle');

  /// [statusSubType] с 1С (см. [CarListItem.statusSubType]).
  String requestDetailStatusSubTypeLabel(String code) {
    switch (code) {
      case 'in_transit_loading':
        return requestDetailTransitSubStatusLoading;
      case 'delivered_temporary_storage':
        return requestDetailDeliveredSubStatusSw;
      default:
        return code;
    }
  }

  String _resolveLanguageCode(Locale locale) {
    switch (locale.languageCode) {
      case 'zh':
        return 'zh';
      case 'ru':
      default:
        return 'ru';
    }
  }
}
