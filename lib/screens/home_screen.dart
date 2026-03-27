import 'package:flutter/material.dart';
import '../theme.dart';
import 'setup_screen.dart';
import 'folder_picker.dart';
import 'unsort_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _openUnsort(BuildContext context) async {
    final result = await Navigator.of(context).push<(String, List<String>)>(
      MaterialPageRoute(
          builder: (_) => const FolderPicker(showImagePreview: false)),
    );
    if (result == null || !context.mounted) return;

    final names = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => const _NameOnlySetup()),
    );
    if (names == null || !context.mounted) return;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => UnsortScreen(sourceDir: result.$1, names: names),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FotoColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: FotoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: FotoSpacing.xxl),
              const Text('FotoSort', style: FotoText.display),
              const SizedBox(height: FotoSpacing.xs),
              const Text('Your personal photo organizer.',
                  style: FotoText.caption),
              const SizedBox(height: FotoSpacing.xxl),
              const Text('WHAT DO YOU WANT TO DO?', style: kSectionLabel),
              const SizedBox(height: FotoSpacing.sm),
              _ModeCard(
                icon: Icons.swipe_rounded,
                title: 'Sort Photos',
                description: 'Swipe photos into folders one by one.',
                bgColor: FotoColors.rightBg,
                iconColor: FotoColors.right,
                badge: 'START HERE',
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SetupScreen())),
              ),
              const SizedBox(height: FotoSpacing.sm),
              _ModeCard(
                icon: Icons.undo_rounded,
                title: 'Unsort / Move Back',
                description: 'Move already-sorted photos to a different folder.',
                bgColor: FotoColors.leftBg,
                iconColor: FotoColors.left,
                onTap: () => _openUnsort(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Name-only setup for unsort ────────────────────────────────────────────────

class _NameOnlySetup extends StatefulWidget {
  const _NameOnlySetup();

  @override
  State<_NameOnlySetup> createState() => _NameOnlySetupState();
}

class _NameOnlySetupState extends State<_NameOnlySetup> {
  final _names = [
    TextEditingController(text: 'Keep'),
    TextEditingController(text: 'Delete'),
    TextEditingController(text: 'Maybe'),
    TextEditingController(text: 'Favorite'),
  ];

  static const _arrows = ['↑', '↓', '←', '→'];

  @override
  void dispose() {
    for (final c in _names) c.dispose();
    super.dispose();
  }

  void _confirm() {
    for (int i = 0; i < 4; i++) {
      if (_names[i].text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_arrows[i]} folder name is empty.'),
          backgroundColor: FotoColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: FotoRadius.button),
        ));
        return;
      }
    }
    Navigator.of(context).pop(_names.map((c) => c.text.trim()).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FotoColors.background,
      appBar: AppBar(title: const Text('Your Folder Names')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FotoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(FotoSpacing.md),
                decoration: BoxDecoration(
                  color: FotoColors.surfaceAlt,
                  borderRadius: FotoRadius.card,
                ),
                child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Icon(Icons.info_outline_rounded,
                      color: FotoColors.textSecondary, size: 16),
                  SizedBox(width: FotoSpacing.sm),
                  Expanded(
                    child: Text(
                      'Enter the same folder names you used when sorting.',
                      style: FotoText.caption,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: FotoSpacing.lg),

              ...List.generate(4, (i) => Padding(
                padding: const EdgeInsets.only(bottom: FotoSpacing.sm),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: FotoColors.surfaceAlt,
                      borderRadius: FotoRadius.chip,
                    ),
                    child: Center(
                      child: Text(_arrows[i],
                          style: const TextStyle(
                              color: FotoColors.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: FotoSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _names[i],
                      style: FotoText.body,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: FotoColors.surfaceAlt,
                        border: OutlineInputBorder(
                            borderRadius: FotoRadius.button,
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: FotoRadius.button,
                            borderSide: const BorderSide(
                                color: FotoColors.textSecondary, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: FotoSpacing.md,
                            vertical: FotoSpacing.sm),
                      ),
                    ),
                  ),
                ]),
              )),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FotoColors.textPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: FotoRadius.card),
                    elevation: 0,
                  ),
                  child: const Text('Continue', style: FotoText.bodyBold),
                ),
              ),
              const SizedBox(height: FotoSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mode card ──────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color bgColor;
  final Color iconColor;
  final String? badge;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(FotoSpacing.md),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: FotoRadius.card,
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: FotoRadius.card,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: FotoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(title, style: FotoText.bodyBold),
                  if (badge != null) ...[
                    const SizedBox(width: FotoSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.2),
                        borderRadius: FotoRadius.chip,
                      ),
                      child: Text(badge!,
                          style: TextStyle(
                              color: iconColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
                const SizedBox(height: FotoSpacing.xs),
                Text(description,
                    style: FotoText.caption),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: FotoColors.textHint, size: 14),
        ]),
      ),
    );
  }
}