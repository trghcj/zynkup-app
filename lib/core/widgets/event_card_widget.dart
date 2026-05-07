import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/events/models/event_model.dart';

class EventCardWidget extends StatelessWidget {
  const EventCardWidget({
    super.key,
    required this.event,
    required this.onTap,
    this.compact = false,
  });

  final Event event;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final category = event.category.name;
    final joined = event.attendeeCount > 0
        ? event.attendeeCount
        : event.registeredUsers.length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: ZynkColors.darkSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ZynkColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Banner(event: event, compact: compact),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CategoryBadge(category),
                      const Spacer(),
                      Text(
                        DateFormat('MMM d').format(event.date),
                        style: const TextStyle(
                          color: ZynkColors.darkMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ZynkColors.darkText,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: ZynkColors.darkMuted,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.venue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ZynkColors.darkMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$joined student${joined == 1 ? '' : 's'} joined',
                    style: const TextStyle(
                      color: ZynkColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.event, required this.compact});

  final Event event;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 86.0 : 136.0;
    final image = event.imageUrls.isNotEmpty ? event.imageUrls.first : null;
    if (image == null || image.isEmpty) {
      return _GradientBanner(event: event, height: height);
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Image.network(
        image,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _GradientBanner(event: event, height: height),
      ),
    );
  }
}

class _GradientBanner extends StatelessWidget {
  const _GradientBanner({required this.event, required this.height});

  final Event event;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: ZynkGradients.forCategory(event.category.name),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(
            Icons.local_activity_rounded,
            color: Colors.white.withValues(alpha: 0.86),
            size: 30,
          ),
        ),
      ),
    );
  }
}
