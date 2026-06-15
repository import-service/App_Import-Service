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
  final _createUrlController = TextEditingController();
  final _updateUrlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _obscureToken = true;
  String? _maskedToken;
  bool _hasToken = false;
  String? _updatedAt;
  String? _effectiveUpdateUrl;
  String? _saveSuccessMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _createUrlController.dispose();
    _updateUrlController.dispose();
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
        _createUrlController.text = settings.oneCRequestCreateUrl ?? '';
        _updateUrlController.text = settings.oneCRequestUpdateUrl ?? '';
        _effectiveUpdateUrl = settings.oneCRequestUpdateUrlEffective;
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
    final createUrl = _createUrlController.text.trim();
    final updateUrl = _updateUrlController.text.trim();
    final token = _tokenController.text.trim();
    if (createUrl.isEmpty || token.isEmpty) {
      if (_hasToken && token.isEmpty) {
        _showError('Введите новый Bearer-токен для замены сохранённого');
      } else {
        _showError('Укажите URL создания и Bearer-токен');
      }
      return;
    }
    if (!AsciiTextInputFormatter.isValidAscii(token)) {
      _showError('Токен: только латиница, цифры и ASCII-символы');
      return;
    }
    if (!_isHttpUrl(createUrl)) {
      _showError('URL создания должен начинаться с http:// или https://');
      return;
    }
    if (updateUrl.isNotEmpty && !_isHttpUrl(updateUrl)) {
      _showError('URL обновления файлов должен начинаться с http:// или https://');
      return;
    }

    setState(() {
      _saving = true;
      _saveSuccessMessage = null;
    });
    try {
      final updated = await sl<AdminSettingsRepository>().updateOneCRequestCreate(
        url: createUrl,
        bearerToken: token,
        updateUrl: updateUrl,
      );
      if (!mounted) return;
      final at = updated.updatedAt;
      setState(() {
        _maskedToken = updated.oneCRequestCreateBearerTokenMasked;
        _hasToken = updated.hasBearerToken;
        _updatedAt = at;
        _effectiveUpdateUrl = updated.oneCRequestUpdateUrlEffective;
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

  bool _isHttpUrl(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

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
              'Исходящие вызовы в 1С',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(8),
            Text(
              'Два отдельных HTTP-роута на стороне 1С: создание заявки и обновление файлов из МП.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(24),
            Text(
              'Создание заявки',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(8),
            Text(
              'После upload из МП и кнопки «Отправить в 1С» для статуса new.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(12),
            TextField(
              controller: _createUrlController,
              onChanged: (_) => _clearSaveBanner(),
              decoration: const InputDecoration(
                labelText: 'URL создания заявки в 1С',
                hintText: 'https://1c.example/hs/MobileAppIntegration/customs-requests',
              ),
              keyboardType: TextInputType.url,
            ),
            const Gap(24),
            Text(
              'Обновление файлов',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(8),
            Text(
              'Подписи, чеки и прочие файлы из МП. Отдельный роут в 1С — не смешивать с созданием.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(12),
            TextField(
              controller: _updateUrlController,
              onChanged: (_) => _clearSaveBanner(),
              decoration: const InputDecoration(
                labelText: 'URL обновления файлов в 1С',
                hintText: 'https://1c.example/hs/MobileAppIntegration/customs-requests/files',
                helperText:
                    'Если пусто — сервер добавит /files к URL создания.',
              ),
              keyboardType: TextInputType.url,
            ),
            if (_effectiveUpdateUrl != null &&
                _updateUrlController.text.trim().isEmpty) ...[
              const Gap(8),
              Text(
                'Сейчас будет использоваться: $_effectiveUpdateUrl',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            const Gap(24),
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
                labelText: 'Bearer-токен (для обоих URL)',
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
