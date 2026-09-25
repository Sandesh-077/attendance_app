import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'admin_navigation.dart';
import 'web_auth_state.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.child,
    required this.path,
    required this.auth,
  });

  final Widget child;
  final String path;
  final WebAuthState auth;

  @override
  Widget build(BuildContext context) {
    final selected = destinationForPath(path);
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1024;
        final medium = constraints.maxWidth >= 600 && !desktop;
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          drawer: desktop || medium
              ? null
              : Drawer(
                  child: _Sidebar(path: path, auth: auth, inDrawer: true),
                ),
          body: Row(
            children: [
              if (desktop)
                SizedBox(
                  width: 256,
                  child: _Sidebar(path: path, auth: auth),
                ),
              if (medium)
                SizedBox(
                  width: 80,
                  child: _Sidebar(path: path, auth: auth, compact: true),
                ),
              Expanded(
                child: Column(
                  children: [
                    Builder(
                      builder: (innerContext) => _Header(
                        title: selected.title,
                        name: auth.name,
                        showMenu: !desktop && !medium,
                        onMenu: () => Scaffold.of(innerContext).openDrawer(),
                      ),
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.name,
    required this.showMenu,
    required this.onMenu,
  });
  final String title;
  final String? name;
  final bool showMenu;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) => Container(
    height: 76,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Row(
      children: [
        if (showMenu) ...[
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Open navigation',
            onPressed: onMenu,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                name ?? 'Administrator',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(
                'Administrator',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.path,
    required this.auth,
    this.compact = false,
    this.inDrawer = false,
  });
  final String path;
  final WebAuthState auth;
  final bool compact;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget item(AdminDestination destination) {
      final selected = destinationForPath(path).path == destination.path;
      void navigate() {
        final router = GoRouter.of(context);
        if (inDrawer) Navigator.of(context).pop();
        router.go(destination.path);
      }

      if (compact) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Tooltip(
            message: destination.title,
            child: Material(
              color: selected
                  ? colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: navigate,
                child: SizedBox(
                  height: 52,
                  child: Icon(
                    destination.icon,
                    color: selected ? colorScheme.onPrimaryContainer : null,
                  ),
                ),
              ),
            ),
          ),
        );
      }
      final tile = ListTile(
        selected: selected,
        selectedTileColor: colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(destination.icon),
        title: Text(destination.title),
        onTap: navigate,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: tile,
      );
    }

    return ColoredBox(
      color: colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 20, 12, 24),
              child: compact
                  ? Tooltip(
                      message: 'CA Attendance',
                      child: Icon(
                        Icons.school,
                        color: colorScheme.primary,
                        size: 32,
                      ),
                    )
                  : Row(
                      children: [
                        Icon(
                          Icons.school,
                          color: colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CA Attendance',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'Admin Portal',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final destination in adminDestinations.take(
                    adminDestinations.length - 2,
                  ))
                    item(destination),
                ],
              ),
            ),
            const Divider(height: 1),
            item(adminDestinations[adminDestinations.length - 2]),
            item(adminDestinations.last),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 12,
                vertical: 8,
              ),
              child: compact
                  ? IconButton(
                      tooltip: 'Logout',
                      onPressed: auth.signOut,
                      icon: const Icon(Icons.logout),
                    )
                  : ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: const Icon(Icons.logout),
                      title: const Text('Logout'),
                      onTap: () async {
                        if (inDrawer) Navigator.of(context).pop();
                        await auth.signOut();
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
