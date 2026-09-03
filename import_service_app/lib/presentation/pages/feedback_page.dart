import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/error/exceptions.dart';
import 'package:import_service_app/core/ui/app_feedback_kind.dart';
import 'package:import_service_app/core/ui/app_feedback_service.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/data/datasources/remote/feedback_remote_data_source.dart';
import 'package:import_service_app/presentation/widgets/app_bar/brand_primary_app_bar.dart';
import 'package:package_info_plus/package_info_plus.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  static const int _minLen = 15;
  static const int _maxLen = 4000;

  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (_) {}
    return defaultTargetPlatform.name;
  }

  Future<void> _submit() async {
    final s = sl<JsonStringsService>();
    final text = _controller.text.trim();
    if (text.length < _minLen) {
      sl<AppFeedbackService>().show(
        s.text('feedbackTooShort'),
        kind: AppFeedbackKind.error,
      );
      return;
    }
    if (text.length > _maxLen) {
      sl<AppFeedbackService>().show(
        s.text('feedbackTooLong'),
        kind: AppFeedbackKind.error,
      );
      return;
    }

    setState(() => _sending = true);
    try {
      String? appVersion;
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {}

      await sl<FeedbackRemoteDataSource>().submitFeedback(
        message: text,
        appVersion: appVersion,
        platform: _platformLabel(),
      );
      if (!mounted) return;
      sl<AppFeedbackService>().show(
        s.text('feedbackSuccess'),
        kind: AppFeedbackKind.success,
      );
      Navigator.of(context).pop();
    } on ServerException catch (e) {
      if (!mounted) return;
      sl<AppFeedbackService>().show(
        e.message.isNotEmpty ? e.message : s.text('feedbackError'),
        kind: AppFeedbackKind.error,
      );
    } catch (_) {
      if (!mounted) return;
      sl<AppFeedbackService>().show(
        s.text('feedbackError'),
        kind: AppFeedbackKind.error,
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = sl<JsonStringsService>();
    return Scaffold(
      appBar: BrandPrimaryAppBar(title: s.text('feedbackPageTitle')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.text('feedbackIntro'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_sending,
                  maxLines: null,
                  expands: true,
                  maxLength: _maxLen,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: s.text('feedbackMessageHint'),
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _sending || _controller.text.trim().length < _minLen
                      ? null
                      : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: AppTheme.white,
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(s.text('feedbackSend')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
