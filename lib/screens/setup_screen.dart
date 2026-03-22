import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/file_service.dart';
import 'folder_picker.dart';
import 'sort_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String? _sourceDir;
  String? _destDir;
  List<String> _images = [];

  final _names = [
    TextEditingController(text: 'Keep'),
    TextEditingController(text: 'Delete'),
    TextEditingController(text: 'Maybe'),
    TextEditingController(text: 'Favorite'),
  ];

  static const _arrows = ['↑', '↓', '←', '→'];
  static const _hints  = ['Keep, Best...', 'Delete, Trash...', 'Maybe, Later...', 'Favorite, Share...'];

  @override
  void dispose() {
    for (final c in _names) c.dispose();
    super.dispose();
  }

  Future<void> _pickSource() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const FolderPicker()),
    );
    if (path == null) return;
    final images = await FileService.scanFolder(path);
    setState(() {
      _sourceDir = path;
      _images    = images;
    });
    if (images.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('No photos found in that folder.'),
        backgroundColor: FotoColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: FotoRadius.button),
      ));
    }
  }

  Future<void> _pickDest() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const FolderPicker()),
    );
    if (path == null) return;
    setState(() => _destDir = path);
  }

  void _start() {
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
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SortScreen(
        images:    _images,
        sourceDir: _sourceDir!,
        destDir:   _destDir,
        names:     _names.map((c) => c.text.trim()).toList(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ready   = _images.isNotEmpty;
    final destSet = _destDir != null;

    return Scaffold(
      backgroundColor: FotoColors.background,
      appBar: AppBar(title: const Text('Set Up')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(FotoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Source folder ─────────────────────────────────────────────
              const Text('SOURCE FOLDER',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: FotoColors.textHint, letterSpacing: 0.8)),
              const SizedBox(height: FotoSpacing.sm),
              GestureDetector(
                onTap: _pickSource,
                child: Container(
                  padding: const EdgeInsets.all(FotoSpacing.md),
                  decoration: BoxDecoration(
                    color: ready ? FotoColors.upBg : FotoColors.surfaceAlt,
                    borderRadius: FotoRadius.card,
                  ),
                  child: Row(children: [
                    Icon(
                      ready ? Icons.photo_library_rounded : Icons.photo_library_outlined,
                      color: ready ? FotoColors.up : FotoColors.textSecondary,
                      size: 22,
                    ),
                    const SizedBox(width: FotoSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _sourceDir != null
                                ? _sourceDir!.split('/').last
                                : 'Choose a folder',
                            style: FotoText.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: ready
                                    ? FotoColors.textPrimary
                                    : FotoColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (ready)
                            Text('${_images.length} photos found',
                                style: FotoText.micro),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: FotoColors.textHint, size: 18),
                  ]),
                ),
              ),

              const SizedBox(height: FotoSpacing.lg),

              // ── Destination folder (optional) ─────────────────────────────
              Row(children: [
                const Expanded(
                  child: Text('DESTINATION FOLDER',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: FotoColors.textHint, letterSpacing: 0.8)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: FotoSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: FotoColors.surfaceAlt,
                    borderRadius: FotoRadius.chip,
                  ),
                  child: const Text('optional',
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w600,
                          color: FotoColors.textHint)),
                ),
              ]),
              const SizedBox(height: FotoSpacing.xs),
              Text(
                destSet
                    ? 'Sorted folders will be created here.'
                    : 'Defaults to same as source.',
                style: FotoText.caption,
              ),
              const SizedBox(height: FotoSpacing.sm),

              // Set destination button / tile
              if (!destSet)
                GestureDetector(
                  onTap: _pickDest,
                  child: Container(
                    padding: const EdgeInsets.all(FotoSpacing.md),
                    decoration: BoxDecoration(
                      color: FotoColors.surfaceAlt,
                      borderRadius: FotoRadius.card,
                    ),
                    child: Row(children: [
                      const Icon(Icons.folder_outlined,
                          color: FotoColors.textSecondary, size: 22),
                      const SizedBox(width: FotoSpacing.sm),
                      const Expanded(
                        child: Text('Set destination folder',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: FotoColors.textSecondary)),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: FotoColors.textHint, size: 18),
                    ]),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(FotoSpacing.md),
                  decoration: BoxDecoration(
                    color: FotoColors.surfaceAlt,
                    borderRadius: FotoRadius.card,
                  ),
                  child: Row(children: [
                    const Icon(Icons.folder_open_rounded,
                        color: FotoColors.textPrimary, size: 22),
                    const SizedBox(width: FotoSpacing.sm),
                    Expanded(
                      child: Text(
                        _destDir!.split('/').last,
                        style: FotoText.body.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _destDir = null),
                      child: const Icon(Icons.close_rounded,
                          color: FotoColors.textHint, size: 18),
                    ),
                  ]),
                ),

              const SizedBox(height: FotoSpacing.lg),

              // ── Swipe folder names ────────────────────────────────────────
              const Text('SWIPE FOLDERS',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: FotoColors.textHint, letterSpacing: 0.8)),
              const SizedBox(height: FotoSpacing.sm),

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
                            horizontal: FotoSpacing.md, vertical: FotoSpacing.sm),
                        hintText: _hints[i],
                        hintStyle: FotoText.body.copyWith(
                            color: FotoColors.textHint),
                      ),
                    ),
                  ),
                ]),
              )),

              const SizedBox(height: FotoSpacing.xl),

              // ── Start button ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: ready ? _start : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FotoColors.textPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: FotoColors.divider,
                    disabledForegroundColor: FotoColors.textSecondary,
                    shape: RoundedRectangleBorder(borderRadius: FotoRadius.card),
                    elevation: 0,
                  ),
                  child: Text(
                    ready ? 'Start Sorting →' : 'Select a folder first',
                    style: FotoText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: FotoSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
} 