import 'package:flutter/material.dart';

import 'package:smeet_app/core/constants/sports.dart';

/// Weekly availability editor: one row per day, three slot chips (Morning / Afternoon / Evening).
class AvailabilityPickerWidget extends StatefulWidget {
  final Map<String, List<String>> initialValue;
  final ValueChanged<Map<String, List<String>>> onChanged;

  const AvailabilityPickerWidget({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<AvailabilityPickerWidget> createState() =>
      _AvailabilityPickerWidgetState();
}

class _AvailabilityPickerWidgetState extends State<AvailabilityPickerWidget> {
  late Map<String, Set<String>> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {};
    for (final day in kAvailabilityDays) {
      final slots = widget.initialValue[day] ?? [];
      _selected[day] = slots.toSet();
    }
  }

  @override
  void didUpdateWidget(covariant AvailabilityPickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameMaps(widget.initialValue, oldWidget.initialValue)) {
      setState(() {
        for (final day in kAvailabilityDays) {
          final slots = widget.initialValue[day] ?? [];
          _selected[day] = slots.toSet();
        }
      });
    }
  }

  bool _sameMaps(
    Map<String, List<String>> a,
    Map<String, List<String>> b,
  ) {
    for (final day in kAvailabilityDays) {
      final la = List<String>.from(a[day] ?? [])..sort();
      final lb = List<String>.from(b[day] ?? [])..sort();
      if (la.length != lb.length) return false;
      for (var i = 0; i < la.length; i++) {
        if (la[i] != lb[i]) return false;
      }
    }
    return true;
  }

  void _emit() {
    final result = <String, List<String>>{};
    for (final e in _selected.entries) {
      if (e.value.isNotEmpty) {
        result[e.key] = kAvailabilitySlots
            .where((s) => e.value.contains(s))
            .toList();
      }
    }
    widget.onChanged(result);
  }

  void _toggle(String day, String slot) {
    setState(() {
      if (_selected[day]!.contains(slot)) {
        _selected[day]!.remove(slot);
      } else {
        _selected[day]!.add(slot);
      }
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: List.generate(kAvailabilityDaysShort.length, (di) {
        final day = kAvailabilityDays[di];
        final dayShort = kAvailabilityDaysShort[di];
        final isWeekend = di >= 5;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  dayShort,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isWeekend ? cs.primary : cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: List.generate(kAvailabilitySlots.length, (si) {
                    final slot = kAvailabilitySlots[si];
                    final selected = _selected[day]!.contains(slot);
                    final slotColor = kAvailabilitySlotColors[si];

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _toggle(day, slot),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 6),
                          height: 34,
                          decoration: BoxDecoration(
                            color: selected
                                ? slotColor.withValues(alpha: 0.15)
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  selected ? slotColor : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                kAvailabilitySlotIcons[si],
                                size: 14,
                                color: selected
                                    ? slotColor
                                    : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                availabilitySlotShort(slot),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? slotColor
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
