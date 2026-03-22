import 'package:flutter/material.dart';
import '../../../theme.dart';
import 'home_screen.dart';

class DoneScreen extends StatelessWidget {
  final int sortedCount;
  final List<String> names; // [up, down, left, right]

  const DoneScreen({
    super.key,
    required this.sortedCount,
    required this.names,
  });

  static const _arrows = ['↑', '↓', '←', '→'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FotoColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FotoSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(
                  color: FotoColors.upBg,
                  borderRadius: FotoRadius.card,
                ),
                child: const Icon(Icons.check_outlined,
                    color: FotoColors.up, size: 24),
              ),

              const SizedBox(height: FotoSpacing.lg),
              Text('$sortedCount photo${sortedCount != 1 ? 's' : ''} sorted',
                  style: FotoText.display),
              const SizedBox(height: FotoSpacing.xs),
              const Text('Moved into your folders.', style: FotoText.caption),

              const SizedBox(height: FotoSpacing.xl),
              const Divider(color: FotoColors.divider),
              const SizedBox(height: FotoSpacing.md),

              // Per-folder breakdown
              ...List.generate(4, (i) => Padding(
                padding: const EdgeInsets.only(bottom: FotoSpacing.sm),
                child: Row(children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: FotoColors.dirs[i],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: FotoSpacing.sm),
                  Text(_arrows[i],
                      style: TextStyle(
                          color: FotoColors.dirs[i],
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: FotoSpacing.xs),
                  Expanded(
                    child: Text(names[i], style: FotoText.body),
                  ),
                ]),
              )),

              const SizedBox(height: FotoSpacing.xl),

              GestureDetector(
                onTap: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (_) => false,
                ),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: FotoColors.textPrimary,
                    borderRadius: FotoRadius.button,
                  ),
                  child: Center(
                    child: Text('Back to Home',
                        style: FotoText.body.copyWith(
                            color: FotoColors.background,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
