import 'package:flutter/material.dart';

class LeaveBalance {
  final String type;
  final String label;
  final IconData iconData;
  final int total;
  final int used;
  final int remaining;

  LeaveBalance({
    required this.type,
    required this.label,
    required this.iconData,
    required this.total,
    required this.used,
    required this.remaining,
  });

  static IconData _iconFromName(String name) {
    switch (name) {
      case 'medical_services': return Icons.medical_services;
      case 'event_available': return Icons.event_available;
      case 'money_off': return Icons.money_off;
      default: return Icons.more_horiz;
    }
  }

  static LeaveBalance fromJson(String type, String label, String iconName, Map<String, dynamic> json) {
    final total = (json['total'] as num?)?.toInt() ?? 0;
    final used = (json['used'] as num?)?.toInt() ?? 0;
    final remaining = (json['remaining'] as num?)?.toInt() ?? (total - used).clamp(0, total);
    return LeaveBalance(
      type: type,
      label: label,
      iconData: _iconFromName(iconName),
      total: total,
      used: used,
      remaining: remaining,
    );
  }
}
