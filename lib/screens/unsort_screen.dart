import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:path/path.dart' as p;
import '../theme.dart';
import '../shared.dart';
import '../services/file_service.dart';

class UnsortScreen extends StatefulWidget {
  final String sourceDir;
  final List<String> names; // [up, down, left, right]

  const UnsortScreen({
    super.key,
    required this.sourceDir,
    required this.names,
  });

  @override
  State<UnsortScreen> createState() => _UnsortScreenState();
}

class _UnsortScreenState extends State<UnsortScreen>
    with TickerProviderStateMixin {

  String? _fromFolder;
  List<String> _images = [];
  int  _index      = 0;
  int  _movedCount = 0;
  bool _locked     = false;
  bool _loading    = false;

  late final List<String> _destNames;
  late final List<String> _destLabels;

  final _drag    = ValueNotifier<Offset>(Offset.zero);
  final _hintIdx = ValueNotifier<int?>(null);

  Offset _dragStart = Offset.zero;
  bool   _dragging  = false;

  late final AnimationController _flyCtrl;
  late final AnimationController _snapCtrl;
  Offset _flyTarget = Offset.zero;

  Size _screenSize = const Size(400, 800);

  final Map<int, Widget> _cache = {};
  static const _preload   = 4;
  static const _cacheMax  = 8;
  static const _threshold = 70.0;

  static const _arrows = ['↑', '↓', '←', '→'];

  @override
  void initState() {
    super.initState();
    _destNames  = [...widget.names, 'Original'];
    _destLabels = [...widget.names.map((n) => n.toUpperCase()), 'ORIGINAL'];
    _flyCtrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _snapCtrl = AnimationController.unbounded(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenSize = MediaQuery.sizeOf(context);
  }

  @override
  void dispose() {
    _drag.dispose();
    _hintIdx.dispose();
    _flyCtrl.dispose();
    _snapCtrl.dispose();
    super.dispose();
  }

  // ── Reset to folder picker ─────────────────────────────────────────────────

  void _resetToPicker() {
    _cache.clear();
    setState(() {
      _fromFolder = null;
      _images     = [];
      _index      = 0;
      _locked     = false;
    });
  }

  // ── Folder selection ───────────────────────────────────────────────────────

  Future<void> _selectFolder(String name) async {
    setState(() => _loading = true);
    final images = await FileService.scanFolder(p.join(widget.sourceDir, name));
    _cache.clear();
    setState(() {
      _fromFolder = name;
      _images     = images;
      _index      = 0;
      _movedCount = 0;
      _locked     = false;
      _loading    = false;
    });
    _preloadFrom(0);
    if (images.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No photos in "$name".'),
        backgroundColor: FotoColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: FotoRadius.button),
      ));
    }
  }

  // ── Cache ──────────────────────────────────────────────────────────────────

  Widget _buildImg(int i) => Image.file(
        File(_images[i]),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_outlined,
              color: FotoColors.textHint, size: 48),
        ),
      );

  void _preloadFrom(int from) {
    for (int i = from; i < from + _preload && i < _images.length; i++) {
      _cache.putIfAbsent(i, () => _buildImg(i));
    }
    if (_cache.length > _cacheMax) {
      final keys = _cache.keys.toList()..sort();
      for (final k in keys) {
        if (k < _index - 1) {
          _cache.remove(k);
          if (_cache.length <= _cacheMax) break;
        }
      }
    }
  }

  // ── Gesture ────────────────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails d) {
    if (_locked) return;
    _snapCtrl.stop();
    _dragStart = d.globalPosition;
    _dragging  = true;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_dragging || _locked) return;
    final delta = d.globalPosition - _dragStart;
    int? hint;
    if (delta.distance > 15) {
      if (delta.dx.abs() > delta.dy.abs()) {
        hint = delta.dx > 0 ? 3 : 2;
      } else {
        hint = delta.dy > 0 ? 1 : 0;
      }
    }
    _drag.value    = delta;
    _hintIdx.value = hint;
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_dragging || _locked) return;
    _dragging = false;
    final speed = d.velocity.pixelsPerSecond.distance;
    final hint  = _hintIdx.value;
    if (hint != null && (_drag.value.distance >= _threshold || speed > 800)) {
      _commitWithAnimation(hint);
    } else {
      _snapBack(d.velocity.pixelsPerSecond);
    }
  }

  // ── Spring snap-back ───────────────────────────────────────────────────────

  void _snapBack(Offset velocity) {
    _hintIdx.value = null;
    final start = _drag.value;
    if (start == Offset.zero) return;

    final spring = SpringDescription.withDampingRatio(
      mass: 1.0, stiffness: 300.0, ratio: 0.7,
    );
    _snapCtrl.stop();
    _snapCtrl.value = 0;
    _snapCtrl.animateWith(DirectSpring(
      SpringSimulation(spring, start.dx, 0, velocity.dx * 0.1),
      SpringSimulation(spring, start.dy, 0, velocity.dy * 0.1),
      _drag,
    ));
  }

  // ── Fly-off ────────────────────────────────────────────────────────────────

  void _commitWithAnimation(int destIdx) {
    if (_locked) return;
    _locked = true;
    _hintIdx.value = null;

    _flyTarget = switch (destIdx) {
      0 => Offset(0, -_screenSize.height * 1.5),
      1 => Offset(0,  _screenSize.height * 1.5),
      2 => Offset(-_screenSize.width * 1.5, 0),
      _ => Offset( _screenSize.width * 1.5, 0),
    };

    _flyCtrl.value = 0;
    _flyCtrl.animateTo(1, curve: Curves.easeIn).then((_) {
      if (!mounted) return;
      _finishCommit(destIdx);
    });
  }

  void _finishCommit(int destIdx) {
    final destDir = destIdx < 4
        ? p.join(widget.sourceDir, widget.names[destIdx])
        : widget.sourceDir;

    FileService.moveFile(_images[_index], destDir);

    _cache.remove(_index);
    _drag.value    = Offset.zero;
    _flyCtrl.value = 0;
    _flyTarget     = Offset.zero;

    final next     = _index + 1;
    final newCount = _movedCount + 1;

    _preloadFrom(next);

    setState(() {
      _index      = next;
      _movedCount = newCount;
      _locked     = false;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fromFolder == null ? FotoColors.background : Colors.black,
      appBar: _fromFolder == null
          ? AppBar(title: const Text('Unsort'))
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              strokeWidth: 2, color: FotoColors.textSecondary))
          : _fromFolder == null
              ? _folderPicker()
              : _sorter(),
    );
  }

  // ── Folder picker ──────────────────────────────────────────────────────────

  Widget _folderPicker() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(FotoSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Neutral info banner — consistent with setup_screen
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
                  child: Text('Pick a sorted folder to swipe photos out of.',
                      style: FotoText.caption),
                ),
              ]),
            ),
            const SizedBox(height: FotoSpacing.lg),
            const Text('SELECT A FOLDER', style: kSectionLabel),
            const SizedBox(height: FotoSpacing.sm),
            ...List.generate(widget.names.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: FotoSpacing.sm),
              child: GestureDetector(
                onTap: () => _selectFolder(widget.names[i]),
                child: Container(
                  padding: const EdgeInsets.all(FotoSpacing.md),
                  decoration: BoxDecoration(
                    color: FotoColors.surfaceAlt,
                    borderRadius: FotoRadius.card,
                    border: Border(
                        left: BorderSide(color: FotoColors.dirs[i], width: 3)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: FotoColors.dirBgs[i],
                        borderRadius: FotoRadius.chip,
                      ),
                      child: Center(
                        child: Text(_arrows[i],
                            style: TextStyle(
                                color: FotoColors.dirs[i],
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: FotoSpacing.md),
                    Expanded(
                      child: Text(widget.names[i], style: FotoText.bodyBold),
                    ),
                    const Icon(Icons.chevron_right_rounded,
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

  // ── Sorter ─────────────────────────────────────────────────────────────────

  Widget _sorter() {
    final remaining = _images.length - _index;

    if (remaining <= 0) {
      return SafeArea(
        child: Center(
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
                onTap: _resetToPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: FotoSpacing.lg, vertical: FotoSpacing.md),
                  decoration: BoxDecoration(
                    color: FotoColors.surfaceAlt,
                    borderRadius: FotoRadius.button,
                  ),
                  child: const Text('Pick another folder', style: FotoText.body),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    final current = _cache[_index] ?? _buildImg(_index);
    final nextImg = _index + 1 < _images.length
        ? (_cache[_index + 1] ?? _buildImg(_index + 1))
        : null;

    return Stack(children: [

      // Next card
      if (nextImg != null)
        ListenableBuilder(
          listenable: Listenable.merge([_drag, _flyCtrl]),
          builder: (_, __) {
            final progress =
                ((_drag.value.distance / 200) + _flyCtrl.value).clamp(0.0, 1.0);
            return Transform.scale(
              scale: 0.95 + 0.05 * progress,
              child: Opacity(
                opacity: 0.5 + 0.5 * progress,
                child: SizedBox.expand(child: nextImg),
              ),
            );
          },
        ),

      // Current card — single Matrix4 transform
      GestureDetector(
        onPanStart:  _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd:    _onPanEnd,
        child: ListenableBuilder(
          listenable: Listenable.merge([_drag, _flyCtrl]),
          builder: (_, __) {
            final offset = _flyCtrl.value > 0 && _flyTarget != Offset.zero
                ? Offset.lerp(_drag.value, _flyTarget, _flyCtrl.value)!
                : _drag.value;
            return Transform(
              transform: Matrix4.identity()
                ..translate(offset.dx, offset.dy)
                ..rotateZ(offset.dx / 900),
              child: SizedBox.expand(child: current),
            );
          },
        ),
      ),

      // Hint badge
      _HintBadge(
        drag:      _drag,
        hintIdx:   _hintIdx,
        labels:    _destLabels,
        threshold: _threshold,
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
                onTap: _resetToPicker,
                child: Container(
                  padding: const EdgeInsets.all(FotoSpacing.sm),
                  decoration: const BoxDecoration(
                    color: Color(0x66000000),
                    borderRadius: FotoRadius.button,
                  ),
                  child: const Icon(Icons.close_outlined,
                      color: kWhite85, size: 18),
                ),
              ),
              const SizedBox(width: FotoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: _movedCount / _images.length,
                      minHeight: 2,
                      backgroundColor: kWhite15,
                      valueColor: const AlwaysStoppedAnimation(kWhite85),
                    ),
                    const SizedBox(height: FotoSpacing.xs),
                    Text('$_fromFolder  ·  $remaining remaining',
                        style: kMicroWhite50),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),

      // Bottom bar
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(FotoSpacing.md),
            child: _BottomBar(
              destNames: _destNames,
              hintIdx:   _hintIdx,
              onTap:     _commitWithAnimation,
            ),
          ),
        ),
      ),
    ]);
  }
}

// ── Hint badge ─────────────────────────────────────────────────────────────────

class _HintBadge extends StatelessWidget {
  final ValueNotifier<Offset> drag;
  final ValueNotifier<int?> hintIdx;
  final List<String> labels;
  final double threshold;

  const _HintBadge({
    required this.drag,
    required this.hintIdx,
    required this.labels,
    required this.threshold,
  });

  static const _alignments = [
    Alignment.topCenter,
    Alignment.bottomCenter,
    Alignment.centerLeft,
    Alignment.centerRight,
    Alignment.center,
  ];
  static const _paddings = [
    EdgeInsets.only(top: 100),
    EdgeInsets.only(bottom: 100),
    EdgeInsets.only(left: 24),
    EdgeInsets.only(right: 24),
    EdgeInsets.zero,
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([hintIdx, drag]),
      builder: (_, __) {
        final idx = hintIdx.value;
        if (idx == null) return const SizedBox.shrink();
        final opacity =
            ((drag.value.distance - 15) / (threshold - 15)).clamp(0.0, 1.0);
        final color = idx < 4 ? FotoColors.dirs[idx] : FotoColors.textSecondary;
        final i     = idx.clamp(0, 4);
        return Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Align(
                alignment: _alignments[i],
                child: Padding(
                  padding: _paddings[i],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: FotoSpacing.md, vertical: FotoSpacing.sm),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: FotoRadius.button,
                    ),
                    child: Text(labels[idx.clamp(0, labels.length - 1)],
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
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

// ── Bottom bar ─────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final List<String> destNames;
  final ValueNotifier<int?> hintIdx;
  final void Function(int) onTap;

  const _BottomBar({
    required this.destNames,
    required this.hintIdx,
    required this.onTap,
  });

  static const _icons = [
    Icons.arrow_upward_outlined,
    Icons.arrow_downward_outlined,
    Icons.arrow_back_outlined,
    Icons.arrow_forward_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: FotoSpacing.md, vertical: FotoSpacing.sm),
        decoration: BoxDecoration(
          color: const Color(0xE8F7F5FB),
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(FotoRadius.xl)),
          boxShadow: kElevatedShadow,
        ),
        child: ValueListenableBuilder<int?>(
          valueListenable: hintIdx,
          builder: (_, active, __) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) {
              final isActive = active == i;
              final color    = FotoColors.dirs[i];
              return GestureDetector(
                onTap: () => onTap(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: FotoSpacing.sm, vertical: FotoSpacing.xs),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_icons[i],
                        color: isActive ? color : FotoColors.textSecondary,
                        size: 20),
                    const SizedBox(height: FotoSpacing.xs),
                    Text(destNames[i],
                        style: TextStyle(
                            fontSize: 11,
                            color: isActive ? color : FotoColors.textHint),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                  ]),
                ),
              );
            }),
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
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.undo_outlined, color: FotoColors.textSecondary, size: 16),
            SizedBox(width: FotoSpacing.sm),
            Text('Return to original folder',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: FotoColors.textSecondary)),
          ]),
        ),
      ),
    ]);
  }
}