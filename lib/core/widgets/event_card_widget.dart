import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/events/models/event_model.dart';

class EventCardWidget extends StatefulWidget {
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
  State<EventCardWidget> createState() => _EventCardWidgetState();
}

class _EventCardWidgetState extends State<EventCardWidget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final category = widget.event.category.name;
    final joined = widget.event.attendeeCount > 0
        ? widget.event.attendeeCount
        : widget.event.registeredUsers.length;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: _hovering
              // ignore: deprecated_member_use
              ? (Matrix4.identity()..scale(1.02))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: ZynkGradients.cardSurface,
            borderRadius: BorderRadius.circular(ZynkRadius.xl),
            border: Border.all(
              color: _hovering
                  ? ZynkColors.gold.withValues(alpha: 0.3)
                  : ZynkColors.darkBorder.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovering ? 0.28 : 0.18),
                blurRadius: _hovering ? 32 : 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: ZynkColors.deepOlive.withValues(alpha: 0.06),
                blurRadius: 48,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Banner(event: widget.event, compact: widget.compact),
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
                          DateFormat('MMM d').format(widget.event.date),
                          style: TextStyle(
                            color: ZynkColors.darkMuted.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ZynkColors.darkText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: ZynkColors.warmBrown.withValues(alpha: 0.7),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.event.venue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ZynkColors.darkMuted.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: ZynkColors.gold,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: ZynkColors.gold.withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$joined student${joined == 1 ? '' : 's'} joined',
                          style: const TextStyle(
                            color: ZynkColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
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
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: Stack(
        children: [
          Image.network(
            image,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _GradientBanner(event: event, height: height),
          ),
          // Bottom fade for text readability
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: height * 0.5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    ZynkColors.darkSurface.withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ],
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Stack(
        children: [
          // Subtle pattern overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(
                Icons.local_activity_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
