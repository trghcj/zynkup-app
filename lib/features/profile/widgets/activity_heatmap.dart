import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';

class ActivityHeatmap extends StatelessWidget {
  final Map<String, int> data;
  const ActivityHeatmap({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // Show last 12 weeks (84 days)
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 83));
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ZynkColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZynkColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Activity', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              _LegendItem(label: 'Less', color: Colors.white10),
              const SizedBox(width: 4),
              _LegendItem(label: '', color: ZynkColors.primary.withValues(alpha: 0.3)),
              const SizedBox(width: 4),
              _LegendItem(label: '', color: ZynkColors.primary.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              _LegendItem(label: 'More', color: ZynkColors.primary),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: 84,
              itemBuilder: (context, index) {
                final date = startDate.add(Duration(days: index));
                final dateStr = date.toIso8601String().split('T')[0];
                final count = data[dateStr] ?? 0;
                
                return Container(
                  decoration: BoxDecoration(
                    color: _getColor(count),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(int count) {
    if (count == 0) return Colors.white.withValues(alpha: 0.05);
    if (count < 2) return ZynkColors.primary.withValues(alpha: 0.2);
    if (count < 5) return ZynkColors.primary.withValues(alpha: 0.5);
    if (count < 10) return ZynkColors.primary.withValues(alpha: 0.8);
    return ZynkColors.primary;
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: const TextStyle(color: ZynkColors.darkMuted, fontSize: 10)),
          const SizedBox(width: 4),
        ],
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      ],
    );
  }
}
