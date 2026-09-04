import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/core/ui/app_snackbars.dart';
import 'package:import_service_admin/core/ui/server_error_ui.dart';
import 'package:import_service_admin/domain/entities/svh_manager.dart';
import 'package:import_service_admin/domain/repositories/svh_managers_repository.dart';

class SvhManagersPage extends StatefulWidget {
  const SvhManagersPage({super.key});

  @override
  State<SvhManagersPage> createState() => _SvhManagersPageState();
}

class _SvhManagersPageState extends State<SvhManagersPage> {
  late Future<({List<SvhManager> items, int total})> _future;

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

  Future<void> _openCreateDialog() async {
    final loginController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый менеджер СВХ'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
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
                  decoration: const InputDecoration(labelText: 'Пароль'),
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
                  decoration: const InputDecoration(labelText: 'ФИО'),
                  textInputAction: TextInputAction.next,
                ),
                const Gap(12),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Телефон'),
                  keyboardType: TextInputType.phone,
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
      nameController.dispose();
      phoneController.dispose();
      return;
    }

    try {
      await sl<SvhManagersRepository>().create(
        login: loginController.text.trim(),
        password: passwordController.text,
        fullName: nameController.text.trim(),
        phone: phoneController.text.trim(),
      );
      if (!mounted) return;
      AppSnackBars.showSuccess('Менеджер СВХ создан');
      _reload();
    } on ServerException catch (e) {
      if (!mounted) return;
      AppSnackBars.showError(e.message);
    } catch (_) {
      if (!mounted) return;
      AppSnackBars.showError('Не удалось создать менеджера');
    } finally {
      loginController.dispose();
      passwordController.dispose();
      nameController.dispose();
      phoneController.dispose();
    }
  }

  Future<void> _openResetPassword(SvhManager manager) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сброс пароля'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passwordController,
            decoration: InputDecoration(
              labelText: 'Новый пароль',
              helperText: manager.login,
            ),
            obscureText: true,
            validator: (v) {
              if (v == null || v.length < 6) return 'Минимум 6 символов';
              return null;
            },
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

    if (ok != true || !mounted) {
      passwordController.dispose();
      return;
    }

    try {
      await sl<SvhManagersRepository>().update(
        id: manager.id,
        password: passwordController.text,
      );
      if (!mounted) return;
      AppSnackBars.showSuccess('Пароль обновлён');
      _reload();
    } on ServerException catch (e) {
      if (!mounted) return;
      AppSnackBars.showError(e.message);
    } catch (_) {
      if (!mounted) return;
      AppSnackBars.showError('Не удалось сменить пароль');
    } finally {
      passwordController.dispose();
    }
  }

  Future<void> _setActive(SvhManager manager, bool active) async {
    final title = active ? 'Включить менеджера?' : 'Отключить менеджера?';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(manager.fullName.isNotEmpty
            ? '${manager.fullName}\n${manager.login}'
            : manager.login),
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
      if (active) {
        await sl<SvhManagersRepository>().update(id: manager.id, active: true);
      } else {
        await sl<SvhManagersRepository>().delete(manager.id);
      }
      if (!mounted) return;
      AppSnackBars.showSuccess(active ? 'Менеджер включён' : 'Менеджер отключён');
      _reload();
    } on ServerException catch (e) {
      if (!mounted) return;
      AppSnackBars.showError(e.message);
    } catch (_) {
      if (!mounted) return;
      AppSnackBars.showError('Не удалось изменить статус');
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
                    final title =
                        m.fullName.trim().isNotEmpty ? m.fullName.trim() : m.login;
                    final subtitleParts = <String>[m.login];
                    if (m.phone.trim().isNotEmpty && m.phone.trim() != '-') {
                      subtitleParts.add(m.phone.trim());
                    }
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.local_shipping_outlined,
                          color: m.active
                              ? AppTheme.primaryBlue
                              : Colors.grey,
                        ),
                        title: Text(title),
                        subtitle: Text(subtitleParts.join(' · ')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(m.active ? 'Активен' : 'Отключён'),
                              backgroundColor: m.active
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFEBEE),
                              side: BorderSide.none,
                              visualDensity: VisualDensity.compact,
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'password':
                                    _openResetPassword(m);
                                  case 'disable':
                                    _setActive(m, false);
                                  case 'enable':
                                    _setActive(m, true);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'password',
                                  child: Text('Сбросить пароль'),
                                ),
                                if (m.active)
                                  const PopupMenuItem(
                                    value: 'disable',
                                    child: Text('Отключить'),
                                  )
                                else
                                  const PopupMenuItem(
                                    value: 'enable',
                                    child: Text('Включить'),
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
