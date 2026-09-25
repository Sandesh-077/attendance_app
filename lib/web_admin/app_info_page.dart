import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class WebAppInfoPage extends StatefulWidget {
  const WebAppInfoPage({super.key});

  @override
  State<WebAppInfoPage> createState() => _WebAppInfoPageState();
}

class _WebAppInfoPageState extends State<WebAppInfoPage> {
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: _info,
    builder: (context, snapshot) => ListView(
      padding: const EdgeInsets.all(32),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'App Info',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      title: Text('Application'),
                      subtitle: Text('CA Attendance Web'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Version'),
                      subtitle: Text(
                        snapshot.hasError
                            ? 'Unavailable'
                            : snapshot.hasData
                            ? snapshot.data!.version
                            : 'Loading…',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Build number'),
                      subtitle: Text(
                        snapshot.hasError
                            ? 'Unavailable'
                            : snapshot.hasData
                            ? snapshot.data!.buildNumber
                            : 'Loading…',
                      ),
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      title: Text('Environment'),
                      subtitle: Text('Production'),
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      title: Text('Developer'),
                      subtitle: Text('Sandesh Singh'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
