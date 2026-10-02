// Web-only file picker (admin is Flutter Web).
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/core/ui/server_error_ui.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/data/datasources/remote/android_apk_remote_data_source.dart';
import 'package:import_service_admin/data/datasources/remote/store_versions_remote_data_source.dart';
import 'package:import_service_admin/domain/repositories/customs_requests_repository.dart';
import 'package:import_service_admin/domain/repositories/organizations_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int? _requestsTotal;
  int? _newCount;
  int? _orgsTotal;
  String? _error;
  List<Map<String, dynamic>> _storeVersions = const [];
  String? _storeVersionsError;
  bool _scanningStores = false;
  Map<String, dynamic>? _apkStatus;
  String? _apkError;
  bool _uploadingApk = false;
  bool _verifyingApk = false;
  final _apkVersionCtrl = TextEditingController();
  final _apkChangelogCtrl = TextEditingController();
  Uint8List? _apkBytes;
  String? _apkFileName;
  String? _apkVerifyResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apkVersionCtrl.dispose();
    _apkChangelogCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _requestsTotal = null;
      _newCount = null;
      _orgsTotal = null;
      _storeVersionsError = null;
      _apkError = null;
    });
    try {
      final all = await sl<CustomsRequestsRepository>().listRequests(limit: 200);
      final newList = await sl<CustomsRequestsRepository>().listRequests(
        limit: 1,
        status: 'new',
      );
      final orgs = await sl<OrganizationsRepository>().list(limit: 1);
      List<Map<String, dynamic>> stores = const [];
      String? storesErr;
      try {
        stores = await sl<StoreVersionsRemoteDataSource>().fetchLatest();
      } catch (e) {
        storesErr = e is ServerException ? e.message : e.toString();
      }
      Map<String, dynamic>? apk;
      String? apkErr;
      try {
        apk = await sl<AndroidApkRemoteDataSource>().fetchStatus();
      } catch (e) {
        apkErr = e is ServerException ? e.message : e.toString();
      }
      if (!mounted) return;
      setState(() {
        _requestsTotal = all.total;
        _newCount = newList.total;
        _orgsTotal = orgs.total;
        _storeVersions = stores;
        _storeVersionsError = storesErr;
        _apkStatus = apk;
        _apkError = apkErr;
      });
    } catch (e) {
      if (!mounted) return;
      if (shouldHideErrorForAuth(e)) return;
      setState(() {
        _error = e is ServerException ? e.message : e.toString();
      });
    }
  }

  Future<void> _pickApk() async {
    if (_uploadingApk) return;
    final input = html.FileUploadInputElement()
      ..accept = '.apk,application/vnd.android.package-archive';
    input.click();
    await input.onChange.first;
    final file = input.files?.first;
    if (file == null) return;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    final raw = reader.result;
    late Uint8List bytes;
    if (raw is ByteBuffer) {
      bytes = raw.asUint8List();
    } else if (raw is Uint8List) {
      bytes = raw;
    } else {
      return;
    }
    if (!mounted) return;
    setState(() {
      _apkBytes = bytes;
      _apkFileName = file.name;
    });
    await _showPublishApkDialog();
  }

  /// Версия только в модалке после выбора файла — не на дашборде.
  Future<void> _showPublishApkDialog() async {
    if (_apkBytes == null || _apkFileName == null) return;
    final published = _apkStatus?['versionName']?.toString().trim();
    _apkVersionCtrl.text =
        (published != null && published.isNotEmpty) ? published : '';
    _apkChangelogCtrl.text = '';
    final fileName = _apkFileName!;
    final sizeMb = (_apkBytes!.length / (1024 * 1024)).toStringAsFixed(1);
    String? dialogError;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !_uploadingApk,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final build = _buildFromVersion(_apkVersionCtrl.text);
            return AlertDialog(
              title: const Text('Публикация APK'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Файл: $fileName ($sizeMb МБ)'),
                      const Gap(16),
                      TextField(
                        controller: _apkVersionCtrl,
                        enabled: !_uploadingApk,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Версия',
                          hintText: '1.0.54',
                          helperText: build == null
                              ? 'Формат X.Y.Z — билд = последние цифры'
                              : 'Билд: $build',
                          border: const OutlineInputBorder(),
                          errorText: dialogError,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) =>
                            setDialogState(() => dialogError = null),
                      ),
                      const Gap(12),
                      TextField(
                        controller: _apkChangelogCtrl,
                        enabled: !_uploadingApk,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Что изменилось',
                          hintText:
                              '• пункт 1\n• пункт 2\n• пункт 3',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _uploadingApk
                      ? null
                      : () => Navigator.of(ctx).pop(false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: _uploadingApk
                      ? null
                      : () {
                          final code =
                              _buildFromVersion(_apkVersionCtrl.text);
                          if (code == null) {
                            setDialogState(() {
                              dialogError =
                                  'Укажите версию вида 1.0.54';
                            });
                            return;
                          }
                          if (_apkChangelogCtrl.text.trim().isEmpty) {
                            setDialogState(() {
                              dialogError =
                                  'Укажите, что изменилось в этой версии';
                            });
                            return;
                          }
                          Navigator.of(ctx).pop(true);
                        },
                  child: _uploadingApk
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Опубликовать'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      if (mounted) {
        setState(() {
          _apkBytes = null;
          _apkFileName = null;
        });
      }
      return;
    }
    await _uploadApk();
  }

  String _fmtMb(Object? bytes) {
    final n = bytes is num ? bytes.toDouble() : double.tryParse('$bytes');
    if (n == null || n <= 0) return '—';
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  String _apkStatusText() {
    if (_apkStatus == null) return 'Статус неизвестен';
    if (_apkStatus!['available'] != true) return 'APK ещё не загружен';
    final code = _apkStatus!['versionCode'];
    final name = _apkStatus!['versionName'];
    final updated = _apkStatus!['updatedAt'];
    final size = _apkStatus!['sizeBytes'] ?? _apkStatus!['fileSizeBytes'];
    final sizeMatches = _apkStatus!['sizeMatches'];
    final sha = _apkStatus!['sha256']?.toString() ?? '';
    final shaShort =
        sha.length > 12 ? '${sha.substring(0, 12)}…' : sha;
    final sizeLine = sizeMatches == false
        ? 'Размер: ${_fmtMb(size)} ⚠ не совпадает с файлом на диске'
        : 'Размер: ${_fmtMb(size)}';
    final changelog = _apkStatus!['changelog']?.toString().trim() ?? '';
    return 'Опубликован: ${name ?? '—'}'
        '${code != null ? ' (build $code)' : ''}'
        '\n$sizeLine'
        '${shaShort.isNotEmpty ? '\nSHA256: $shaShort' : ''}'
        '${updated != null ? '\n$updated' : ''}'
        '${changelog.isNotEmpty ? '\n\nЧто изменилось:\n$changelog' : ''}';
  }

  List<Map<String, dynamic>> _apkHistoryRows() {
    final raw = _apkStatus?['history'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  /// Билд из хвоста версии: 1.0.53 → 53.
  int? _buildFromVersion(String raw) {
    final name = raw.trim();
    final re = RegExp(r'^(\d+)\.(\d+)\.(\d+)$');
    final m = re.firstMatch(name);
    if (m == null) return null;
    final code = int.tryParse(m.group(3)!);
    if (code == null || code < 1) return null;
    return code;
  }

  Future<void> _verifyApkOnServer() async {
    if (_verifyingApk) return;
    setState(() {
      _verifyingApk = true;
      _apkVerifyResult = null;
    });
    try {
      final result = await sl<AndroidApkRemoteDataSource>().verify();
      if (!mounted) return;
      final ok = result['ok'] == true;
      final msg = ok
          ? 'Проверка OK: ${_fmtMb(result['sizeBytes'])}, '
              'sha совпадает, ZIP magic OK'
          : 'Проверка FAIL: sizeMatches=${result['sizeMatches']}, '
              'shaMatches=${result['shaMatches']}, '
              'zipMagicOk=${result['zipMagicOk']} '
              '(файл ${_fmtMb(result['sizeBytes'])}, '
              'манифест ${_fmtMb(result['manifestSizeBytes'])})';
      setState(() {
        _apkVerifyResult = msg;
        if (result['available'] == true) {
          _apkStatus = {
            ...?_apkStatus,
            'available': true,
            'versionCode': result['versionCode'],
            'versionName': result['versionName'],
            'sizeBytes': result['sizeBytes'],
            'fileSizeBytes': result['sizeBytes'],
            'sizeMatches': result['sizeMatches'],
            'sha256': result['sha256'],
            'updatedAt': result['updatedAt'],
            'apkUrl': result['apkUrl'],
          };
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      final msg = e is ServerException ? e.message : 'Не удалось проверить APK';
      setState(() => _apkVerifyResult = msg);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _verifyingApk = false);
    }
  }

  Future<void> _uploadApk() async {
    final versionName = _apkVersionCtrl.text.trim();
    final code = _buildFromVersion(versionName);
    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите версию вида 1.0.53 (билд = последние цифры)'),
        ),
      );
      return;
    }
    if (_apkBytes == null || _apkBytes!.isEmpty || _apkFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите APK файл')),
      );
      return;
    }
    final localSize = _apkBytes!.length;
    setState(() {
      _uploadingApk = true;
      _apkVerifyResult = null;
    });
    try {
      final result = await sl<AndroidApkRemoteDataSource>().upload(
        fileBytes: _apkBytes!,
        fileName: _apkFileName!,
        versionName: versionName,
        changelog: _apkChangelogCtrl.text.trim(),
      );
      if (!mounted) return;
      final remoteSize = _asInt(result['sizeBytes']);
      final sizeOk = remoteSize == localSize;
      final verify = await sl<AndroidApkRemoteDataSource>().verify();
      if (!mounted) return;
      final integrityOk = verify['ok'] == true;
      final msg = !sizeOk
          ? 'ОШИБКА: локальный размер ${_fmtMb(localSize)} ≠ на сервере ${_fmtMb(remoteSize)}'
          : !integrityOk
              ? 'ОШИБКА после выкладки: проверка sha/размера не прошла'
              : 'APK опубликован: $versionName (build $code), ${_fmtMb(localSize)}, проверка OK';
      setState(() {
        _apkStatus = result;
        _apkBytes = null;
        _apkFileName = null;
        _apkVerifyResult = msg;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ServerException ? e.message : 'Не удалось загрузить APK',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingApk = false);
    }
  }

  Future<void> _scanStores() async {
    if (_scanningStores) return;
    setState(() => _scanningStores = true);
    try {
      final stores = await sl<StoreVersionsRemoteDataSource>().scanNow();
      if (!mounted) return;
      setState(() {
        _storeVersions = stores;
        _storeVersionsError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сканирование сторов завершено')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ServerException ? e.message : 'Не удалось сканировать сторы',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _scanningStores = false);
    }
  }

  void _goRequests({String? status}) {
    if (status != null && status.isNotEmpty) {
      context.go('/requests?status=${Uri.encodeQueryComponent(status)}');
    } else {
      context.go('/requests');
    }
  }

  void _goOrganizations() {
    context.go('/organizations');
  }

  String _storeLabel(String store) {
    switch (store) {
      case 'google_play':
        return 'Google Play';
      case 'rustore':
        return 'RuStore';
      case 'app_store':
        return 'App Store';
      default:
        return store;
    }
  }

  String _formatStoreVersion(Map<String, dynamic> row) {
    final name = row['versionName']?.toString();
    final code = row['versionCode'];
    if (name != null && name.isNotEmpty) {
      if (code != null) return '$name (build $code)';
      return name;
    }
    if (code != null) return 'build $code';
    return '—';
  }

  String _formatStoreMeta(Map<String, dynamic> row) {
    final status = row['status']?.toString() ?? '';
    if (status == 'error') {
      return row['errorMessage']?.toString() ?? 'ошибка';
    }
    final source = row['scanSource']?.toString().trim();
    final scanned = row['scannedAt']?.toString() ?? '—';
    if (source != null && source.isNotEmpty) {
      return '$source · $scanned';
    }
    return scanned;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const Gap(12),
            FilledButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Обзор',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Gap(20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(
                title: 'Заявки',
                value: _requestsTotal?.toString() ?? '…',
                icon: Icons.assignment_outlined,
                color: AppTheme.primaryBlue,
                onTap: () => _goRequests(),
              ),
              _StatCard(
                title: 'Статус new',
                value: _newCount?.toString() ?? '…',
                subtitle: 'можно отправить в 1С',
                icon: Icons.upload_outlined,
                color: AppTheme.accentRed,
                onTap: () => _goRequests(status: 'new'),
              ),
              _StatCard(
                title: 'Организации',
                value: _orgsTotal?.toString() ?? '…',
                icon: Icons.business_outlined,
                color: const Color(0xFF2E7D32),
                onTap: _goOrganizations,
              ),
            ],
          ),
          const Gap(28),
          Text(
            'APK на сервере',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Gap(12),
          if (_apkError != null)
            Text(
              _apkError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.accentRed,
                  ),
            ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_apkStatusText()),
                  if (_apkVerifyResult != null) ...[
                    const Gap(8),
                    Text(
                      _apkVerifyResult!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _apkVerifyResult!.startsWith('ОШИБКА') ||
                                    _apkVerifyResult!.startsWith('Проверка FAIL')
                                ? AppTheme.accentRed
                                : const Color(0xFF2E7D32),
                          ),
                    ),
                  ],
                  const Gap(12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _uploadingApk ? null : _pickApk,
                        icon: _uploadingApk
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.attach_file),
                        label: Text(
                          _uploadingApk ? 'Публикация…' : 'Выбрать APK',
                        ),
                      ),
                      if (_apkStatus != null && _apkStatus!['available'] == true)
                        OutlinedButton.icon(
                          onPressed: (_uploadingApk || _verifyingApk)
                              ? null
                              : _verifyApkOnServer,
                          icon: _verifyingApk
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.verified_outlined),
                          label: const Text('Проверить на сервере'),
                        ),
                      if (_apkStatus != null && _apkStatus!['available'] == true)
                        OutlinedButton.icon(
                          onPressed: () async {
                            final url = _apkStatus!['apkUrl']?.toString() ??
                                'https://app.import-service.su/api/app/android-apk/download';
                            await Clipboard.setData(ClipboardData(text: url));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ссылка на APK скопирована'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.link),
                          label: const Text('Скопировать ссылку'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_apkHistoryRows().isNotEmpty) ...[
            const Gap(16),
            Text(
              'История выкладок APK',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Gap(8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (var i = 0; i < _apkHistoryRows().length; i++) ...[
                      if (i > 0) const Divider(height: 20),
                      _ApkHistoryTile(row: _apkHistoryRows()[i]),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const Gap(28),
          Row(
            children: [
              Text(
                'Версии в сторах',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _scanningStores ? null : _scanStores,
                icon: _scanningStores
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('Сканировать'),
              ),
            ],
          ),
          const Gap(12),
          if (_storeVersionsError != null)
            Text(
              _storeVersionsError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.accentRed,
                  ),
            ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_storeVersions.isEmpty)
                    const Text('Нет данных — запустите сканирование')
                  else
                    for (final row in _storeVersions)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                _storeLabel(row['store']?.toString() ?? ''),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                _formatStoreVersion(row),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                _formatStoreMeta(row),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApkHistoryTile extends StatelessWidget {
  const _ApkHistoryTile({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final name = row['versionName']?.toString() ?? '—';
    final code = row['versionCode'];
    final updated = row['updatedAt']?.toString() ?? '';
    final changelog = row['changelog']?.toString().trim() ?? '';
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$name${code != null ? ' (build $code)' : ''}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (updated.isNotEmpty)
            Text(
              updated,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          const Gap(6),
          Text(
            changelog.isEmpty ? 'Без описания изменений' : changelog,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: changelog.isEmpty ? Colors.black45 : null,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 28),
                const Gap(12),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
                const Gap(4),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                if (subtitle != null) ...[
                  const Gap(4),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
