import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'package:derde_divisie/core/config/media_config.dart';
import 'package:derde_divisie/core/widgets/derde_div_logo.dart';

class IntroVideoScreen extends StatefulWidget {
  const IntroVideoScreen({super.key});

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen>
    with WidgetsBindingObserver {
  static const _background = Color(0xFF07110D);
  static const _green = Color(0xFF3BAE5D);

  VideoPlayerController? _controller;
  bool _isInitializing = false;
  bool _isFullscreenActive = false;
  String? _errorMessage;
  double _volume = 0.7;
  bool _isMuted = false;
  bool _wasPlayingBeforeFullscreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _controller?.pause();
    }
  }

  Future<void> _initializeVideo() async {
    if (_isInitializing || _controller != null) return;

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    final controller = VideoPlayerController.networkUrl(
      MediaConfig.introVideo20262027Url,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );

    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(_isMuted ? 0 : _volume);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage =
            'De introfilm kan niet worden geladen. De browser ondersteunt dit videoformaat mogelijk niet, of de verbinding is tijdelijk niet beschikbaar.';
      });
    }
  }

  Future<void> _retry() async {
    final oldController = _controller;
    _controller = null;
    await oldController?.pause();
    await oldController?.dispose();
    if (!mounted) return;
    await _initializeVideo();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.setVolume(_isMuted ? 0 : _volume);
      await controller.play();
    }

    if (mounted) setState(() {});
  }

  Future<void> _restart() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    await controller.seekTo(Duration.zero);
    await controller.setVolume(_isMuted ? 0 : _volume);
    await controller.play();
    if (mounted) setState(() {});
  }

  Future<void> _seekTo(Duration position) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.seekTo(position);
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    final nextMuted = !_isMuted;
    setState(() => _isMuted = nextMuted);
    await controller?.setVolume(nextMuted ? 0 : _volume);
  }

  Future<void> _setVolume(double value) async {
    final controller = _controller;
    setState(() {
      _volume = value;
      _isMuted = value == 0;
    });
    await controller?.setVolume(value);
  }

  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    _wasPlayingBeforeFullscreen = controller.value.isPlaying;
    final position = controller.value.position;
    await controller.setVolume(_isMuted ? 0 : _volume);
    if (!mounted) return;

    setState(() => _isFullscreenActive = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await controller.seekTo(position);
    if (_wasPlayingBeforeFullscreen && !controller.value.isPlaying) {
      await controller.play();
    }
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _IntroVideoFullscreen(
          controller: controller,
          isMuted: _isMuted,
          volume: _volume,
          onTogglePlayback: _togglePlayback,
          onRestart: _restart,
          onSeekTo: _seekTo,
          onToggleMute: _toggleMute,
          onVolumeChanged: _setVolume,
        ),
      ),
    );

    if (!mounted) return;
    final shouldResumeInline = _wasPlayingBeforeFullscreen;
    setState(() => _isFullscreenActive = false);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (shouldResumeInline && !controller.value.isPlaying) {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    controller?.pause();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F1),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 900 ? 32.0 : 16.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Derde Divisie introfilm',
                        style: TextStyle(
                          color: Color(0xFF153B2A),
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Seizoen 2026/2027',
                        style: TextStyle(
                          color: Color(0xFF3BAE5D),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Bekijk de officiële introductiefilm van de Derde Divisie voor het seizoen 2026/2027.',
                        style: TextStyle(
                          color: Color(0xFF5F6D64),
                          fontSize: 15.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        decoration: BoxDecoration(
                          color: _background,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _green.withValues(alpha: .34),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _green.withValues(alpha: .14),
                              blurRadius: 28,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: _buildVideoSurface(),
                            ),
                            if (_controller != null &&
                                _controller!.value.isInitialized)
                              _IntroVideoControls(
                                controller: _controller!,
                                isMuted: _isMuted,
                                volume: _volume,
                                onTogglePlayback: _togglePlayback,
                                onRestart: _restart,
                                onSeekTo: _seekTo,
                                onToggleMute: _toggleMute,
                                onVolumeChanged: _setVolume,
                                onFullscreen: _openFullscreen,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoSurface() {
    if (_errorMessage != null) {
      return IntroVideoErrorPanel(message: _errorMessage!, onRetry: _retry);
    }

    final controller = _controller;
    if (_isInitializing ||
        controller == null ||
        !controller.value.isInitialized) {
      return IntroVideoPlaceholder(isLoading: _isInitializing);
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasPlaybackError = value.hasError;

        if (_isFullscreenActive && !hasPlaybackError) {
          return IntroVideoFullscreenPlaceholder(isPlaying: value.isPlaying);
        }

        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            if (!hasPlaybackError)
              FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: value.size.width,
                  height: value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            else
              IntroVideoErrorPanel(
                message:
                    'De introfilm kan niet worden afgespeeld. De browser ondersteunt dit videoformaat mogelijk niet.',
                onRetry: _retry,
              ),
            if (!value.isPlaying && !hasPlaybackError)
              _CenterPlayButton(onPressed: _togglePlayback),
            if (value.isBuffering && !hasPlaybackError)
              const Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: _green,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class IntroVideoPlaceholder extends StatelessWidget {
  final bool isLoading;

  const IntroVideoPlaceholder({super.key, this.isLoading = false});

  static const _green = Color(0xFF3BAE5D);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF07110D),
        gradient: RadialGradient(
          center: Alignment.center,
          radius: .78,
          colors: [Color(0x332F8F3B), Color(0xFF07110D)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DerdeDivLogo.full(width: 210, height: 82),
            if (isLoading) ...[
              const SizedBox(height: 24),
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: _green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class IntroVideoFullscreenPlaceholder extends StatelessWidget {
  final bool isPlaying;

  const IntroVideoFullscreenPlaceholder({
    super.key,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF07110D),
        gradient: RadialGradient(
          center: Alignment.center,
          radius: .78,
          colors: [Color(0x22000000), Color(0xFF07110D)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DerdeDivLogo.full(width: 190, height: 76),
            const SizedBox(height: 18),
            Text(
              isPlaying
                  ? 'Schermvullende weergave actief'
                  : 'Video staat schermvullend klaar',
              style: const TextStyle(
                color: Color(0xFFB9C7BE),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IntroVideoErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const IntroVideoErrorPanel({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF07110D),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.ondemand_video_rounded,
                color: Color(0xFF3BAE5D),
                size: 42,
              ),
              const SizedBox(height: 14),
              const Text(
                'Video niet beschikbaar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB9C7BE),
                  fontSize: 14.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Probeer opnieuw'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterPlayButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CenterPlayButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Introfilm afspelen',
      child: Tooltip(
        message: 'Afspelen',
        child: InkResponse(
          onTap: onPressed,
          radius: 48,
          child: Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: const Color(0xFF3BAE5D).withValues(alpha: .92),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 46,
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroVideoControls extends StatelessWidget {
  final VideoPlayerController controller;
  final bool isMuted;
  final double volume;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRestart;
  final ValueChanged<Duration> onSeekTo;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onFullscreen;
  final bool overlay;

  const _IntroVideoControls({
    required this.controller,
    required this.isMuted,
    required this.volume,
    required this.onTogglePlayback,
    required this.onRestart,
    required this.onSeekTo,
    required this.onToggleMute,
    required this.onVolumeChanged,
    required this.onFullscreen,
    this.overlay = false,
  });

  static const _green = Color(0xFF3BAE5D);
  static const _text = Color(0xFFE8F0EA);
  static const _muted = Color(0xFFB9C7BE);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final duration = value.duration;
        final position = value.position > duration ? duration : value.position;
        final maxSeconds = duration.inMilliseconds <= 0
            ? 1.0
            : duration.inMilliseconds.toDouble();
        final currentSeconds =
            position.inMilliseconds.clamp(0, maxSeconds.toInt()).toDouble();
        final compact = MediaQuery.sizeOf(context).width < 720;

        return Container(
          decoration: BoxDecoration(
            color: overlay
                ? Colors.black.withValues(alpha: .46)
                : const Color(0xFF0C1B14),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            children: [
              Semantics(
                label: 'Voortgang van de introfilm',
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _green,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: _green,
                    overlayColor: _green.withValues(alpha: .18),
                  ),
                  child: Slider(
                    value: currentSeconds,
                    min: 0,
                    max: maxSeconds,
                    onChanged: (next) {
                      onSeekTo(Duration(milliseconds: next.round()));
                    },
                  ),
                ),
              ),
              Row(
                children: [
                  _ControlButton(
                    tooltip: value.isPlaying ? 'Pauzeren' : 'Afspelen',
                    icon: value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    onPressed: onTogglePlayback,
                  ),
                  _ControlButton(
                    tooltip: 'Opnieuw afspelen',
                    icon: Icons.replay_rounded,
                    onPressed: onRestart,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    style: const TextStyle(
                      color: _text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _ControlButton(
                    tooltip: isMuted ? 'Geluid inschakelen' : 'Dempen',
                    icon: isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    onPressed: onToggleMute,
                  ),
                  if (!compact)
                    SizedBox(
                      width: 130,
                      child: Semantics(
                        label: 'Volumeniveau',
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: _green,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: _green,
                          ),
                          child: Slider(
                            value: isMuted ? 0 : volume,
                            min: 0,
                            max: 1,
                            onChanged: onVolumeChanged,
                          ),
                        ),
                      ),
                    ),
                  _ControlButton(
                    tooltip: 'Schermvullend weergeven',
                    icon: Icons.fullscreen_rounded,
                    onPressed: onFullscreen,
                  ),
                  if (value.isBuffering)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text(
                        'Bufferen...',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _ControlButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        color: Colors.white,
        iconSize: 25,
        onPressed: onPressed,
      ),
    );
  }
}

class _IntroVideoFullscreen extends StatefulWidget {
  final VideoPlayerController controller;
  final bool isMuted;
  final double volume;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRestart;
  final ValueChanged<Duration> onSeekTo;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolumeChanged;

  const _IntroVideoFullscreen({
    required this.controller,
    required this.isMuted,
    required this.volume,
    required this.onTogglePlayback,
    required this.onRestart,
    required this.onSeekTo,
    required this.onToggleMute,
    required this.onVolumeChanged,
  });

  @override
  State<_IntroVideoFullscreen> createState() => _IntroVideoFullscreenState();
}

class _IntroVideoFullscreenState extends State<_IntroVideoFullscreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).maybePop();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: _validAspectRatio(
                      widget.controller.value.aspectRatio,
                    ),
                    child: VideoPlayer(widget.controller),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Semantics(
                    button: true,
                    label: 'Schermvullende weergave sluiten',
                    child: IconButton.filled(
                      tooltip: 'Sluiten',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _IntroVideoControls(
                    controller: widget.controller,
                    isMuted: widget.isMuted,
                    volume: widget.volume,
                    onTogglePlayback: widget.onTogglePlayback,
                    onRestart: widget.onRestart,
                    onSeekTo: widget.onSeekTo,
                    onToggleMute: widget.onToggleMute,
                    onVolumeChanged: widget.onVolumeChanged,
                    onFullscreen: () => Navigator.of(context).maybePop(),
                    overlay: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _validAspectRatio(double aspectRatio) {
    if (aspectRatio.isFinite && aspectRatio > 0) return aspectRatio;
    return 16 / 9;
  }
}
