import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/app_update_service.dart';

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key});
  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  final _service = AppUpdateService();
  late final Future<PackageInfo> _info = _service.installedInfo();
  ReleaseConfig? _config;
  bool _checking = false;
  String? _message;

  Future<void> _check() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      final config = await _service.fetchConfig();
      final info = await _info;
      if (!mounted) return;
      setState(() {
        _config = config;
        _message = config == null
            ? 'Release information is unavailable.'
            : config.hasUpdate(info.version)
            ? 'Version ${config.latestVersion} is available.'
            : 'You have the latest version.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Unable to check for updates. Try again later.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('App Info')),
    body: FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snapshot) {
        final info = snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const ListTile(
              title: Text('Application'),
              subtitle: Text('CA Attendance'),
            ),
            ListTile(
              title: const Text('Installed version'),
              subtitle: Text(info?.version ?? 'Unavailable'),
            ),
            ListTile(
              title: const Text('Build number'),
              subtitle: Text(info?.buildNumber ?? 'Unavailable'),
            ),
            const ListTile(
              title: Text('Developer'),
              subtitle: Text('Sandesh Singh'),
            ),
            const ListTile(
              title: Text('Environment'),
              subtitle: Text('Production'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _checking ? null : _check,
              icon: const Icon(Icons.refresh),
              label: const Text('Check for Updates'),
            ),
            if (_checking) const Center(child: CircularProgressIndicator()),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_message!),
              ),
            if (_config != null) ...[
              const SizedBox(height: 16),
              Text(
                "What's New • ${_config!.latestVersion}",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _config!.releaseNotes.isEmpty
                    ? 'No release notes available.'
                    : _config!.releaseNotes,
              ),
              if (info != null && _config!.hasUpdate(info.version))
                TextButton(
                  onPressed: _config!.updateUrl == null
                      ? null
                      : () async {
                          final opened = await _service.openUpdate(_config!);
                          if (!opened && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Unable to open the update link.',
                                ),
                              ),
                            );
                          }
                        },
                  child: const Text('Update'),
                ),
            ],
          ],
        );
      },
    ),
  );
}
