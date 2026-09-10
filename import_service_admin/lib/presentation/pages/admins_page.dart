import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_admin/core/auth/auth_session_controller.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/core/ui/app_snackbars.dart';
import 'package:import_service_admin/core/ui/server_error_ui.dart';
import 'package:import_service_admin/domain/entities/admin_user.dart';
import 'package:import_service_admin/domain/repositories/admin_users_repository.dart';
import 'package:import_service_admin/presentation/helpers/admin_credentials_clipboard.dart';

class AdminsPage extends StatefulWidget {
  const AdminsPage({super.key});

  @override
  State<AdminsPage> createState() => _AdminsPageState();
}

class _AdminsPageState extends State<AdminsPage> {
  late Future<({List<AdminUser> items, int total})> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = sl<AdminUsersRepository>().list(limit: 200);
    });
  }

  int? get _currentAdminId {
    final raw = sl<AuthSessionController>().userId;
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  Future<void> _showCopiedDialog({
    required String login,
    required String password,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Данные для входа'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Логин и пароль скопированы в буфер.\n'
                'Вставьте в мессенджер (Ctrl+V). Письмо не отправляется.',
              ),
              const Gap(12),
              SelectableText('Логин: $login'),
              SelectableText('Пароль: $password'),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await copyAdminLoginCredentials(login: login, password: password);
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
      ),
    );
  }

  Future<void> _openCreateDialog() async {
    final loginController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый администратор'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: loginController,
                  decoration: const InputDecoration(labelText: 'Логин'),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Введите логин';
                    return null;
                  },
                ),
                const Gap(12),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    helperText: 'После создания можно скопировать в буфер',
                  ),
                  obscureText: true,
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
      return;
    }

    final login = loginController.text.trim();
    final password = passwordController.text;
    loginController.dispose();
    passwordController.dispose();

    try {
      await sl<AdminUsersRepository>().create(
        login: login,
        password: password,
      );
      if (!mounted) return;
      AppSnackBars.showSuccess('Администратор создан');
      _reload();
      await copyAdminLoginCredentials(login: login, password: password);
      await _showCopiedDialog(login: login, password: password);
    } on ServerException catch (e) {
      if (!mounted) return;
      AppSnackBars.showError(e.message);
    } catch (_) {
      if (!mounted) return;
      AppSnackBars.showError('Не удалось создать администратора');
    }
  }

  Future<void> _openEditDialog(AdminUser user) async {
    final loginController = TextEditingController(text: user.login);
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать администратора'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: loginController,
                  decoration: const InputDecoration(labelText: 'Логин'),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Введите логин';
                    return null;
                  },
                ),
                const Gap(12),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Новый пароль',
                    helperText: 'Оставьте пустым, чтобы не менять',
                  ),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (v.length < 6) return 'Минимум 6 символов';
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
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(context, true);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) {
      loginController.dispose();
      passwordController.dispose();
      return;
    }

    final nextLogin = loginController.text.trim();
    final nextPassword = passwordController.text;
    loginController.dispose();
    passwordController.dispose();

    final loginChanged = nextLogin != user.login;
    final passwordChanged = nextPassword.isNotEmpty;
    if (!loginChanged && !passwordChanged) {
      AppSnackBars.showSuccess('Изменений нет');
      return;
    }

    try {
      final updated = await sl<AdminUsersRepository>().update(
        id: user.id,
        login: loginChanged ? nextLogin : null,
        password: passwordChanged ? nextPassword : null,
      );
      if (!mounted) return;
      AppSnackBars.showSuccess('Сохранено');
      _reload();
      if (passwordChanged) {
        await copyAdminLoginCredentials(
          login: updated.login,
          password: nextPassword,
        );
        await _showCopiedDialog(login: updated.login, password: nextPassword);
      }
    } on ServerException catch (e) {
      if (!mounted) return;
      AppSnackBars.showError(e.message);
    } catch (_) {
      if (!mounted) return;
      AppSnackBars.showError('Не удалось сохранить');
    }
  }

  Future<void> _openCopyCredentialsDialog(AdminUser user) async {
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
                Text('Логин: ${user.login}'),
                const Gap(12),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    helperText:
                        'В БД хранится хеш — введите пароль, который выдаёте',
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

    final password = passwordController.text;
    passwordController.dispose();
    await copyAdminLoginCredentials(login: user.login, password: password);
    await _showCopiedDialog(login: user.login, password: password);
  }

  Future<void> _confirmDelete(AdminUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить администратора?'),
        content: Text('Логин: ${user.login}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await sl<AdminUsersRepository>().delete(user.id);
      if (!mounted) return;
      AppSnackBars.showSuccess('Администратор удалён');
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
    final currentId = _currentAdminId;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _openCreateDialog,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Добавить администратора'),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<({List<AdminUser> items, int total})>(
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
                return const Center(child: Text('Администраторов пока нет'));
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
                    final user = items[index];
                    final isSelf = currentId != null && user.id == currentId;
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.admin_panel_settings_outlined),
                        title: Text(user.login),
                        subtitle: Text(
                          user.createdAt != null
                              ? 'Создан: ${user.createdAt}'
                              : 'ID: ${user.id}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelf) const Chip(label: Text('Вы')),
                            IconButton(
                              tooltip: 'Редактировать',
                              onPressed: () => _openEditDialog(user),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Копировать логин/пароль',
                              onPressed: () => _openCopyCredentialsDialog(user),
                              icon: const Icon(Icons.copy_outlined),
                            ),
                            if (!isSelf)
                              IconButton(
                                tooltip: 'Удалить',
                                onPressed: () => _confirmDelete(user),
                                icon: const Icon(Icons.delete_outline),
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
