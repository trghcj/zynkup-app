import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({super.key});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  bool _loading = false;

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1)); // Mock load
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ZynkBackground(
        child: RefreshIndicator(
          color: ZynkColors.gold,
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 22, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Campus Feed',
                        style: TextStyle(
                          color: ZynkColors.offWhite,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Stay updated with what\'s happening on campus.',
                        style: TextStyle(color: ZynkColors.darkMuted),
                      ),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: ZynkColors.gold),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _FeedPostCard(index: index),
                    childCount: 5,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedPostCard extends StatelessWidget {
  final int index;
  const _FeedPostCard({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        gradient: ZynkGradients.cardSurface,
        borderRadius: BorderRadius.circular(ZynkRadius.lg),
        border: Border.all(color: ZynkColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage('https://api.dicebear.com/7.x/avataaars/png?seed=User$index'),
                  backgroundColor: ZynkColors.darkSurface2,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student $index',
                        style: const TextStyle(
                          color: ZynkColors.offWhite,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '2 hours ago',
                        style: TextStyle(
                          color: ZynkColors.darkMuted.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz_rounded, color: ZynkColors.darkMuted),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          
          // Image Content (Mocking alternate posts having images)
          if (index % 2 == 0)
            Image.network(
              'https://picsum.photos/seed/zynkup$index/600/400',
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            
          // Text Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'This is a sample post about campus life. Just finished the hackathon and it was amazing! 🚀',
              style: const TextStyle(
                color: ZynkColors.offWhite,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          
          // Action Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                _ActionIcon(icon: Icons.favorite_border_rounded, label: '${12 + index * 5}'),
                const SizedBox(width: 24),
                const _ActionIcon(icon: Icons.chat_bubble_outline_rounded, label: 'Reply'),
                const Spacer(),
                const _ActionIcon(icon: Icons.share_rounded, label: 'Share'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ActionIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: ZynkColors.darkMuted, size: 20),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: ZynkColors.darkMuted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
