/// Custom date picker with app branding.
/// Celadon green theme, clean calendar grid.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:plain/app/theme/design_tokens.dart';

/// Show custom date picker dialog. Returns selected date (UTC).
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _AppDatePickerDialog(
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime.now().add(const Duration(days: 1)),
    ),
  );
}

class _AppDatePickerDialog extends StatefulWidget {
  const _AppDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_AppDatePickerDialog> createState() => _AppDatePickerDialogState();
}

class _AppDatePickerDialogState extends State<_AppDatePickerDialog> {
  late DateTime _selectedDate;
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    _displayMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: selected date
            Text(
              _formatHeaderDate(_selectedDate),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: context.colors.ink),
            ),
            const SizedBox(height: Spacing.xl),

            // Month navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: context.colors.inkSecondary),
                  onPressed: _prevMonth,
                ),
                Text(
                  '${_displayMonth.year}年${_displayMonth.month}月',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.colors.ink),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: context.colors.inkSecondary),
                  onPressed: _nextMonth,
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),

            // Weekday header
            Row(
              children: ['一', '二', '三', '四', '五', '六', '日'].map((d) {
                return Expanded(
                  child: Center(
                    child: Text(d, style: TextStyle(fontSize: 12, color: context.colors.inkTertiary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: Spacing.sm),

            // Calendar grid
            _buildCalendarGrid(),
            const SizedBox(height: Spacing.xl),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('取消', style: TextStyle(color: context.colors.inkSecondary)),
                ),
                const SizedBox(width: Spacing.md),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selectedDate.toUtc()),
                  child: Text('确定', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final lastDay = DateTime(_displayMonth.year, _displayMonth.month + 1, 0);
    // Monday = 0, Sunday = 6
    final startWeekday = (firstDay.weekday - 1) % 7;
    final totalDays = lastDay.day;

    final cells = <Widget>[];

    // Empty cells before first day
    for (var i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }

    // Day cells
    for (var day = 1; day <= totalDays; day++) {
      final date = DateTime(_displayMonth.year, _displayMonth.month, day);
      final isSelected = date.year == _selectedDate.year &&
          date.month == _selectedDate.month &&
          date.day == _selectedDate.day;
      final isToday = date.year == DateTime.now().year &&
          date.month == DateTime.now().month &&
          date.day == DateTime.now().day;
      final isDisabled = date.isBefore(widget.firstDate) || date.isAfter(widget.lastDate);

      cells.add(
        GestureDetector(
          onTap: isDisabled ? null : () => setState(() => _selectedDate = date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.colors.primary
                  : isToday
                      ? context.colors.primary.withValues(alpha: 0.1)
                      : null,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isDisabled
                      ? context.colors.inkTertiary.withValues(alpha: 0.4)
                      : isSelected
                          ? context.colors.onPrimary
                          : isToday
                              ? context.colors.primary
                              : context.colors.ink,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: 1.1,
      children: cells,
    );
  }

  void _prevMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1);
    });
  }

  String _formatHeaderDate(DateTime date) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = weekdays[(date.weekday - 1) % 7];
    return '${date.year}年${date.month}月${date.day}日 $weekday';
  }
}
