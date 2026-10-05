import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:import_service_admin/core/di/injection_container.dart';
import 'package:import_service_admin/core/error/exceptions.dart';
import 'package:import_service_admin/core/ui/server_error_ui.dart';
import 'package:import_service_admin/data/datasources/remote/android_apk_remote_data_source.dart';
import 'package:import_service_admin/presentation/widgets/apk_release_history_tile.dart';

class ApkReleaseHistoryPage extends StatefulWidget {
  const ApkReleaseHistoryPage({super.key});

  @override
  State<ApkReleaseHistoryPage> createState() => _ApkReleaseHistoryPageState();
}

class _ApkReleaseHistoryPageState extends State<ApkReleaseHistoryPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await sl<AndroidApkRemoteDataSource>().fetchStatus();
      final raw = status['history'];
      final list = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
              .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _rows = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (shouldHideErrorForAuth(e)) return;
      setState(() {
        _loading = false;
        _error = e is ServerException ? e.message : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История выкладок APK'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.red,
                          ),
                    )
                  else if (_rows.isEmpty)
                    const Text('История пуста')
                  else
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
                            for (var i = 0; i < _rows.length; i++) ...[
                              if (i > 0) const Divider(height: 20),
                              ApkReleaseHistoryTile(row: _rows[i]),
                            ],
                          ],
                        ),
                      ),
                    ),
                  const Gap(24),
                ],
              ),
            ),
    );
  }
}
