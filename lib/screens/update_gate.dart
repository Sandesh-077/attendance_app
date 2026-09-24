import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/app_update_service.dart';

class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});
  final Widget child;
  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  final _service = AppUpdateService();
  late final Future<(PackageInfo, ReleaseConfig?)> _check = _load();
  bool _prompted = false;

  Future<(PackageInfo, ReleaseConfig?)> _load() async {
    final info = await _service.installedInfo();
    try {
      return (info, await _service.fetchConfig());
    } catch (_) {
      return (info, null);
    }
  }

  void _showOptional(PackageInfo info, ReleaseConfig config) {
    if (_prompted) return;
    _prompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (config.hasUpdate(info.version)) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Update Available • Version ${config.latestVersion}'),
            content: SingleChildScrollView(
              child: Text("What's New:\n${config.releaseNotes}"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Later'),
              ),
              TextButton(
                onPressed: config.updateUrl == null
                    ? null
                    : () async {
                        if (await _service.openUpdate(config) &&
                            dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      },
                child: const Text('Update'),
              ),
            ],
          ),
        );
      } else if (info.version == config.latestVersion &&
          config.releaseNotes.trim().isNotEmpty &&
          !await _notesAlreadyShown(info.version)) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text("What's New • ${info.version}"),
            content: SingleChildScrollView(child: Text(config.releaseNotes)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        try {
          await _service.markReleaseNotesShown(info.version);
        } catch (_) {
          // Local storage failure must not prevent access to the app.
        }
      }
    });
  }

  Future<bool> _notesAlreadyShown(String version) async {
    try {
      return await _service.releaseNotesShown(version);
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<(PackageInfo, ReleaseConfig?)>(
    future: _check,
    builder: (context, snapshot) {
      if (snapshot.hasError) return widget.child;
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final (info, config) = snapshot.data!;
      if (config != null && config.requiresUpdate(info.version)) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.system_update, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Required Update • Version ${config.latestVersion}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(config.releaseNotes),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: config.updateUrl == null
                        ? null
                        : () async {
                            final opened = await _service.openUpdate(config);
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
                  if (config.updateUrl == null)
                    const Text(
                      'Contact your administrator for the update link.',
                    ),
                ],
              ),
            ),
          ),
        );
      }
      if (config != null) _showOptional(info, config);
      return widget.child;
    },
  );
}
