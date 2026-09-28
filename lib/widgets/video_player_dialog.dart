import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/utils/video_selection_utils.dart';

class VideoPlayerDialog extends StatefulWidget {
  VideoPlayerDialog.file({
    super.key,
    required String filePath,
    required this.title,
  }) : _controllerFactory = (() => VideoPlayerController.file(File(filePath)));

  final String title;
  final VideoPlayerController Function() _controllerFactory;

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late final VideoPlayerController _controller;
  String? _errorMessage;
  bool _isInitialized = false;
  bool _isLoopingSelection = false;
  bool _isSelectingSegment = false;
  bool _isSeeking = false;
  bool? _draggingStartHandle;
  double _selectionStartMs = 0;
  double? _selectionEndMs;
  double _lastVolume = 1;

  int get _durationMs => _controller.value.duration.inMilliseconds;

  @override
  void initState() {
    super.initState();
    _controller = widget._controllerFactory();
    _controller.addListener(_onPlayerUpdate);
    _initializePlayer();
  }

  void _onPlayerUpdate() {
    if (mounted) setState(() {});
    if (_isLoopingSelection &&
        !_isSeeking &&
        _isInitialized &&
        _controller.value.isPlaying) {
      final positionMs = _controller.value.position.inMilliseconds;
      final endMs = _selectionEndMs ?? _durationMs.toDouble();
      if (positionMs >= endMs ||
          positionMs < _selectionStartMs.floorToDouble()) {
        _seekToSelectionStart(resumePlayback: true);
      }
    }
  }

  Future<void> _initializePlayer() async {
    try {
      await _controller.initialize();
      final durationMs = _durationMs.toDouble();
      _selectionEndMs = durationMs;
      await _controller.setLooping(false);
      await _controller.setVolume(1);
      await _controller.play();
      if (mounted) setState(() => _isInitialized = true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Could not play this video. The file or video link may be missing or unsupported.\n$error',
        );
      }
    }
  }

  Future<void> _seekToSelectionStart({bool resumePlayback = false}) async {
    if (_isSeeking || !_isInitialized) return;
    _isSeeking = true;
    try {
      await _controller.seekTo(
        Duration(milliseconds: _selectionStartMs.round()),
      );
      if (resumePlayback && mounted) await _controller.play();
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not seek within this video: $error';
          _isLoopingSelection = false;
        });
      }
    } finally {
      _isSeeking = false;
    }
  }

  Future<void> _togglePlayback() async {
    if (!_isInitialized) return;
    try {
      if (_controller.value.isPlaying) {
        await _controller.pause();
      } else {
        final positionMs = _controller.value.position.inMilliseconds;
        final endMs = _selectionEndMs ?? _durationMs.toDouble();
        if (positionMs >= endMs ||
            (_isLoopingSelection && positionMs < _selectionStartMs)) {
          await _controller.seekTo(
            Duration(milliseconds: _selectionStartMs.round()),
          );
        }
        await _controller.play();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not control playback: $error');
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    if (!_isInitialized) return;
    try {
      if (_controller.value.volume > 0) {
        _lastVolume = _controller.value.volume;
        await _controller.setVolume(0);
      } else {
        await _controller.setVolume(_lastVolume == 0 ? 1 : _lastVolume);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not change volume: $error');
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleLoopSelection() async {
    setState(() => _isLoopingSelection = !_isLoopingSelection);
    if (_isLoopingSelection) {
      await _seekToSelectionStart(resumePlayback: _controller.value.isPlaying);
    }
  }

  Future<void> _seekToPosition(double positionMs) async {
    try {
      await _controller.seekTo(Duration(milliseconds: positionMs.round()));
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not seek in this video: $error');
      }
    }
  }

  Future<void> _setVolume(double volume) async {
    try {
      if (volume > 0) _lastVolume = volume;
      await _controller.setVolume(volume);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not change volume: $error');
      }
    }
  }

  void _updateTimeline(double value, double width) {
    if (width <= 0 || _durationMs <= 0) return;
    final trackWidth = (width - 24).clamp(1, double.infinity);
    final valueMs =
        ((value - 12).clamp(0, trackWidth) / trackWidth) * _durationMs;

    if (!_isSelectingSegment) {
      _seekToPosition(valueMs);
      return;
    }

    final selection = RangeValues(
      _selectionStartMs,
      _selectionEndMs ?? _durationMs.toDouble(),
    );
    final startX = 12 + selection.start / _durationMs * trackWidth;
    final endX = 12 + selection.end / _durationMs * trackWidth;
    _draggingStartHandle ??= (value - startX).abs() <= (value - endX).abs();
    final nextSelection = _draggingStartHandle!
        ? moveVideoSelectionStart(selection, valueMs, _durationMs)
        : moveVideoSelectionEnd(selection, valueMs, _durationMs);
    setState(() {
      _selectionStartMs = nextSelection.start;
      _selectionEndMs = nextSelection.end;
    });
  }

  void _finishTimelineInteraction() {
    _draggingStartHandle = null;
  }

  String _timeLabel(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (value.inHours > 0) return '${value.inHours}:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  String _millisecondsLabel(double value) =>
      _timeLabel(Duration(milliseconds: value.round()));

  @override
  void dispose() {
    _controller.removeListener(_onPlayerUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = _controller.value;
    final durationMs = _durationMs;
    final endMs = _selectionEndMs ?? durationMs.toDouble();
    final positionMs = value.position.inMilliseconds
        .clamp(0, durationMs > 0 ? durationMs : 0)
        .toDouble();
    final volume = value.volume;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close video',
                    onPressed: () => Navigator.of(context).pop(),
                    color: Colors.white,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              fit: FlexFit.tight,
              child: Center(
                child: _errorMessage != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      )
                    : !_isInitialized
                    ? const Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(),
                      )
                    : AspectRatio(
                        aspectRatio: value.aspectRatio > 0
                            ? value.aspectRatio
                            : 9 / 16,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ColoredBox(
                            color: Colors.black,
                            child: GestureDetector(
                              onTap: _togglePlayback,
                              child: VideoPlayer(_controller),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            if (_isInitialized) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00111111), Color(0xFF111111)],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          _timeLabel(value.position),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              return Semantics(
                                label: _isSelectingSegment
                                    ? 'Video loop section selection'
                                    : 'Video position',
                                value: _isSelectingSegment
                                    ? 'Start ${_millisecondsLabel(_selectionStartMs)}, end ${_millisecondsLabel(endMs)}'
                                    : _timeLabel(value.position),
                                slider: true,
                                onIncrease: _isSelectingSegment
                                    ? null
                                    : () => _seekToPosition(
                                        (positionMs + 1000)
                                            .clamp(0, durationMs)
                                            .toDouble(),
                                      ),
                                onDecrease: _isSelectingSegment
                                    ? null
                                    : () => _seekToPosition(
                                        (positionMs - 1000)
                                            .clamp(0, durationMs)
                                            .toDouble(),
                                      ),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapUp: (details) {
                                    _draggingStartHandle = null;
                                    _updateTimeline(
                                      details.localPosition.dx,
                                      width,
                                    );
                                    _finishTimelineInteraction();
                                  },
                                  onHorizontalDragStart: (details) {
                                    _draggingStartHandle = null;
                                    final selection = RangeValues(
                                      _selectionStartMs,
                                      endMs,
                                    );
                                    final trackWidth = (width - 24).clamp(
                                      1,
                                      double.infinity,
                                    );
                                    final startX =
                                        12 +
                                        selection.start /
                                            (durationMs > 0 ? durationMs : 1) *
                                            trackWidth;
                                    final endX =
                                        12 +
                                        selection.end /
                                            (durationMs > 0 ? durationMs : 1) *
                                            trackWidth;
                                    _draggingStartHandle =
                                        (details.localPosition.dx - startX)
                                            .abs() <=
                                        (details.localPosition.dx - endX).abs();
                                  },
                                  onHorizontalDragUpdate: (details) =>
                                      _updateTimeline(
                                        details.localPosition.dx,
                                        width,
                                      ),
                                  onHorizontalDragEnd: (_) =>
                                      _finishTimelineInteraction(),
                                  onHorizontalDragCancel:
                                      _finishTimelineInteraction,
                                  child: CustomPaint(
                                    painter: _VideoTimelinePainter(
                                      durationMs: durationMs,
                                      positionMs: positionMs,
                                      selectionStartMs: _selectionStartMs,
                                      selectionEndMs: endMs,
                                      isSelectingSegment: _isSelectingSegment,
                                      activeColor: theme.colorScheme.error,
                                    ),
                                    child: const SizedBox(height: 40),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Text(
                          _timeLabel(value.duration),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    if (_isSelectingSegment)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(40, 0, 40, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Start ${_millisecondsLabel(_selectionStartMs)}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              'End ${_millisecondsLabel(endMs)}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: value.isPlaying ? 'Pause' : 'Play',
                          onPressed: _togglePlayback,
                          color: Colors.white,
                          iconSize: 32,
                          icon: Icon(
                            value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                        IconButton(
                          tooltip: volume == 0 ? 'Unmute' : 'Mute',
                          onPressed: _toggleMute,
                          color: Colors.white,
                          icon: Icon(
                            volume == 0
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            min: 0,
                            max: 1,
                            value: volume.clamp(0, 1).toDouble(),
                            onChanged: _setVolume,
                          ),
                        ),
                        IconButton(
                          tooltip: _isSelectingSegment
                              ? 'Finish selecting section'
                              : 'Select repeat section',
                          onPressed: () => setState(
                            () => _isSelectingSegment = !_isSelectingSegment,
                          ),
                          color: _isSelectingSegment
                              ? theme.colorScheme.error
                              : Colors.white,
                          icon: Icon(
                            _isSelectingSegment
                                ? Icons.check_circle_rounded
                                : Icons.content_cut_rounded,
                          ),
                        ),
                        IconButton(
                          tooltip: _isLoopingSelection
                              ? 'Stop repeating section'
                              : 'Repeat selected section',
                          onPressed: _toggleLoopSelection,
                          color: _isLoopingSelection
                              ? theme.colorScheme.error
                              : Colors.white,
                          icon: Icon(
                            _isLoopingSelection
                                ? Icons.repeat_one_on_rounded
                                : Icons.repeat_one_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VideoTimelinePainter extends CustomPainter {
  const _VideoTimelinePainter({
    required this.durationMs,
    required this.positionMs,
    required this.selectionStartMs,
    required this.selectionEndMs,
    required this.isSelectingSegment,
    required this.activeColor,
  });

  final int durationMs;
  final double positionMs;
  final double selectionStartMs;
  final double selectionEndMs;
  final bool isSelectingSegment;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (durationMs <= 0 || size.width <= 24) return;
    const horizontalInset = 12.0;
    final trackWidth = size.width - horizontalInset * 2;
    final centerY = size.height / 2;
    final positionX = horizontalInset + positionMs / durationMs * trackWidth;
    if (isSelectingSegment) {
      final startX =
          horizontalInset + selectionStartMs / durationMs * trackWidth;
      final endX = horizontalInset + selectionEndMs / durationMs * trackWidth;
      final selectedPaint = Paint()
        ..color = activeColor
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(startX, centerY),
        Offset(endX, centerY),
        selectedPaint,
      );
      final handlePaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(startX, centerY), 6, handlePaint);
      canvas.drawCircle(Offset(endX, centerY), 6, handlePaint);
    } else {
      final backgroundPaint = Paint()
        ..color = Colors.white24
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(horizontalInset, centerY),
        Offset(size.width - horizontalInset, centerY),
        backgroundPaint,
      );
      final playedPaint = Paint()
        ..color = activeColor
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(horizontalInset, centerY),
        Offset(
          positionX.clamp(horizontalInset, size.width - horizontalInset),
          centerY,
        ),
        playedPaint,
      );
    }

    canvas.drawCircle(
      Offset(
        positionX.clamp(horizontalInset, size.width - horizontalInset),
        centerY,
      ),
      5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _VideoTimelinePainter oldDelegate) =>
      durationMs != oldDelegate.durationMs ||
      positionMs != oldDelegate.positionMs ||
      selectionStartMs != oldDelegate.selectionStartMs ||
      selectionEndMs != oldDelegate.selectionEndMs ||
      isSelectingSegment != oldDelegate.isSelectingSegment ||
      activeColor != oldDelegate.activeColor;
}
