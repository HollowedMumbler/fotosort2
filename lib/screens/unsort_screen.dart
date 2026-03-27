import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../file_service.dart';
import '../theme.dart';

const _kWhite85 = Color(0xD9FFFFFF);
const _kWhite60 = Color(0x99FFFFFF);
const _kBlack35 = Color(0x59000000);

class UnsortScreen extends StatefulWidget {
  final List<String> folderNames;
  final String sourceDirectory;

  const UnsortScreen({
    super.key,
    required this.folderNames,
    required this.sourceDirectory,
  });

  @override
  State<UnsortScreen> createState() => _UnsortScreenState();
}

class _UnsortScreenState extends State<UnsortScreen> {

  String? _fromFolder;
  List<String> _paths = [];
  int _index      = 0;
  int _movedCount = 0;

  late final List<String> _destNames;

  final _dragDelta = ValueNotifier<Offset>(Offset.zero);
  final _hintIndex = ValueNotifier<int?>(null);

  Offset _dragStart = Offset.zero;
  bool _dragging    = false;

  // FIX: hard lock — set before setState, released inside setState
  bool _locked = false;

  final Map<int, Widget> _imageCache = {};

  static const double _threshold   = 70.0;
  static const int _preloadAhead   = 4;
  static const int _maxCacheSize   = 8;

  @override
  void initState() {
    super.initState();
    _destNames = [...widget.folderNames, 'Original'];
  }

  @override
  void dispose() {
    _dragDelta.dispose();
    _hintIndex.dispose();
    super.dispose();
  }

  Widget _buildImageWidget(String path) => Image.file(
        File(path),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_outlined,
              color: FotoColors.textHint, size: 48),
        ),
      );

  void _preloadRange(int from, int count) {
    for (int i = from; i < from + count && i < _paths.length; i++) {
      if (_imageCache.containsKey(i)) continue;
      _imageCache[i] = _buildImageWidget(_paths[i]);
    }
    // FIX: cap cache size to avoid memory bloat
    if (_imageCache.length > _maxCacheSize) {
      final keys = _imageCache.keys.toList()..sort();
      for (final k in keys) {
        if (k < _index - 1) {
          _imageCache.remove(k);
          if (_imageCache.length <= _maxCacheSize) break;
        }
      }
    }
  }

  Future<void> _selectFromFolder(String folderName) async {
    final folderPath = p.join(widget.sourceDirectory, folderName);
    final images = await FileService.scanFolder(folderPath);
    _imageCache.clear();
    setState(() {
      _fromFolder = folderName;
      _paths      = images;
      _index      = 0;
      _movedCount = 0;
      _locked     = false;
    });
    // FIX: preload from index 0 immediately
    _preloadRange(0, _preloadAhead);
    if (images.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No photos in "$folderName".',
            style: FotoText.body.copyWith(color: Colors.white)),
        backgroundColor: FotoColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: FotoRadius.button),
      ));
    }
  }

  void _onPanStart(DragStartDetails d) {
    if (_locked) return;
    _dragStart = d.globalPosition;
    _dragging  = true;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_dragging || _locked) return;
    final delta = d.globalPosition - _dragStart;
    int? hint;
    if (delta.distance > 20) {
      if (delta.dx.abs() > delta.dy.abs()) {
        hint = delta.dx > 0 ? 3 : 2;
      } else {
        hint = delta.dy > 0 ? 1 : 0;
      }
    }
    _dragDelta.value = delta;
    _hintIndex.value = hint;
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_dragging || _locked) return;
    _dragging = false;
    final delta    = _dragDelta.value;
    final hint     = _hintIndex.value;
    final velocity = d.velocity.pixelsPerSecond.distance;
    if (hint != null && (delta.distance >= _threshold || velocity > 800)) {
      _commitMove(hint);
    } else {
      _dragDelta.value = Offset.zero;
      _hintIndex.value = null;
    }
  }

  void _commitMove(int destIndex) {
    // FIX: lock FIRST before anything else
    if (_locked || _index >= _paths.length) return;
    _locked = true;

    final imagePath = _paths[_index];
    final destDir = destIndex < 4
        ? p.join(widget.sourceDirectory, widget.folderNames[destIndex])
        : widget.sourceDirectory;

    FileService.moveFile(imagePath, destDir);

    // FIX: reset notifiers immediately
    _dragDelta.value = Offset.zero;
    _hintIndex.value = null;

    // FIX: preload next before advancing
    final nextIndex = _index + 1;
    _preloadRange(nextIndex, _preloadAhead);

    _imageCache.remove(_index);

    setState(() {
      _index      = nextIndex;
      _movedCount = _movedCount + 1;
      // FIX: unlock inside setState — atomic with index update
      _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FotoColors.background,
      appBar: AppBar(title: const Text('Unsort')),
      body: _fromFolder == null ? _folderPicker() : _sorter(),
    );
  }

  Widget _folderPicker() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(FotoSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(FotoSpacing.md),
              decoration: BoxDecoration(
                color: FotoColors.infoBannerBg,
                borderRadius: FotoRadius.card,
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded,
                    color: FotoColors.infoBannerText, size: 16),
                const SizedBox(width: FotoSpacing.sm),
                Expanded(
                  child: Text(
                    'Pick a sorted folder to swipe photos out of.',
                    style: FotoText.caption.copyWith(color: FotoColors.infoBannerText),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: FotoSpacing.lg),
            Text('SELECT A FOLDER',
                style: FotoText.label.copyWith(letterSpacing: 0.8)),
            const SizedBox(height: FotoSpacing.md),
            ...List.generate(widget.folderNames.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: FotoSpacing.sm),
              child: GestureDetector(
                onTap: () => _selectFromFolder(widget.folderNames[i]),
                child: Container(
                  padding: const EdgeInsets.all(FotoSpacing.md),
                  decoration: BoxDecoration(
                    color: FotoColors.surface,
                    borderRadius: FotoRadius.card,
                    boxShadow: FotoShadow.card,
                    border: Border(left: BorderSide(
                        color: FotoColors.directions[i], width: 3)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: FotoColors.directionBgs[i],
                        borderRadius: BorderRadius.circular(FotoRadius.sm),
                      ),
                      child: Center(child: Text(
                        ['↑','↓','←','→'][i],
                        style: TextStyle(color: FotoColors.directions[i],
                            fontSize: 16, fontWeight: FontWeight.w500),
                      )),
                    ),
                    const SizedBox(width: FotoSpacing.md),
                    Expanded(child: Text(widget.folderNames[i],
                        style: FotoText.body.copyWith(fontWeight: FontWeight.w500))),
                    const Icon(Icons.chevron_right_outlined,
                        color: FotoColors.textHint, size: 18),
                  ]),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _sorter() {
    final remaining = _paths.length - _index;

    if (remaining <= 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(FotoSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: FotoColors.up, size: 48),
            const SizedBox(height: FotoSpacing.md),
            Text('$_movedCount photo${_movedCount != 1 ? 's' : ''} moved',
                style: FotoText.display),
            const SizedBox(height: FotoSpacing.xl),
            GestureDetector(
              onTap: () {
                _imageCache.clear();
                setState(() {
                  _fromFolder = null;
                  _paths      = [];
                  _index      = 0;
                  _locked     = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: FotoSpacing.lg, vertical: FotoSpacing.md),
                decoration: BoxDecoration(
                  color: FotoColors.surfaceAlt,
                  borderRadius: FotoRadius.button,
                ),
                child: Text('Pick another folder', style: FotoText.body),
              ),
            ),
          ]),
        ),
      );
    }

    // FIX: fallback to building on the spot — no blank flash on cache miss
    final current = _imageCache[_index] ?? _buildImageWidget(_paths[_index]);

    return Stack(children: [
      // Photo
      GestureDetector(
        onPanStart:  _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd:    _onPanEnd,
        child: _UnsortDragLayer(
          dragDelta: _dragDelta,
          child: current,
        ),
      ),

      // Hint badge
      _UnsortHintOverlay(
        dragDelta:  _dragDelta,
        hintIndex:  _hintIndex,
        threshold:  _threshold,
        destNames:  _destNames,
      ),

      // Top bar
      Positioned(
        top: 0, left: 0, right: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                FotoSpacing.md, FotoSpacing.sm, FotoSpacing.md, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () {
                  _imageCache.clear();
                  setState(() {
                    _fromFolder = null;
                    _paths      = [];
                    _index      = 0;
                    _locked     = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(FotoSpacing.sm),
                  decoration: BoxDecoration(
                    color: _kBlack35, borderRadius: FotoRadius.button),
                  child: const Icon(Icons.close_outlined, color: _kWhite85, size: 18),
                ),
              ),
              const SizedBox(width: FotoSpacing.md),
              Expanded(
                child: Text('$_fromFolder  •  $remaining remaining',
                    style: const TextStyle(color: _kWhite60, fontSize: 11)),
              ),
            ]),
          ),
        ),
      ),

      // Bottom controls
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                FotoSpacing.md, 0, FotoSpacing.md, FotoSpacing.md),
            child: _UnsortBottomControls(
              folderNames: widget.folderNames,
              hintIndex:   _hintIndex,
              onTap:       _commitMove,
            ),
          ),
        ),
      ),
    ]);
  }
}

// ── Drag layer ────────────────────────────────────────────────────────────────
class _UnsortDragLayer extends StatelessWidget {
  final ValueNotifier<Offset> dragDelta;
  final Widget child;

  const _UnsortDragLayer({required this.dragDelta, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Offset>(
      valueListenable: dragDelta,
      builder: (_, offset, __) => Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: offset.dx / 900,
          child: SizedBox.expand(
            child: ColoredBox(color: Colors.black, child: child),
          ),
        ),
      ),
    );
  }
}

// ── Hint overlay ──────────────────────────────────────────────────────────────
class _UnsortHintOverlay extends StatelessWidget {
  final ValueNotifier<Offset> dragDelta;
  final ValueNotifier<int?> hintIndex;
  final double threshold;
  final List<String> destNames;

  const _UnsortHintOverlay({
    required this.dragDelta, required this.hintIndex,
    required this.threshold, required this.destNames,
  });

  @override
  Widget build(BuildContext context) {
    // FIX: single ListenableBuilder on both notifiers — no nested teardown
    return ListenableBuilder(
      listenable: Listenable.merge([hintIndex, dragDelta]),
      builder: (_, __) {
        final idx = hintIndex.value;
        if (idx == null) return const SizedBox.shrink();
        final delta   = dragDelta.value;
        final color   = idx < 4 ? FotoColors.directions[idx] : FotoColors.textSecondary;
        final opacity = (delta.distance / threshold).clamp(0.0, 1.0);
        return Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: FotoSpacing.md, vertical: FotoSpacing.sm),
                  decoration: BoxDecoration(
                    color: color, borderRadius: FotoRadius.button,
                    boxShadow: FotoShadow.elevated,
                  ),
                  child: Text(
                    destNames[idx].toUpperCase(),
                    style: const TextStyle(color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Bottom controls ───────────────────────────────────────────────────────────
class _UnsortBottomControls extends StatelessWidget {
  final List<String> folderNames;
  final ValueNotifier<int?> hintIndex;
  final void Function(int) onTap;

  const _UnsortBottomControls({
    required this.folderNames, required this.hintIndex, required this.onTap,
  });

  static const _icons = [
    Icons.arrow_upward_outlined, Icons.arrow_downward_outlined,
    Icons.arrow_back_outlined,   Icons.arrow_forward_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: FotoSpacing.md, vertical: FotoSpacing.sm),
        decoration: BoxDecoration(
          color: const Color(0xE1F7F5FB),
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(FotoRadius.xl)),
          boxShadow: FotoShadow.elevated,
        ),
        child: ValueListenableBuilder<int?>(
          valueListenable: hintIndex,
          builder: (_, active, __) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) => GestureDetector(
              onTap: () => onTap(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: FotoSpacing.sm, vertical: FotoSpacing.xs),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_icons[i],
                      color: active == i
                          ? FotoColors.directions[i]
                          : FotoColors.textSecondary,
                      size: 20),
                  const SizedBox(height: FotoSpacing.xs),
                  Text(folderNames[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: active == i
                            ? FotoColors.directions[i]
                            : FotoColors.textHint,
                      ),
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                ]),
              ),
            )),
          ),
        ),
      ),
      GestureDetector(
        onTap: () => onTap(4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: FotoSpacing.md),
          decoration: const BoxDecoration(
            color: FotoColors.surfaceAlt,
            borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(FotoRadius.xl)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.undo_outlined,
                color: FotoColors.textSecondary, size: 16),
            const SizedBox(width: FotoSpacing.sm),
            Text('Return to original folder',
                style: FotoText.caption.copyWith(fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    ]);
  }
}