// lib/features/user/screens/user_event_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/events/models/event_model.dart';

class UserEventDetailsScreen extends StatefulWidget {
  final Event event;
  const UserEventDetailsScreen({super.key, required this.event});

  @override
  State<UserEventDetailsScreen> createState() => _UserEventDetailsScreenState();
}

class _UserEventDetailsScreenState extends State<UserEventDetailsScreen> {
  bool _registering = false;
  bool _registered  = false;

  Future<void> _register() async {
    setState(() => _registering = true);
    try {
      final success = await ApiService.registerEvent(int.parse(widget.event.id));
      if (!mounted) return;
      if (success) {
        setState(() => _registered = true);
        _snack('Registered successfully! 🎉', ZynkColors.success);
      }
    } on ApiException catch (e) {
      _snack(e.message, ZynkColors.error);
    } catch (_) {
      _snack('Registration failed. Try again.', ZynkColors.error);
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark  = Theme.of(context).brightness == Brightness.dark;
    final event = widget.event;
    final cat   = event.category.name;
    final isUpcoming = event.date.isAfter(DateTime.now());

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Hero header ──────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: dark ? ZynkColors.darkSurface : ZynkColors.lightBg,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                // Gradient banner using category colour
                Container(
                  decoration: BoxDecoration(
                    gradient: ZynkGradients.forCategory(cat),
                  ),
                ),
                // Decorative pattern
                Positioned(
                  right: -30, top: -30,
                  child: Container(
                    width: 180, height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.07),
                    ),
                  ),
                ),
                // Event title overlay
                Positioned(
                  left: 20, right: 20, bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CategoryBadge(cat),
                      const SizedBox(height: 8),
                      Text(event.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          )),
                    ],
                  ),
                ),
              ]),
            ),
          ),

          // ── Body ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Status badge ──────────────────────────
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: (isUpcoming
                                ? ZynkColors.success
                                : ZynkColors.lightMuted)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (isUpcoming
                                  ? ZynkColors.success
                                  : ZynkColors.lightMuted)
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Row(children: [
                        Icon(
                          isUpcoming
                              ? Icons.schedule_rounded
                              : Icons.history_rounded,
                          size: 13,
                          color: isUpcoming
                              ? ZynkColors.success
                              : ZynkColors.lightMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isUpcoming ? 'Upcoming' : 'Past Event',
                          style: TextStyle(
                            color: isUpcoming
                                ? ZynkColors.success
                                : ZynkColors.lightMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ]),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── Description ───────────────────────────
                  Text('About this Event',
                      style: TextStyle(
                        color: dark ? ZynkColors.darkText : ZynkColors.lightText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 8),
                  Text(event.description,
                      style: TextStyle(
                        color: dark
                            ? ZynkColors.darkMuted
                            : ZynkColors.lightMuted,
                        fontSize: 15,
                        height: 1.65,
                      )),

                  const SizedBox(height: 24),

                  // ── Info cards ────────────────────────────
                  _InfoCard(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date & Time',
                    value: DateFormat('EEE, MMM dd yyyy • hh:mm a')
                        .format(event.date),
                    color: ZynkColors.catTech,
                    dark: dark,
                  ),
                  const SizedBox(height: 10),
                  _InfoCard(
                    icon: Icons.location_on_rounded,
                    label: 'Venue',
                    value: event.venue,
                    color: ZynkColors.primary,
                    dark: dark,
                  ),
                  const SizedBox(height: 10),
                  _InfoCard(
                    icon: Icons.category_rounded,
                    label: 'Category',
                    value: cat.toUpperCase(),
                    color: ZynkColors.forCategory(cat),
                    dark: dark,
                  ),

                  const SizedBox(height: 32),

                  // ── Register button ───────────────────────
                  if (isUpcoming)
                    _registered
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: ZynkColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: ZynkColors.success.withOpacity(0.3)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: ZynkColors.success),
                                SizedBox(width: 8),
                                Text('You are registered!',
                                    style: TextStyle(
                                      color: ZynkColors.success,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    )),
                              ],
                            ),
                          )
                        : ZynkButton(
                            label: 'Register for this Event',
                            icon: Icons.how_to_reg_rounded,
                            onTap: _register,
                            isLoading: _registering,
                          )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: dark
                            ? ZynkColors.darkSurface2
                            : ZynkColors.lightSurf2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: dark
                                ? ZynkColors.darkBorder
                                : ZynkColors.lightBorder),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy_rounded,
                              color: ZynkColors.lightMuted),
                          SizedBox(width: 8),
                          Text('This event has ended',
                              style: TextStyle(
                                color: ZynkColors.lightMuted,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final bool dark;
  const _InfoCard({required this.icon, required this.label,
    required this.value, required this.color, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                  color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                )),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                  color: dark ? ZynkColors.darkText : ZynkColors.lightText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                )),
          ],
        )),
      ]),
    );
  }
}