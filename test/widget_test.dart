import 'package:ca_attendance/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MyApp builds a MaterialApp shell', (tester) async {
    await tester.pumpWidget(
      const MyApp(
        home: Scaffold(body: Center(child: Text('App shell test'))),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('App shell test'), findsOneWidget);
  });
}
