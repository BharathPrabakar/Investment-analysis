// lib/providers/database_provider.dart
//
// Simple InheritedWidget that exposes AppDatabase down the widget tree.
// Use AppDbProvider.of(context) to obtain the database instance.

import 'package:flutter/widgets.dart';
import '../database/app_database.dart';

class AppDbProvider extends InheritedWidget {
  final AppDatabase db;

  const AppDbProvider({
    super.key,
    required this.db,
    required super.child,
  });

  static AppDatabase of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<AppDbProvider>();
    assert(provider != null, 'No AppDbProvider found in widget tree');
    return provider!.db;
  }

  @override
  bool updateShouldNotify(AppDbProvider oldWidget) => db != oldWidget.db;
}
