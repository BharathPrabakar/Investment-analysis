// lib/stocks/widgets/tag_chip.dart
//
// Reusable tag chip widget used in card list view and detail view.

import 'package:flutter/material.dart';

class TagChip extends StatelessWidget {
  final String label;
  final VoidCallback? onDeleted;

  const TagChip({super.key, required this.label, this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: cs.onSecondaryContainer,
        ),
      ),
      backgroundColor: cs.secondaryContainer,
      deleteIconColor: cs.onSecondaryContainer.withValues(alpha: 0.7),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      onDeleted: onDeleted,
    );
  }
}
