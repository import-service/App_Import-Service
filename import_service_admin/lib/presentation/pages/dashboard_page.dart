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
  final _apkVersionCodeCtrl = TextEditingController();
  final _apkVersionNameCtrl = TextEditingController();
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
    _apkVersionCodeCtrl.dispose();
    _apkVersionNameCtrl.dispose();
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
        if (apk != null && apk['available'] == true) {
          final code = apk['versionCode'];
          if (code != null) _apkVersionCodeCtrl.text = '$code';
          final name = apk['versionName']?.toString();
          if (name != null && name.isNotEmpty) {
            _apkVersionNameCtrl.text = name;
          }
        }
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
    final input = html.FileUploadInputElement()..accept = '.apk,application/vnd.android.package-archive';
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
    setState(() {
      _apkBytes = bytes;
      _apkFileName = file.name;
    });
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
    return 'Опубликован: build $code'
        '${name != null ? ' ($name)' : ''}'
        '\n$sizeLine'
        '${shaShort.isNotEmpty ? '\nSHA256: $shaShort' : ''}'
        '${updated != null ? '\n$updated' : ''}';
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
    final code = int.tryParse(_apkVersionCodeCtrl.text.trim());
    if (code == null || code < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите versionCode (buildNumber)')),
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
        versionCode: code,
        versionName: _apkVersionNameCtrl.text.trim(),
      );
      if (!mounted) return;
      final remoteSize = _asInt(result['sizeBytes']);
      final sizeOk = remoteSize == localSize;
      final sizeMatches = result['sizeMatches'] != false;
      final verify = await sl<AndroidApkRemoteDataSource>().verify();
      if (!mounted) return;
      final integrityOk = verify['ok'] == true;
      final msg = !sizeOk
          ? 'ОШИБКА: локальный размер ${_fmtMb(localSize)} ≠ на сервере ${_fmtMb(remoteSize)}'
          : !integrityOk
              ? 'ОШИБКА после выкладки: проверка sha/размера не прошла'
              : 'APK опубликован: ${_fmtMb(localSize)}, проверка OK';
      setState(() {
        _apkStatus = result;
        _apkBytes = null;
        _apkFileName = null;
        _apkVerifyResult = msg;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (!sizeOk || !sizeMatches || !integrityOk) {
        // оставляем статус видимым
      }
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
                  TextField(
                    controller: _apkVersionCodeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'versionCode (buildNumber)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const Gap(8),
                  TextField(
                    controller: _apkVersionNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'versionName (опционально)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const Gap(8),
                  Text(
                    _apkFileName == null
                        ? 'Файл не выбран'
                        : 'Файл: $_apkFileName (${((_apkBytes?.length ?? 0) / (1024 * 1024)).toStringAsFixed(1)} МБ)',
                  ),
                  const Gap(8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _uploadingApk ? null : _pickApk,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Выбрать APK'),
                      ),
                      FilledButton.icon(
                        onPressed: _uploadingApk ? null : _uploadApk,
                        icon: _uploadingApk
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Опубликовать'),
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
                                'https://157-22-173-7.sslip.io/api/app/android-apk/download';
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
                                row['status'] == 'error'
                                    ? row['errorMessage']?.toString() ?? 'ошибка'
                                    : row['scannedAt']?.toString() ?? '—',
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
