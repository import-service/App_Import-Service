import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/core/ui/app_snackbars.dart';
import 'package:import_service_admin/core/ui/server_error_ui.dart';
import 'package:import_service_admin/domain/entities/svh_manager.dart';
import 'package:import_service_admin/domain/repositories/svh_managers_repository.dart';
import 'package:import_service_admin/presentation/helpers/svh_credentials_clipboard.dart';
import 'package:import_service_admin/presentation/widgets/forms/fields/admin_phone_ru_field.dart';
import 'package:import_service_admin/presentation/widgets/forms/input_formatters/phone_ru_input_formatter.dart';
import 'package:import_service_admin/presentation/widgets/forms/required_field_label.dart';

class SvhManagerDetailPage extends StatefulWidget {
  const SvhManagerDetailPage({super.key, required this.managerId});

  final int managerId;

  @override
  State<SvhManagerDetailPage> createState() => _SvhManagerDetailPageState();
}

class _SvhManagerDetailPageState extends State<SvhManagerDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  late Future<SvhManager> _future;
  SvhManager? _manager;
  bool _saving = false;

  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<SvhManager> _load() async {
    final item = await sl<SvhManagersRepository>().getById(widget.managerId);
    _manager = item;
    _loginController.text = item.login;
    _nameController.text = item.fullName;
    final phone = item.phone.trim();
    _phoneController.text = phone.isEmpty || phone == '-'
        ? '+7'
        : PhoneRuInputFormatter.formatDisplay(phone);
    return item;
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  bool _isValidEmail(String value) {
    final v = value.trim();
    if (v.contains('..')) return false;
    return _emailPattern.hasMatch(v);
  }

  Future<void> _copyCredentials() async {
    final login = _loginController.text.trim();
    final password = _passwordController.text;
    if (!_isValidEmail(login)) {
      AppSnackBars.showError('Укажите корректный email-логин');
      return;
    }
    if (password.length < 6) {
      AppSnackBars.showError(
        'Для копирования введите пароль (минимум 6 символов) в поле ниже',
      );
      return;
    }
    await copySvhLoginCredentials(login: login, password: password);
    if (!mounted) return;
    AppSnackBars.showSuccess(
      'Данные скопированы — можно вставить в мессенджер',
    );
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final manager = _manager;
    if (manager == null) return;

    final login = _loginController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final fullName = _nameController.text.trim();
    final phoneApi =
        PhoneRuInputFormatter.normalizeOptionalForApi(_phoneController.text);

    setState(() => _saving = true);
    try {
      final result = await sl<SvhManagersRepository>().update(
        id: manager.id,
        login: login != manager.login ? login : null,
        password: password.isNotEmpty ? password : null,
        fullName: fullName,
        phone: phoneApi ?? '-',
      );

      final credentialsTouched =
          login != manager.login || password.isNotEmpty;
      if (credentialsTouched && password.isNotEmpty) {
        await copySvhLoginCredentials(login: login, password: password);
      }

      if (!mounted) return;
      if (credentialsTouched) {
        final mailPart = result.emailSent
            ? 'Письмо отправлено на $login.'
            : 'Письмо отправить не удалось.';
        final copyPart = password.isNotEmpty
            ? ' Данные скопированы — можно вставить в мессенджер.'
            : '';
        AppSnackBars.showSuccess('$mailPart$copyPart');
      } else {
        AppSnackBars.showSuccess('Сохранено');
      }
      _passwordController.clear();
      _reload();
    } on ServerException catch (e) {
      if (!mounted) return;
      AppSnackBars.showError(e.message);
    } catch (_) {
      if (!mounted) return;
      AppSnackBars.showError('Не удалось сохранить');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Менеджер СВХ'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<SvhManager>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _manager == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && _manager == null) {
            final panel = buildRetryErrorPanel(
              error: snapshot.error,
              onRetry: _reload,
            );
            if (panel != null) return panel;
            return const SizedBox.shrink();
          }

          final m = _manager ?? snapshot.data;
          if (m == null) {
            return const Center(child: Text('Не найден'));
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        m.active ? 'Активен' : 'Отключён',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Gap(16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          label: RequiredFieldLabel(text: 'ФИО', required: true),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Введите ФИО';
                          }
                          return null;
                        },
                      ),
                      const Gap(12),
                      TextFormField(
                        controller: _loginController,
                        decoration: const InputDecoration(
                          label: RequiredFieldLabel(
                            text: 'Логин (email)',
                            required: true,
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Введите email';
                          }
                          if (!_isValidEmail(v)) return 'Некорректный email';
                          return null;
                        },
                      ),
                      const Gap(12),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          label: Text('Новый пароль'),
                          helperText:
                              'Оставьте пустым, чтобы не менять. Нужен для копирования в мессенджер.',
                        ),
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          if (v.length < 6) return 'Минимум 6 символов';
                          return null;
                        },
                      ),
                      const Gap(12),
                      AdminPhoneRuField(
                        controller: _phoneController,
                        markRequired: false,
                        textInputAction: TextInputAction.done,
                      ),
                      const Gap(24),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: const Text('Сохранить'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _copyCredentials,
                            icon: const Icon(Icons.copy_outlined),
                            label: const Text('Копировать данные для входа'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
