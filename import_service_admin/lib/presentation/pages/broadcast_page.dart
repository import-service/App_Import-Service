// Web-only file picker (admin is Flutter Web).
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/theme/app_theme.dart';
import 'package:import_service_admin/core/ui/app_snackbars.dart';
import 'package:import_service_admin/data/datasources/remote/broadcast_remote_data_source.dart';

class BroadcastPage extends StatefulWidget {
  const BroadcastPage({super.key});

  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage> {
  final _broadcast = sl<BroadcastRemoteDataSource>();
  final _textCtrl = TextEditingController();
  final _senderCtrl = TextEditingController();
  bool _busy = false;
  Uint8List? _fileBytes;
  String? _fileName;
  Map<String, dynamic>? _lastResult;

  @override
  void dispose() {
    _textCtrl.dispose();
    _senderCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*,application/pdf';
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
      _fileBytes = bytes;
      _fileName = file.name;
    });
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && (_fileBytes == null || _fileBytes!.isEmpty)) {
      AppSnackBars.showError('Введите текст или прикрепите файл', context: context);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await _broadcast.send(
        text: text,
        senderName: _senderCtrl.text.trim(),
        fileBytes: _fileBytes?.toList(),
        fileName: _fileName,
      );
      if (!mounted) return;
      setState(() {
        _lastResult = r;
        _textCtrl.clear();
        _fileBytes = null;
        _fileName = null;
      });
      AppSnackBars.showSuccess(
        'Отправлено: чат ${r['chatOk'] ?? 0}/${r['organizations'] ?? 0}, '
        'email ${r['emailOk'] ?? 0}',
        context: context,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBars.showError('$e', context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = _lastResult;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Рассылка', style: theme.textTheme.titleLarge),
        const Gap(8),
        Text(
          'Сообщение уйдёт всем организациям (deleted_at IS NULL): в общий чат приложения, '
          'на email (login организации) и push. Клиент может ответить в общем чате.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
        ),
        const Gap(16),
        TextField(
          controller: _textCtrl,
          minLines: 4,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: 'Текст сообщения',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const Gap(10),
        TextField(
          controller: _senderCtrl,
          decoration: const InputDecoration(
            labelText: 'Отправитель (необязательно)',
            hintText: 'Рассылка',
            border: OutlineInputBorder(),
          ),
        ),
        const Gap(12),
        Row(
          children: [
            OutlinedButton(
              onPressed: _busy ? null : _pickFile,
              child: const Text('Прикрепить файл'),
            ),
            const Gap(12),
            Expanded(
              child: Text(
                _fileName ?? 'Файл не выбран (PDF или изображение)',
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_fileName != null)
              IconButton(
                tooltip: 'Убрать файл',
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _fileBytes = null;
                          _fileName = null;
                        }),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const Gap(16),
        FilledButton(
          onPressed: _busy ? null : _send,
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Отправить всем'),
        ),
        if (last != null) ...[
          const Gap(20),
          Text('Последняя рассылка', style: theme.textTheme.titleSmall),
          const Gap(8),
          Text('Организаций: ${last['organizations'] ?? '—'}'),
          Text('Чат: ${last['chatOk'] ?? 0} ok, ${last['chatFail'] ?? 0} ошибок'),
          Text(
            'Email: ${last['emailOk'] ?? 0} ok, '
            '${last['emailSkip'] ?? 0} без адреса, '
            '${last['emailFail'] ?? 0} ошибок',
          ),
        ],
      ],
    );
  }
}
