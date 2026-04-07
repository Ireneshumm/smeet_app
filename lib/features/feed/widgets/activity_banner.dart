import 'package:flutter/material.dart';

class ActivityBanner extends StatelessWidget {
  final int incomingLikes;
  final int todayGames;
  final VoidCallback? onTapLikes;
  final VoidCallback? onTapGames;

  const ActivityBanner({
    super.key,
    this.incomingLikes = 0,
    this.todayGames = 0,
    this.onTapLikes,
    this.onTapGames,
  });

  @override
  Widget build(BuildContext context) {
    if (incomingLikes <= 0 && todayGames <= 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (incomingLikes > 0) ...[
              Expanded(
                child: GestureDetector(
                  onTap: onTapLikes,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 90),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6C63FF),
                          const Color(0xFF6C63FF).withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '❤️',
                          style: TextStyle(fontSize: 24),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          incomingLikes == 1
                              ? '1 person wants to play with you 🎾'
                              : '$incomingLikes people want to play with you 🎾',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap to connect',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (incomingLikes > 0 && todayGames > 0)
              const SizedBox(width: 10),
            if (todayGames > 0) ...[
              Expanded(
                child: GestureDetector(
                  onTap: onTapGames,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 90),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF11998E),
                          Color(0xFF38EF7D),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '⚡',
                          style: TextStyle(fontSize: 24),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          todayGames == 1
                              ? '1 game near you today'
                              : '$todayGames games near you today',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Find a game →',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
