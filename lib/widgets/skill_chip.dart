import 'package:flutter/material.dart';

class SkillChip extends StatelessWidget {
  final String name;
  final String? category;
  final VoidCallback? onDeleted;

  const SkillChip({
    super.key,
    required this.name,
    this.category,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        Icons.bolt,
        size: 16,
        color: colorScheme.primary,
      ),
      label: Text(
        category != null ? '$name ($category)' : name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.4),
      side: BorderSide(
        color: colorScheme.primary.withValues(alpha: 0.2),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      deleteIcon: onDeleted != null
          ? Icon(Icons.close, size: 16, color: colorScheme.error)
          : null,
      onDeleted: onDeleted,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}
