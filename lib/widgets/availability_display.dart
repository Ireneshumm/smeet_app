import 'package:flutter/material.dart';

import 'package:smeet_app/core/constants/sports.dart';

/// Read-only availability: one row per day that has slots; hidden days omitted.
class AvailabilityDisplayWidget extends StatelessWidget {
  final Map<String, dynamic>? availability;

  const AvailabilityDisplayWidget({super.key, this.availability});

  @override
  Widget build(BuildContext context) {
    final normalized = availability == null
        ? <String, List<String>>{}
        : normalizeAvailabilityMap(availability);

    if (normalized.isEmpty) {
      return Text(
        'No availability set',
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final orderedDays =
        kAvailabilityDays.where((day) => normalized.containsKey(day)).toList();

    if (orderedDays.isEmpty) {
      return Text(
        'No availability set',
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: orderedDays.map((day) {
        final slots = normalized[day] ?? [];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  day,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: kAvailabilitySlots
                      .where((s) => slots.contains(s))
                      .map((slot) {
                    final si = kAvailabilitySlots.indexOf(slot);
                    final slotColor = kAvailabilitySlotColors[si];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: slotColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: slotColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            kAvailabilitySlotIcons[si],
                            size: 12,
                            color: slotColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            slot,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: slotColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
