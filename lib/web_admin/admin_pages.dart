import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'admin_navigation.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key, required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final actions = adminDestinations
        .where(
          (destination) => {
            'Classes',
            'Students',
            'Teachers',
            'Attendance',
            'Reports',
          }.contains(destination.title),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, ${name ?? 'Administrator'}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Manage CA Attendance from your administration dashboard.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 36),
              Text(
                'Quick access',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 1000
                      ? 3
                      : width >= 600
                      ? 2
                      : 1;
                  final cardWidth = (width - (columns - 1) * 16) / columns;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final action in actions)
                        SizedBox(
                          width: cardWidth,
                          child: _QuickActionCard(destination: action),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.destination});
  final AdminDestination destination;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.go(destination.path),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              destination.icon,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              destination.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(destination.description),
            const SizedBox(height: 24),
            Text(
              'Open ${destination.title} →',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
