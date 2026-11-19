import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/download_provider.dart';
import '../services/player_native.dart';
import '../widgets/thumb.dart';

enum _Level { none, brightness, volume }

/// Built-in player.
/// - tap: show / hide the controls        - double tap left / right: -10s / +10s
/// - hold the right side: 2x speed        - swipe up/down on the left: brightness, right: volume
/// - lock button: ignores all touches until unlocked
class PlayerPage extends StatefulWidget {
  final HistoryEntry entry;
  const PlayerPage({super.key, required this.entry});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final VideoPlayerController _c;
  bool _ready = false;
  bool _error = false;
  bool _show = true;
  bool _landscape = false;
  bool _dragging = false; // seek bar
  double _drag = 0;
  double _speed = 1.0;
  bool _boost = false; // holding for 2x

  bool _locked = false;
  bool _lockBtn = false; // lock icon visible while locked

  // brightness / volume gesture
  _Level _level = _Level.none;
  bool _levelLeft = true;
  double _levelValue = 0;
  bool _levelReady = false;
  Timer? _levelTimer;

  Timer? _hide;
  Timer? _lockTimer;
  Offset _tap = Offset.zero;

  bool get _audio => widget.entry.isAudio;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.file(File(widget.entry.path));
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _c.play();
      _autoHide();
    }).catchError((_) {
      if (mounted) setState(() => _error = true);
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    _lockTimer?.cancel();
    _levelTimer?.cancel();
    _c.dispose();
    PlayerNative.resetBrightness();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ------------------------------------------------------------- controls
  void _autoHide() {
    _hide?.cancel();
    if (_c.value.isPlaying) {
      _hide = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _show = false);
      });
    }
  }

  void _onTap() {
    if (_locked) {
      _flashLockButton();
      return;
    }
    setState(() => _show = !_show);
    if (_show) _autoHide();
  }

  void _flashLockButton() {
    _lockTimer?.cancel();
    setState(() => _lockBtn = true);
    _lockTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _lockBtn = false);
    });
  }

  void _lock() {
    setState(() {
      _locked = true;
      _show = false;
    });
    _flashLockButton();
  }

  void _unlock() {
    _lockTimer?.cancel();
    setState(() {
      _locked = false;
      _lockBtn = false;
      _show = true;
    });
    _autoHide();
  }

  Future<void> _seekBy(int seconds) async {
    final pos = _c.value.position + Duration(seconds: seconds);
    final max = _c.value.duration;
    await _c.seekTo(pos < Duration.zero ? Duration.zero : (pos > max ? max : pos));
    _autoHide();
  }

  void _playPause() {
    final v = _c.value;
    if (v.isPlaying) {
      _c.pause();
      _hide?.cancel();
    } else {
      if (v.position >= v.duration) _c.seekTo(Duration.zero);
      _c.play();
      _autoHide();
    }
  }

  void _rotate() {
    setState(() => _landscape = !_landscape);
    SystemChrome.setPreferredOrientations(_landscape
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
        _landscape ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  // -------------------------------------------------------------- gestures
  void _onLongPressStart(LongPressStartDetails d) {
    if (_locked || !_ready) return;
    final w = MediaQuery.of(context).size.width;
    if (d.localPosition.dx > w / 2) {
      HapticFeedback.mediumImpact();
      _c.setPlaybackSpeed(2.0);
      setState(() => _boost = true);
    }
  }

  void _endBoost() {
    if (!_boost) return;
    _c.setPlaybackSpeed(_speed);
    setState(() => _boost = false);
  }

  Future<void> _onDragStart(DragStartDetails d) async {
    if (_locked || !_ready) return;
    final w = MediaQuery.of(context).size.width;
    _levelLeft = d.localPosition.dx < w / 2;
    _levelReady = false;
    _levelTimer?.cancel();
    final v = _levelLeft ? await PlayerNative.brightness() : await PlayerNative.volume();
    _levelValue = v.clamp(0.0, 1.0);
    _levelReady = true;
    if (mounted) {
      setState(() => _level = _levelLeft ? _Level.brightness : _Level.volume);
    }
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_locked || !_levelReady || _level == _Level.none) return;
    final h = MediaQuery.of(context).size.height;
    _levelValue = (_levelValue - d.delta.dy / (h * 0.45)).clamp(0.0, 1.0);
    if (_level == _Level.brightness) {
      PlayerNative.setBrightness(_levelValue);
    } else {
      PlayerNative.setVolume(_levelValue);
    }
    setState(() {});
  }

  void _onDragEnd([DragEndDetails? _]) {
    _levelTimer?.cancel();
    _levelTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _level = _Level.none);
    });
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  // ------------------------------------------------------------------ UI
  Widget _media(AppPalette c) {
    if (_error) {
      return SafeArea(
        child: Stack(children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white70, size: 48),
              const SizedBox(height: 12),
              Text(context.tr('player_error'),
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () =>
                    context.read<DownloadProvider>().openFile(widget.entry),
                child: Text(context.tr('menu_open_with')),
              ),
            ]),
          ),
        ]),
      );
    }
    if (!_ready) return const Center(child: CircularProgressIndicator());
    if (_audio) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: c.primary.withAlpha(0x55), blurRadius: 40, spreadRadius: 2)
                ],
              ),
              child: VideoThumb(url: widget.entry.thumbnail, w: 240, h: 240),
            ),
            const SizedBox(height: 28),
            Text(widget.entry.title,
                maxLines: 3,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _c.value.aspectRatio == 0 ? 16 / 9 : _c.value.aspectRatio,
        child: VideoPlayer(_c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette.of(context);
    final controls = _show && !_locked;
    final lockVisible = _locked ? _lockBtn : _show;

    return PopScope(
      canPop: !_locked,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _locked) _flashLockButton();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [
          _media(c),

          // touch layer: sits ABOVE the video and BELOW the buttons
          if (_ready && !_error)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onTap,
              onDoubleTapDown: (d) => _tap = d.localPosition,
              onDoubleTap: () {
                if (_locked) return;
                final w = MediaQuery.of(context).size.width;
                _seekBy(_tap.dx < w / 2 ? -10 : 10);
              },
              onLongPressStart: _onLongPressStart,
              onLongPressEnd: (_) => _endBoost(),
              onLongPressCancel: _endBoost,
              onVerticalDragStart: _onDragStart,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              onVerticalDragCancel: _onDragEnd,
              child: const SizedBox.expand(),
            ),

          if (_ready && !_error) ...[
            // dark gradient (visual only)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: controls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xB3000000),
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0xB3000000)
                        ],
                        stops: [0, 0.25, 0.65, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // buttons (empty areas let touches fall through to the touch layer)
            AnimatedOpacity(
              opacity: controls ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !controls,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [_topBar(c), _centerButtons(c), _bottomBar(c)],
                  ),
                ),
              ),
            ),

            // screen lock button
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: lockVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !lockVisible,
                    child: Container(
                      decoration: const BoxDecoration(
                          color: Color(0x80000000), shape: BoxShape.circle),
                      child: IconButton(
                        icon: Icon(
                            _locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                            color: Colors.white),
                        tooltip: _locked
                            ? context.tr('unlock_screen')
                            : context.tr('lock_screen'),
                        onPressed: _locked ? _unlock : _lock,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 2x speed chip
            if (_boost)
              Align(
                alignment: const Alignment(0, -0.7),
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xB3000000),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('2x',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800)),
                      SizedBox(width: 6),
                      Icon(Icons.fast_forward_rounded, color: Colors.white, size: 20),
                    ]),
                  ),
                ),
              ),

            // brightness / volume indicator
            if (_level != _Level.none)
              Align(
                alignment: _levelLeft ? Alignment.centerLeft : Alignment.centerRight,
                child: IgnorePointer(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    decoration: BoxDecoration(
                        color: const Color(0xB3000000),
                        borderRadius: BorderRadius.circular(18)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          _level == _Level.brightness
                              ? Icons.brightness_6_rounded
                              : (_levelValue <= 0
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded),
                          color: Colors.white),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 110,
                        width: 6,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: _levelValue,
                              color: c.primary,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('${(_levelValue * 100).round()}%',
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ]),
                  ),
                ),
              ),
          ],
        ]),
      ),
    );
  }

  Widget _topBar(AppPalette c) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(widget.entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          PopupMenuButton<double>(
            tooltip: context.tr('player_speed'),
            icon: const Icon(Icons.speed_rounded, color: Colors.white),
            onSelected: (s) {
              setState(() => _speed = s);
              _c.setPlaybackSpeed(s);
            },
            itemBuilder: (_) => [
              for (final s in const [0.5, 1.0, 1.5, 2.0])
                PopupMenuItem(
                    value: s,
                    child: Row(children: [
                      SizedBox(
                          width: 24,
                          child: _speed == s
                              ? const Icon(Icons.check_rounded, size: 18)
                              : null),
                      Text('${s}x'),
                    ])),
            ],
          ),
          if (!_audio)
            IconButton(
              icon: Icon(
                  _landscape
                      ? Icons.screen_rotation_alt_rounded
                      : Icons.screen_rotation_rounded,
                  color: Colors.white),
              onPressed: _rotate,
            ),
        ]),
      );

  Widget _centerButtons(AppPalette c) => ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _c,
        builder: (_, v, __) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 38,
              icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
              onPressed: () => _seekBy(-10),
            ),
            const SizedBox(width: 18),
            Container(
              decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
              child: IconButton(
                iconSize: 46,
                padding: const EdgeInsets.all(10),
                icon: Icon(
                    v.isPlaying
                        ? Icons.pause_rounded
                        : (v.position >= v.duration && v.duration > Duration.zero
                            ? Icons.replay_rounded
                            : Icons.play_arrow_rounded),
                    color: Colors.white),
                onPressed: _playPause,
              ),
            ),
            const SizedBox(width: 18),
            IconButton(
              iconSize: 38,
              icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
              onPressed: () => _seekBy(10),
            ),
          ],
        ),
      );

  Widget _bottomBar(AppPalette c) => ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _c,
        builder: (_, v, __) {
          final total = v.duration.inMilliseconds;
          final max = total > 0 ? total.toDouble() : 1.0;
          final pos = v.position.inMilliseconds.toDouble().clamp(0.0, max);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              Text(_fmt(_dragging ? Duration(milliseconds: _drag.toInt()) : v.position),
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: (_dragging ? _drag : pos).clamp(0.0, max),
                  max: max,
                  activeColor: c.primary,
                  inactiveColor: Colors.white24,
                  onChangeStart: (x) {
                    _dragging = true;
                    _drag = x;
                    _hide?.cancel();
                  },
                  onChanged: (x) => setState(() => _drag = x),
                  onChangeEnd: (x) async {
                    await _c.seekTo(Duration(milliseconds: x.toInt()));
                    if (mounted) setState(() => _dragging = false);
                    _autoHide();
                  },
                ),
              ),
              Text(_fmt(v.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ]),
          );
        },
      );
}
