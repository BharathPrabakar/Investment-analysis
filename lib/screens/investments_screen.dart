// lib/screens/investments_screen.dart
import 'package:flutter/material.dart';
import '../stocks/stocks_section.dart';

/// Investments tab displaying Stocks portfolio.
class InvestmentsScreen extends StatelessWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StocksSection();
  }
}

