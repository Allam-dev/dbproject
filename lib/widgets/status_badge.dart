import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color _backgroundColor() {
    switch (status.toLowerCase()) {
      case 'available':
        return const Color(0xFF2E7D32);
      case 'deployed':
        return const Color(0xFFE65100);
      case 'inactive':
        return const Color(0xFFC62828);
      case 'active':
        return const Color(0xFFC62828);
      case 'resolved':
        return const Color(0xFF2E7D32);
      default:
        return Colors.grey;
    }
  }

  IconData _icon() {
    switch (status.toLowerCase()) {
      case 'available':
        return Icons.check_circle_outline;
      case 'deployed':
        return Icons.flight_takeoff;
      case 'inactive':
        return Icons.cancel_outlined;
      case 'active':
        return Icons.warning_amber_rounded;
      case 'resolved':
        return Icons.check_circle;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundColor().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _backgroundColor().withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(), size: 14, color: _backgroundColor()),
          const SizedBox(width: 4),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: TextStyle(
              color: _backgroundColor(),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
