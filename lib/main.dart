// lib/main.dart
import 'package:flutter/material.dart';

import 'data/local_tickers.dart';
import 'database/app_database.dart';
import 'providers/database_provider.dart';
import 'screens/analysis_screen.dart';
import 'screens/investments_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ensureTickersLoaded();
  runApp(const InvestmentTrackerApp());
}

class InvestmentTrackerApp extends StatefulWidget {
  final AppDatabase? db;
  const InvestmentTrackerApp({super.key, this.db});

  @override
  State<InvestmentTrackerApp> createState() => _InvestmentTrackerAppState();
}

class _InvestmentTrackerAppState extends State<InvestmentTrackerApp> {
  late final AppDatabase _db;
  late final bool _ownsDb;

  @override
  void initState() {
    super.initState();
    if (widget.db != null) {
      _db = widget.db!;
      _ownsDb = false;
    } else {
      _db = AppDatabase();
      _ownsDb = true;
    }
  }

  @override
  void dispose() {
    if (_ownsDb) {
      _db.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDbProvider(
      db: _db,
      child: MaterialApp(
        title: 'Investment Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A6B72),
            brightness: Brightness.light,
          ),
          textTheme: const TextTheme().apply(fontFamily: 'Roboto'),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A6B72),
            brightness: Brightness.dark,
          ),
          textTheme: const TextTheme().apply(fontFamily: 'Roboto'),
        ),
        themeMode: ThemeMode.system,
        home: const AppShell(),
      ),
    );
  }
}

/// [AppShell] owns the bottom navigation and swaps between top-level screens.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  // Top-level destination definitions — add new tabs here in future steps.
  static const _destinations = [
    (
      label: 'Investments',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
    ),
    (
      label: 'Analysis',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
    ),
  ];

  // Screens are kept in a list so each builds lazily but survives tab switches.
  static const _screens = <Widget>[
    InvestmentsScreen(),
    AnalysisScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _destinations[_selectedIndex].label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
