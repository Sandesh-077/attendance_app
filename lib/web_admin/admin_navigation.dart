import 'package:flutter/material.dart';

class AdminDestination {
  const AdminDestination(this.path, this.title, this.icon, this.description);

  final String path;
  final String title;
  final IconData icon;
  final String description;
}

const adminDestinations = <AdminDestination>[
  AdminDestination('/admin', 'Dashboard', Icons.dashboard_outlined, ''),
  AdminDestination(
    '/admin/classes',
    'Classes',
    Icons.class_outlined,
    'Manage classes and archives.',
  ),
  AdminDestination(
    '/admin/students',
    'Students',
    Icons.people_outline,
    'Manage students and archives.',
  ),
  AdminDestination(
    '/admin/teachers',
    'Teachers',
    Icons.school_outlined,
    'Manage teachers.',
  ),
  AdminDestination(
    '/admin/assignments',
    'Assignments',
    Icons.assignment_outlined,
    'Manage class assignments.',
  ),
  AdminDestination(
    '/admin/attendance',
    'Attendance',
    Icons.fact_check_outlined,
    'Take and review attendance.',
  ),
  AdminDestination(
    '/admin/reports',
    'Reports',
    Icons.description_outlined,
    'Review student reports.',
  ),
  AdminDestination(
    '/admin/profile',
    'Profile',
    Icons.account_circle_outlined,
    'Update your profile.',
  ),
  AdminDestination(
    '/admin/app-info',
    'App Info',
    Icons.info_outline,
    'View web app information.',
  ),
];

AdminDestination destinationForPath(String path) {
  if (path.startsWith('/admin/report-options')) {
    return adminDestinations.firstWhere(
      (item) => item.path == '/admin/classes',
    );
  }
  for (final destination in adminDestinations.reversed) {
    if (path == destination.path || path.startsWith('${destination.path}/')) {
      return destination;
    }
  }
  return adminDestinations.first;
}
