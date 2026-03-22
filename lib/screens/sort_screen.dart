import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:path/path.dart' as p;
import '../theme.dart';
import '../services/file_service.dart';
import 'done_screen.dart';

enum Dir { up, down, left, right }

const _kWhite85 = Color(0xD9FFFFFF);
const _kWhite50 = Color(0x80FFFFFF);
const _kWhite15 = Color(0x26FFFFFF);

class SortScreen extends StatefulWidget {
  final List<String> images;
  final String sourceDir;
  final String? destDir;    // optional — defaults to sourceDir if null
  final List<String> names; // [up, down, left, right]

  const SortScreen({
    super.key,
    required this.images,
    required this.sourceDir,
    required this.names,
    this.destDir,
  });

  @override
  State<SortScreen> createState() => _SortScreenState();
}

class _SortScreenState extends State<SortScreen>
    with TickerProviderStateMixin {

  int  _index       = 0;
  int  _sortedCount = 0;
  bool _locked      = false;

  final _drag    = ValueNotifier<Offset>(Offset.zero);
  final _hintDir = ValueNotifier<Dir?>(null);

  Offset _dragStart = Offset.zero;
  bool   _dragging  = false;

  late final AnimationController _flyCtrl;
  late final AnimationController _snapCtrl;
  Offset _flyTarget = Offset.zero;

  final Map<int, Widget> _cache = {};
  static const _preload  = 4;
  static const _cacheMax = 8;

  late final List<String> _labels;
  static const _threshold = 70.0;

  @override
  void initState() {
    super.initState();
    _labels = widget.names.map((n) => n.toUpperCase()).toList();
    _flyCtrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _snapCtrl = AnimationController.unbounded(vsync: this);
    _preloadFrom(0);
  }

  @override
  void dispose() {
    _drag.dispose();
    _hintDir.dispose();
    _flyCtrl.dispose();
    _snapCtrl.dispose();
    super.dispose();
  }

  // ── Cache ──────────────────────────────────────────────────────────────────

  Widget _buildImg(int i) => Image.file(
        File(widget.images[i]),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_outlined,
              color: FotoColors.textHint, size: 48),
        ),
      );

  void _preloadFrom(int from) {
    for (int i = from; i < from + _preload && i < widget.images.length; i++) {
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
    Dir? dir;
    if (delta.distance > 15) {
      if (delta.dx.abs() > delta.dy.abs()) {
        dir = delta.dx > 0 ? Dir.right : Dir.left;
      } else {
        dir = delta.dy > 0 ? Dir.down : Dir.up;
      }
    }
    _drag.value    = delta;
    _hintDir.value = dir;
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_dragging || _locked) return;
    _dragging = false;
    final velocity = d.velocity.pixelsPerSecond.distance;
    final hint     = _hintDir.value;
    if (hint != null && (_drag.value.distance >= _threshold || velocity > 800)) {
      _commitWithAnimation(hint, d.velocity.pixelsPerSecond);
    } else {
      _snapBack(d.velocity.pixelsPerSecond);
    }
  }

  // ── Spring snap-back ───────────────────────────────────────────────────────

  void _snapBack(Offset velocity) {
    _hintDir.value = null;
    final start = _drag.value;
    if (start == Offset.zero) return;

    final spring = SpringDescription.withDampingRatio(
      mass: 1.0, stiffness: 300.0, ratio: 0.7,
    );

    final simX = SpringSimulation(spring, start.dx, 0, velocity.dx * 0.1);
    final simY = SpringSimulation(spring, start.dy, 0, velocity.dy * 0.1);

    _snapCtrl.stop();
    _snapCtrl.value = 0;
    _snapCtrl.animateWith(_DirectSpring(simX, simY, start, _drag));
  }

  // ── Fly-off ────────────────────────────────────────────────────────────────

  void _commitWithAnimation(Dir dir, Offset velocity) {
    if (_locked) return;
    _locked = true;
    _hintDir.value = null;

    final size = MediaQuery.sizeOf(context);
    _flyTarget = switch (dir) {
      Dir.up    => Offset(0, -size.height * 1.5),
      Dir.down  => Offset(0,  size.height * 1.5),
      Dir.left  => Offset(-size.width * 1.5, 0),
      Dir.right => Offset( size.width * 1.5, 0),
    };

    _flyCtrl.value = 0;
    _flyCtrl.animateTo(1, curve: Curves.easeIn).then((_) {
      if (!mounted) return;
      _finishCommit(dir);
    });
  }

  void _finishCommit(Dir dir) {
    // Use destDir if set, otherwise fall back to sourceDir
    final base = widget.destDir ?? widget.sourceDir;
    FileService.moveFile(
      widget.images[_index],
      p.join(base, widget.names[dir.index]),
    );

    _cache.remove(_index);
    _drag.value    = Offset.zero;
    _flyCtrl.value = 0;
    _flyTarget     = Offset.zero;

    final next     = _index + 1;
    final newCount = _sortedCount + 1;
    final done     = next >= widget.images.length;

    _preloadFrom(next);

    setState(() {
      _index       = next;
      _sortedCount = newCount;
      _locked      = false;
    });

    if (done && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => DoneScreen(sortedCount: newCount, names: widget.names),
        ));
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.images.length) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: _kWhite85)),
      );
    }

    final current = _cache[_index] ?? _buildImg(_index);
    final nextImg = _index + 1 < widget.images.length
        ? (_cache[_index + 1] ?? _buildImg(_index + 1))
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [

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

        // Current card
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
              return Transform.translate(
                offset: offset,
                child: Transform.rotate(
                  angle: offset.dx / 900,
                  child: SizedBox.expand(child: current),
                ),
              );
            },
          ),
        ),

        // Hint badge
        _HintBadge(
          drag:      _drag,
          hintDir:   _hintDir,
          labels:    _labels,
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
                _TopBtn(
                  icon: Icons.close_outlined,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: FotoSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(
                        value: _sortedCount / widget.images.length,
                        minHeight: 2,
                        backgroundColor: _kWhite15,
                        valueColor: const AlwaysStoppedAnimation(_kWhite85),
                      ),
                      const SizedBox(height: FotoSpacing.xs),
                      Text('$_sortedCount / ${widget.images.length}',
                          style: FotoText.micro.copyWith(color: _kWhite50)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),

        // Bottom buttons
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(FotoSpacing.md),
              child: _BottomBar(
                names:   widget.names,
                hintDir: _hintDir,
                onTap:   (dir) => _commitWithAnimation(dir, Offset.zero),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Direct spring ──────────────────────────────────────────────────────────────

class _DirectSpring extends Simulation {
  final SpringSimulation _x;
  final SpringSimulation _y;
  final Offset _start;
  final ValueNotifier<Offset> _drag;

  _DirectSpring(this._x, this._y, this._start, this._drag);

  @override
  double x(double time) {
    _drag.value = Offset(_x.x(time), _y.x(time));
    return _drag.value.distance;
  }

  @override
  double dx(double time) => _x.dx(time);

  @override
  bool isDone(double time) {
    final done = _x.isDone(time) && _y.isDone(time);
    if (done) _drag.value = Offset.zero;
    return done;
  }
}

// ── Hint badge ─────────────────────────────────────────────────────────────────

class _HintBadge extends StatelessWidget {
  final ValueNotifier<Offset> drag;
  final ValueNotifier<Dir?> hintDir;
  final List<String> labels;
  final double threshold;

  const _HintBadge({
    required this.drag,
    required this.hintDir,
    required this.labels,
    required this.threshold,
  });

  static const _alignments = {
    Dir.up:    Alignment.topCenter,
    Dir.down:  Alignment.bottomCenter,
    Dir.left:  Alignment.centerLeft,
    Dir.right: Alignment.centerRight,
  };
  static const _paddings = {
    Dir.up:    EdgeInsets.only(top: 100),
    Dir.down:  EdgeInsets.only(bottom: 100),
    Dir.left:  EdgeInsets.only(left: 24),
    Dir.right: EdgeInsets.only(right: 24),
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([hintDir, drag]),
      builder: (_, __) {
        final dir = hintDir.value;
        if (dir == null) return const SizedBox.shrink();
        final opacity =
            ((drag.value.distance - 15) / (threshold - 15)).clamp(0.0, 1.0);
        return Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Align(
                alignment: _alignments[dir]!,
                child: Padding(
                  padding: _paddings[dir]!,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: FotoSpacing.md, vertical: FotoSpacing.sm),
                    decoration: BoxDecoration(
                      color: FotoColors.dirs[dir.index],
                      borderRadius: FotoRadius.button,
                    ),
                    child: Text(labels[dir.index],
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
  final List<String> names;
  final ValueNotifier<Dir?> hintDir;
  final void Function(Dir) onTap;

  const _BottomBar({
    required this.names,
    required this.hintDir,
    required this.onTap,
  });

  static const _dirs    = [Dir.left, Dir.down, Dir.up, Dir.right];
  static const _nameIdx = [2, 1, 0, 3];
  static const _icons   = [
    Icons.arrow_back_outlined,
    Icons.arrow_downward_outlined,
    Icons.arrow_upward_outlined,
    Icons.arrow_forward_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: FotoSpacing.md, vertical: FotoSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xE8F7F5FB),
        borderRadius: BorderRadius.circular(FotoRadius.xl),
        boxShadow: kElevatedShadow,
      ),
      child: ValueListenableBuilder<Dir?>(
        valueListenable: hintDir,
        builder: (_, active, __) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (i) {
            final dir      = _dirs[i];
            final isActive = active == dir;
            final color    = FotoColors.dirs[dir.index];
            return GestureDetector(
              onTap: () => onTap(dir),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: FotoSpacing.sm, vertical: FotoSpacing.xs),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_icons[i],
                      color: isActive ? color : FotoColors.textSecondary,
                      size: 20),
                  const SizedBox(height: FotoSpacing.xs),
                  Text(names[_nameIdx[i]],
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
    );
  }
}

// ── Top button ─────────────────────────────────────────────────────────────────

class _TopBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(FotoSpacing.sm),
        decoration: const BoxDecoration(
          color: Color(0x66000000),
          borderRadius: FotoRadius.button,
        ),
        child: Icon(icon, color: _kWhite85, size: 18),
      ),
    );
  }
}