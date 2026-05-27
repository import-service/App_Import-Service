import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/core/ui/app_snackbars.dart';
import 'package:import_service_admin/core/ui/ascii_text_input_formatter.dart';
import 'package:import_service_admin/core/ui/server_error_ui.dart';
import 'package:import_service_admin/domain/repositories/admin_settings_repository.dart';

class SettingsOneCPage extends StatefulWidget {
  const SettingsOneCPage({super.key});

  @override
  State<SettingsOneCPage> createState() => _SettingsOneCPageState();
}

class _SettingsOneCPageState extends State<SettingsOneCPage> {
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _obscureToken = true;
  String? _maskedToken;
  bool _hasToken = false;
  String? _updatedAt;
  String? _saveSuccessMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settings =
          await sl<AdminSettingsRepository>().getOneCRequestCreate();
      if (!mounted) return;
      setState(() {
        _urlController.text = settings.oneCRequestCreateUrl ?? '';
        _maskedToken = settings.oneCRequestCreateBearerTokenMasked;
        _hasToken = settings.hasBearerToken;
        _updatedAt = settings.updatedAt;
        _loading = false;
      });
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (shouldHideErrorForAuth(e)) return;
      _showError(e is ServerException ? e.message : '$e');
    }
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    final token = _tokenController.text.trim();
    if (url.isEmpty || token.isEmpty) {
      if (_hasToken && token.isEmpty) {
        _showError('Введите новый Bearer-токен для замены сохранённого');
      } else {
        _showError('Укажите URL и Bearer-токен');
      }
      return;
    }
    if (!AsciiTextInputFormatter.isValidAscii(token)) {
      _showError('Токен: только латиница, цифры и ASCII-символы');
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      _showError('URL должен начинаться с http:// или https://');
      return;
    }

    setState(() {
      _saving = true;
      _saveSuccessMessage = null;
    });
    try {
      final updated = await sl<AdminSettingsRepository>().updateOneCRequestCreate(
        url: url,
        bearerToken: token,
      );
      if (!mounted) return;
      final at = updated.updatedAt;
      setState(() {
        _maskedToken = updated.oneCRequestCreateBearerTokenMasked;
        _hasToken = updated.hasBearerToken;
        _updatedAt = at;
        _tokenController.clear();
        _obscureToken = true;
        _saveSuccessMessage =
            'Настройки сохранены на сервере${at != null ? ' · $at' : ''}. '
            'Токен на сервере: ${_maskedToken ?? '••••'} — полный текст не показывается.';
      });
      AppSnackBars.showSuccess(
        'Настройки 1С сохранены на сервере',
        context: context,
      );
    } on UnauthorizedException {
      return;
    } on ServerException catch (e) {
      _showError(e.message);
    } catch (e) {
      if (shouldHideErrorForAuth(e)) return;
      _showError('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    AppSnackBars.showError(message, context: context);
  }

  void _clearSaveBanner() {
    if (_saveSuccessMessage != null) {
      setState(() => _saveSuccessMessage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Исходящая передача заявки в 1С',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(8),
            Text(
              'Используется при создании заявки и кнопке «Отправить в 1С» для статуса new.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(24),
            TextField(
              controller: _urlController,
              onChanged: (_) => _clearSaveBanner(),
              decoration: const InputDecoration(
                labelText: 'URL создания заявки в 1С',
                hintText: 'https://1c.example/hs/import/customs-request',
              ),
              keyboardType: TextInputType.url,
            ),
            const Gap(16),
            if (_hasToken) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      'На сервере сохранён токен: ${_maskedToken ?? '••••'}. '
                      'Полный текст не отдаётся API — введите новый ниже, чтобы заменить.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(8),
            ],
            TextField(
              controller: _tokenController,
              onChanged: (_) => _clearSaveBanner(),
              decoration: InputDecoration(
                labelText: 'Bearer-токен',
                hintText: _hasToken
                    ? 'Новый токен (латиница, цифры, ASCII)'
                    : 'Введите токен (латиница, цифры, ASCII)',
                helperText:
                    'Кириллица в токене недопустима — запрос в 1С не отправится.',
                suffixIcon: IconButton(
                  tooltip: _obscureToken ? 'Показать' : 'Скрыть',
                  onPressed: () =>
                      setState(() => _obscureToken = !_obscureToken),
                  icon: Icon(
                    _obscureToken
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              obscureText: _obscureToken,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              inputFormatters: const [AsciiTextInputFormatter()],
            ),
            if (_updatedAt != null) ...[
              const Gap(8),
              Text(
                'Обновлено: $_updatedAt',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (_saveSuccessMessage != null) ...[
              const Gap(16),
              Material(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF2E7D32),
                        size: 22,
                      ),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          _saveSuccessMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const Gap(24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppTheme.primaryBlue,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}
