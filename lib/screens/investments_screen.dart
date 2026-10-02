// lib/screens/investments_screen.dart
import 'package:flutter/material.dart';
import '../stocks/stocks_section.dart';

/// Investments tab. Currently contains the Stocks section.
/// Future investment types (FD, MF, etc.) will be added as additional
/// sections or tabs within this screen.
class InvestmentsScreen extends StatelessWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // For now the Investments tab IS the Stocks section.
    // When more investment types are added, this will become a tabbed view.
    return const StocksSection();
  }
}
