import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/user/screens/user_event_details_screen.dart';

class UserEventCard extends StatelessWidget {
  final Event event;

  const UserEventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final String? coverImage =
        event.imageUrls.isNotEmpty ? event.imageUrls.first : null;
    final catColor = ZynkColors.forCategory(event.category.name);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => UserEventDetailsScreen(event: event)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder,
          ),
          boxShadow: dark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover Image ──────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              child: coverImage != null
                  ? Image.network(
                      coverImage,
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(catColor),
                    )
                  : _imagePlaceholder(catColor),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Category + Approval Status ────────
                  Row(
                    children: [
                      CategoryBadge(event.category.name),
                      const Spacer(),
                      if (!event.isApproved)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ZynkColors.warning.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color:
                                    ZynkColors.warning.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'PENDING',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: ZynkColors.warning,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── Title ─────────────────────────────
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color:
                          dark ? ZynkColors.darkText : ZynkColors.lightText,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Date & Venue ──────────────────────
                  _infoRow(
                    icon: Icons.calendar_today_rounded,
                    text: DateFormat('EEE, MMM dd • hh:mm a')
                        .format(event.date),
                    color: catColor,
                    dark: dark,
                  ),
                  const SizedBox(height: 6),
                  _infoRow(
                    icon: Icons.location_on_rounded,
                    text: event.venue,
                    color: catColor,
                    dark: dark,
                  ),

                  const SizedBox(height: 12),

                  // ── Footer ─────────────────────────────
                  Row(
                    children: [
                      Icon(Icons.people_rounded,
                          size: 14,
                          color: dark
                              ? ZynkColors.darkMuted
                              : ZynkColors.lightMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${event.registeredUsers.length} registered',
                        style: TextStyle(
                          fontSize: 12,
                          color: dark
                              ? ZynkColors.darkMuted
                              : ZynkColors.lightMuted,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'View Details',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: catColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded,
                                size: 13, color: catColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String text,
    required Color color,
    required bool dark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder(Color catColor) {
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: ZynkGradients.forCategory(
          catColor == ZynkColors.catTech
              ? 'tech'
              : catColor == ZynkColors.catCultural
                  ? 'cultural'
                  : catColor == ZynkColors.catSports
                      ? 'sports'
                      : catColor == ZynkColors.catWorkshop
                          ? 'workshop'
                          : 'seminar',
        ),
      ),
      child: const Icon(Icons.event_rounded,
          size: 48, color: Colors.white24),
    );
  }
}