import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/core/ui/app_snackbars.dart';
import 'package:import_service_admin/core/ui/server_error_ui.dart';
import 'package:import_service_admin/domain/entities/svh_manager.dart';
import 'package:import_service_admin/domain/repositories/svh_managers_repository.dart';
import 'package:import_service_admin/presentation/helpers/svh_credentials_clipboard.dart';
import 'package:import_service_admin/presentation/widgets/forms/fields/admin_phone_ru_field.dart';
import 'package:import_service_admin/presentation/widgets/forms/input_formatters/phone_ru_input_formatter.dart';
import 'package:import_service_admin/presentation/widgets/forms/required_field_label.dart';

class SvhManagersPage extends StatefulWidget {
  const SvhManagersPage({super.key});

  @override
  State<SvhManagersPage> createState() => _SvhManagersPageState();
}

class _SvhManagersPageState extends State<SvhManagersPage> {
  late Future<({List<SvhManager> items, int total})> _future;

  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = sl<SvhManagersRepository>().list(
        limit: 200,
        includeDisabled: true,
      );
    });
  }

  bool _isValidEmail(String value) {
    final v = value.trim();
    if (v.contains('..')) return false;
    return _emailPattern.hasMatch(v);
  }

  Future<void> _showCreateResultDialog({
    required String login,
    required String password,
    required bool emailSent,
  }) async {
    final credentials = formatSvhLoginCredentials(
      login: login,
      password: password,
    );
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Менеджер создан'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  emailSent
                      ? 'Письмо с данными для входа отправлено на:\n$login'
                      : 'Письмо отправить не удалось.\nПроверьте SMTP или спам-папку получателя.',
                  style: TextStyle(
                    color: emailSent
                        ? const Color(0xFF1B5E20)
                        : const Color(0xFFB71C1C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(12),
                const Text(
                  'Данные для входа скопированы в буфер обмена.\n'
                  'Можно вставить в любой мессенджер (Ctrl+V).',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Gap(16),
                SelectableText(
                  credentials,
                  style: const TextStyle(fontFamily: 'monospace', height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () async {
                await copySvhLoginCredentials(
                  login: login,
                  password: password,
                );
                if (context.mounted) {
                  AppSnackBars.showSuccess(
                    'Снова скопировано в буфер',
                    context: context,
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Скопировать ещё раз'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCopyCredentialsDialog(SvhManager manager) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Копировать данные для входа'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Логин: ${manager.login}'),
                const Gap(12),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    label: RequiredFieldLabel(
                      text: 'Пароль',
                      required: true,
                    ),
                    helperText:
                        'В БД хранится хеш — введите пароль, который выдаёте менеджеру',
                  ),
                  obscureText: true,
                  autofocus: true,
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return 'Минимум 6 символов';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(context, true);
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Копировать'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) {
      passwordController.dispose();
      return;
    }

    await copySvhLoginCredentials(
      login: manager.login,
      password: passwordController.text,
    );
    passwordController.dispose();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Скопировано'),
        content: SizedBox(
          width: 440,
          child: Text(
            'Логин и пароль скопированы в буфер.\n'
            'Можно вставить в мессенджер (Ctrl+V).\n\n'
            'Логин: ${manager.login}',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ОК'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateDialog() async {
    final loginController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController(text: '+7');
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый менеджер СВХ'),
        content: SizedBox(
          width: 560,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: loginController,
                    decoration: const InputDecoration(
                      label: RequiredFieldLabel(
                        text: 'Логин (email)',
                        required: true,
                      ),
                      helperText: 'Как в мобильном приложении',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
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
                    controller: passwordController,
                    decoration: const InputDecoration(
                      label: RequiredFieldLabel(text: 'Пароль', required: true),
                    ),
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'Минимум 6 символов';
                      }
                      return null;
                    },
                  ),
                  const Gap(12),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      label: RequiredFieldLabel(text: 'ФИО', required: true),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Введите ФИО';
                      return null;
                    },
                  ),
                  const Gap(12),
                  AdminPhoneRuField(
                    controller: phoneController,
                    markRequired: false,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(context, true);
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );

    if (created != true || !mounted) {
      loginController.dispose();
      passwordController.dispose();
      nameController.dispose();
      phoneController.dispose();
      return;
    }

    final login = loginController.text.trim().toLowerCase();
    final password = passwordController.text;
    final fullName = nameController.text.trim();
    final phoneApi =
        PhoneRuInputFormatter.normalizeOptionalForApi(phoneController.text);

    loginController.dispose();
    passwordController.dispose();
    nameController.dispose();
    phoneController.dispose();

    try {
      final result = await sl<SvhManagersRepository>().create(
        login: login,
        password: password,
        fullName: fullName,
        phone: phoneApi,
      );
      await copySvhLoginCredentials(login: login, password: password);
      if (!mounted) return;
      _reload();
      await _showCreateResultDialog(
        login: login,
        password: password,
        emailSent: result.emailSent,
      );
    } on ServerException catch (e) {
      if (!mounted) return;
      AppSnackBars.showError(e.message);
    } catch (_) {
      if (!mounted) return;
      AppSnackBars.showError('Не удалось создать менеджера');
    }
  }

  Future<void> _setActive(SvhManager manager, bool active) async {
    final title = active ? 'Включить менеджера?' : 'Отключить менеджера?';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          manager.fullName.isNotEmpty
              ? '${manager.fullName}\n${manager.login}'
              : manager.login,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(active ? 'Включить' : 'Отключить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await sl<SvhManagersRepository>().update(
        id: manager.id,
        active: active,
      );
      if (!mounted) return;
      AppSnackBars.showSuccess(
        active ? 'Менеджер включён' : 'Менеджер отключён',
      );
      _reload();
    } on ServerException catch (e) {
      if (!mounted) return;
      AppSnackBars.showError(e.message);
    } catch (_) {
      if (!mounted) return;
      AppSnackBars.showError('Не удалось изменить статус');
    }
  }

  Future<void> _deleteHard(SvhManager manager) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить навсегда?'),
        content: Text(
          'Менеджер будет удалён из базы.\n'
          '${manager.fullName.isNotEmpty ? '${manager.fullName}\n' : ''}'
          '${manager.login}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await sl<SvhManagersRepository>().delete(manager.id);
      if (!mounted) return;
      AppSnackBars.showSuccess('Менеджер удалён');
      _reload();
    } on ServerException catch (e) {
      if (!mounted) return;
      AppSnackBars.showError(e.message);
    } catch (_) {
      if (!mounted) return;
      AppSnackBars.showError('Не удалось удалить');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _openCreateDialog,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Добавить менеджера'),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<({List<SvhManager> items, int total})>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                final panel = buildRetryErrorPanel(
                  error: snapshot.error,
                  onRetry: _reload,
                );
                if (panel != null) return panel;
                return const SizedBox.shrink();
              }

              final items = snapshot.data?.items ?? const [];
              if (items.isEmpty) {
                return const Center(child: Text('Менеджеров СВХ пока нет'));
              }

              return RefreshIndicator(
                onRefresh: () async {
                  _reload();
                  await _future;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Gap(8),
                  itemBuilder: (context, index) {
                    final m = items[index];
                    final title = m.fullName.trim().isNotEmpty
                        ? m.fullName.trim()
                        : m.login;
                    final subtitleParts = <String>[m.login];
                    if (m.phone.trim().isNotEmpty && m.phone.trim() != '-') {
                      subtitleParts.add(
                        PhoneRuInputFormatter.formatDisplay(m.phone.trim()),
                      );
                    }
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.local_shipping_outlined,
                                  color: m.active
                                      ? AppTheme.primaryBlue
                                      : Colors.grey,
                                ),
                                const Gap(12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const Gap(4),
                                      SelectableText(
                                        subtitleParts.join(' · '),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                const Gap(8),
                                Chip(
                                  label: Text(m.active ? 'Активен' : 'Отключён'),
                                  backgroundColor: m.active
                                      ? const Color(0xFFE8F5E9)
                                      : const Color(0xFFFFEBEE),
                                  side: BorderSide.none,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const Gap(12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await context.push('/svh-managers/${m.id}');
                                    if (mounted) _reload();
                                  },
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Изменить'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _openCopyCredentialsDialog(m),
                                  icon: const Icon(
                                    Icons.copy_outlined,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Копировать данные для входа',
                                  ),
                                ),
                                if (m.active)
                                  OutlinedButton.icon(
                                    onPressed: () => _setActive(m, false),
                                    icon: const Icon(
                                      Icons.block_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Отключить'),
                                  )
                                else
                                  OutlinedButton.icon(
                                    onPressed: () => _setActive(m, true),
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      size: 18,
                                    ),
                                    label: const Text('Включить'),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () => _deleteHard(m),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red.shade700,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Удалить'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
