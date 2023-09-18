import 'dart:async';
import 'dart:io';
import 'package:better_player/src/configuration/better_player_controls_configuration.dart';
import 'package:better_player/src/controls/better_player_clickable_widget.dart';
import 'package:better_player/src/controls/better_player_controls_state.dart';
import 'package:better_player/src/controls/better_player_material_progress_bar.dart';
import 'package:better_player/src/controls/better_player_multiple_gesture_detector.dart';
import 'package:better_player/src/controls/better_player_progress_colors.dart';
import 'package:better_player/src/core/better_player_controller.dart';
import 'package:better_player/src/subtitles/better_player_subtitles_source_type.dart';
import 'package:better_player/src/video_player/video_player.dart';
import 'package:collection/collection.dart';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_to_airplay/flutter_to_airplay.dart';

import '../subtitles/better_player_subtitles_source.dart';

class BetterPlayerMaterialControls extends StatefulWidget {
  ///Callback used to send information if player bar is hidden or not
  final Function(bool visbility) onControlsVisibilityChanged;

  ///Controls config
  final BetterPlayerControlsConfiguration controlsConfiguration;

  const BetterPlayerMaterialControls({
    Key? key,
    required this.onControlsVisibilityChanged,
    required this.controlsConfiguration,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _BetterPlayerMaterialControlsState();
  }
}

class _BetterPlayerMaterialControlsState
    extends BetterPlayerControlsState<BetterPlayerMaterialControls> {
  VideoPlayerValue? _latestValue;
  double _latestVolume = 0.5;
  Timer? _hideTimer;
  Timer? _initTimer;
  Timer? _showAfterExpandCollapseTimer;
  bool _displayTapped = false;
  bool _wasLoading = false;
  VideoPlayerController? _controller;
  BetterPlayerController? _betterPlayerController;
  StreamSubscription? _controlsVisibilityStreamSubscription;

  BetterPlayerControlsConfiguration get _controlsConfiguration =>
      widget.controlsConfiguration;

  @override
  VideoPlayerValue? get latestValue => _latestValue;

  @override
  BetterPlayerController? get betterPlayerController => _betterPlayerController;

  @override
  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration =>
      _controlsConfiguration;

  @override
  Widget build(BuildContext context) {
    return buildLTRDirectionality(_buildMainWidget());
  }

  ///Builds main widget of the controls.
  Widget _buildMainWidget() {
    _wasLoading = isLoading(_latestValue);
    if (_latestValue?.hasError == true) {
      return Container(
        color: Colors.black,
        child: _buildErrorWidget(),
      );
    }
    return GestureDetector(
      onTap: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onTap?.call();
        }
        controlsNotVisible
            ? cancelAndRestartTimer()
            : changePlayerControlsNotVisible(true);
      },
      onDoubleTap: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onDoubleTap?.call();
        }
        cancelAndRestartTimer();
      },
      onLongPress: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onLongPress?.call();
        }
      },
      child: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_wasLoading) Center(child: _buildLoadingWidget()),
            Align(
              alignment: Alignment.topCenter,
              child: AnimatedOpacity(
                opacity: controlsNotVisible ? 0.0 : 0.8,
                duration: _controlsConfiguration.controlsHideTime,
                child: Container(
                  height: _controlsConfiguration.controlBarHeight + 60.0,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black, Colors.transparent],
                      stops: [0, 0.90],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: AnimatedOpacity(
                opacity: controlsNotVisible ? 0.0 : 0.1,
                duration: _controlsConfiguration.controlsHideTime,
                child: Container(
                  height: _controlsConfiguration.controlBarHeight + 180.0,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.transparent],
                      stops: [0, 0.01],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedOpacity(
                opacity: controlsNotVisible ? 0.0 : 0.8,
                duration: _controlsConfiguration.controlsHideTime,
                child: Container(
                  height: _controlsConfiguration.controlBarHeight + 50.0,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black],
                      stops: [0, 0.99],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            _buildTopBar(),
            _buildBottomBar(),
            _buildPlayPauseButton(_controller!),
            _buildVolumeSlider(),
            _showSubtitlesListModal()
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return Align(
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        onEnd: _onPlayerHide,
        child: SafeArea(
          child: Container(
            height: 80,
            width: MediaQuery.of(context).size.width,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            "assets/loading_icon.png",
                            scale: 12.0,
                            fit: BoxFit.fitWidth,
                            color: Colors.white,
                          ),
                          Image.asset(
                            "assets/loading_icon.png",
                            scale: 12.0,
                            fit: BoxFit.fitWidth,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _controlsConfiguration.movieName,
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _controlsConfiguration.directorsName,
                          textAlign: TextAlign.start,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildIosAirPlayButton(),
                    _buildClosePlayerButton(),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIosAirPlayButton() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    if (Platform.isAndroid) {
      return const SizedBox();
    }

    return Container(
      child: Stack(
        children: [
          Center(
            child: Icon(Icons.airplay_outlined, color: Colors.white, size: 26),
          ),
          GestureDetector(
            child: AirPlayRoutePickerView(
              height: 48,
              width: 48,
              tintColor: Colors.transparent,
              activeTintColor: Colors.transparent,
              backgroundColor: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosePlayerButton() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () async {
          if (_controlsConfiguration.onPlayerCloses != null) {
            Duration? endTime = await _controller!.position;
            _controlsConfiguration
                .onPlayerCloses!(endTime?.inSeconds.toDouble() ?? 0.0);
          }
          Navigator.of(context).pop();
          Navigator.of(context).pop();
          dispose();
        },
        child: SvgPicture.asset(
          "assets/close-button.svg",
          semanticsLabel: "close.svg",
          height: 24,
          width: 24,
          color: Colors.white,
          placeholderBuilder: (context) => Icon(Icons.error_rounded),
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton(VideoPlayerController controller) {
    if (!betterPlayerController!.controlsEnabled || _wasLoading) {
      return const SizedBox();
    }

    return Container(
      alignment: Alignment.center,
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        onEnd: _onPlayerHide,
        child: InkWell(
          onTap: _onPlayPause,
          child: Icon(
            controller.value.isPlaying ? Icons.pause : Icons.play_arrow_rounded,
            color: _controlsConfiguration.iconsColor,
            size: MediaQuery.of(context).size.width * .088,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        onEnd: _onPlayerHide,
        child: SafeArea(
          child: Container(
            height: 70,
            width: MediaQuery.of(context).size.width,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                if (_betterPlayerController!.isLiveStream())
                  const SizedBox()
                else
                  _controlsConfiguration.enableProgressBar
                      ? _buildProgressBar()
                      : const SizedBox(),
                Expanded(
                  flex: 75,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width * .12,
                        child: Row(
                          children: [
                            if (_controlsConfiguration.enableMute)
                              _buildVolumeButton(_controller)
                            else
                              const SizedBox(),
                          ],
                        ),
                      ),
                      _buildSubtitleIcon()
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeButton(VideoPlayerController? controller) {
    return InkWell(
      onTap: () {
        cancelAndRestartTimer();
        changeVolumeSliderControlsNotVisible(!volumeSliderNotVisible);
      },
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRect(
          child: Container(
            height: _controlsConfiguration.controlBarHeight,
            margin: const EdgeInsets.only(left: 8, top: 4),
            child: Icon(
              (_latestValue != null && _latestValue!.volume > 0)
                  ? Icons.volume_up_sharp
                  : _controlsConfiguration.unMuteIcon,
              color: _controlsConfiguration.iconsColor,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitleIcon() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () {
          cancelAndRestartTimer();
          changeSubtitleModalControlsNotVisible(!subtitleModalNotVisible);
        },
        child: Icon(
          Icons.subtitles_outlined,
          size: 31,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildVolumeSlider() {
    return Positioned(
      height: MediaQuery.of(context).size.height * .4,
      bottom: MediaQuery.of(context).size.height * .16,
      left: MediaQuery.of(context).size.width * .004,
      child: SafeArea(
        child: AnimatedOpacity(
          opacity: volumeSliderNotVisible ? 0.0 : 1.0,
          duration: _controlsConfiguration.controlsHideTime,
          child: RotatedBox(
            quarterTurns: 3,
            child: Container(
              alignment: Alignment.centerLeft,
              width: MediaQuery.of(context).size.width * .20,
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8)),
              child: Slider(
                value: _latestVolume,
                min: 0,
                max: 1.0,
                inactiveColor: Colors.grey.withOpacity(0.6),
                activeColor: Colors.white,
                onChanged: (volume) {
                  _betterPlayerController!.setVolume(volume);
                  _latestVolume = _betterPlayerController!
                      .videoPlayerController!.value.volume;
                  setState(() {});
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _showSubtitlesListModal() {
    if (subtitleModalNotVisible) {
      return Container();
    } else {
      final subtitles =
          List.of(betterPlayerController!.betterPlayerSubtitlesSourceList);
      final noneSubtitlesElementExists = subtitles.firstWhereOrNull((source) =>
              source.type == BetterPlayerSubtitlesSourceType.none) !=
          null;
      if (!noneSubtitlesElementExists) {
        subtitles.add(BetterPlayerSubtitlesSource(
          type: BetterPlayerSubtitlesSourceType.none,
        ));
      }

      return Positioned(
        bottom: MediaQuery.of(context).size.height * .16,
        right: MediaQuery.of(context).size.width * .04,
        child: SingleChildScrollView(
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(top: 8, left: 8, bottom: 8),
            width: MediaQuery.of(context).size.width * .25,
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: const Text("Legendas/CC",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                Column(
                  children: _buildSubtitleOptions(subtitles),
                )
              ],
            ),
          ),
        ),
      );
    }
  }

  List<Widget> _buildSubtitleOptions(
      List<BetterPlayerSubtitlesSource> subtitlesSourceList) {
    List<Widget> subtitleOptions = [];

    for (BetterPlayerSubtitlesSource subtitlesSource in subtitlesSourceList) {
      final selectedSourceType =
          betterPlayerController!.betterPlayerSubtitlesSource;
      final bool isSelected = (subtitlesSource == selectedSourceType) ||
          (subtitlesSource.type == BetterPlayerSubtitlesSourceType.none &&
              subtitlesSource.type == selectedSourceType!.type);

      subtitleOptions.add(Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        child: GestureDetector(
          onTap: () {
            betterPlayerController!.setupSubtitleSource(subtitlesSource);
          },
          child: Row(
            children: [
              Visibility(
                  visible: isSelected,
                  child: Icon(
                    Icons.check_outlined,
                    color: isSelected ? Colors.white : Colors.transparent,
                  )),
              Container(
                margin: const EdgeInsets.only(left: 4, right: 4),
                child: Text(
                  subtitlesSource.type == BetterPlayerSubtitlesSourceType.none
                      ? "Desligadas"
                      : "Português (Brasil)",
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                ),
              )
            ],
          ),
        ),
      ));
    }

    return subtitleOptions;
  }

  Widget _buildProgressBar() {
    return Expanded(
      flex: 40,
      child: Container(
        alignment: Alignment.bottomCenter,
        margin: const EdgeInsets.only(left: 8, right: 16),
        child: BetterPlayerMaterialVideoProgressBar(
          _controller,
          _betterPlayerController,
          onDragStart: () {
            _hideTimer?.cancel();
          },
          onDragEnd: () {
            _startHideTimer();
          },
          onTapDown: () {
            cancelAndRestartTimer();
          },
          colors: BetterPlayerProgressColors(
              playedColor: _controlsConfiguration.progressBarPlayedColor,
              handleColor: _controlsConfiguration.progressBarHandleColor,
              bufferedColor: _controlsConfiguration.progressBarBufferedColor,
              backgroundColor:
                  _controlsConfiguration.progressBarBackgroundColor),
        ),
      ),
    );
  }

  Widget? _buildLoadingWidget() {
    if (_controlsConfiguration.loadingWidget != null) {
      return Container(
        color: _controlsConfiguration.controlBarColor,
        child: _controlsConfiguration.loadingWidget,
      );
    }

    return CircularProgressIndicator(
      valueColor:
          AlwaysStoppedAnimation<Color>(_controlsConfiguration.loadingColor),
    );
  }

  Widget _buildErrorWidget() {
    final errorBuilder =
        _betterPlayerController!.betterPlayerConfiguration.errorBuilder;
    if (errorBuilder != null) {
      return errorBuilder(
          context,
          _betterPlayerController!
              .videoPlayerController!.value.errorDescription);
    } else {
      final textStyle = TextStyle(color: _controlsConfiguration.textColor);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning,
              color: _controlsConfiguration.iconsColor,
              size: 42,
            ),
            Text(
              _betterPlayerController!.translations.generalDefaultError,
              style: textStyle,
            ),
            if (_controlsConfiguration.enableRetry)
              TextButton(
                onPressed: () {
                  _betterPlayerController!.retryDataSource();
                },
                child: Text(
                  _betterPlayerController!.translations.generalRetry,
                  style: textStyle.copyWith(fontWeight: FontWeight.bold),
                ),
              )
          ],
        ),
      );
    }
  }

  Widget _buildHitAreaClickableButton(
      {Widget? icon, required void Function() onClicked}) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 80.0, maxWidth: 80.0),
      child: BetterPlayerMaterialClickableWidget(
        onTap: onClicked,
        child: Align(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(48),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Stack(
                children: [icon!],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplayButton(VideoPlayerController controller) {
    final bool isFinished = isVideoFinished(_latestValue);
    return _buildHitAreaClickableButton(
      icon: isFinished
          ? Icon(
              Icons.replay,
              size: 42,
              color: _controlsConfiguration.iconsColor,
            )
          : Icon(
              controller.value.isPlaying
                  ? Icons.pause
                  : Icons.play_arrow_rounded,
              size: 42,
              color: _controlsConfiguration.iconsColor,
            ),
      onClicked: () {
        if (isFinished) {
          if (_latestValue != null && _latestValue!.isPlaying) {
            if (_displayTapped) {
              changePlayerControlsNotVisible(true);
            } else {
              cancelAndRestartTimer();
            }
          } else {
            _onPlayPause();
            changePlayerControlsNotVisible(true);
          }
        } else {
          _onPlayPause();
        }
      },
    );
  }

  @override
  void cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    changePlayerControlsNotVisible(false);
    _displayTapped = true;
  }

  Future<void> _initialize() async {
    _controller!.addListener(_updateState);

    _updateState();

    if ((_controller!.value.isPlaying) ||
        _betterPlayerController!.betterPlayerConfiguration.autoPlay) {
      _startHideTimer();
    }

    if (_controlsConfiguration.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        changePlayerControlsNotVisible(false);
      });
    }

    _controlsVisibilityStreamSubscription =
        _betterPlayerController!.controlsVisibilityStream.listen((state) {
      changePlayerControlsNotVisible(!state);
      if (!controlsNotVisible) {
        cancelAndRestartTimer();
      }
    });
  }

  void _onPlayPause() {
    bool isFinished = false;

    if (_latestValue?.position != null && _latestValue?.duration != null) {
      isFinished = _latestValue!.position >= _latestValue!.duration!;
    }

    if (_controller!.value.isPlaying) {
      changePlayerControlsNotVisible(false);
      _hideTimer?.cancel();
      _betterPlayerController!.pause();
    } else {
      cancelAndRestartTimer();

      if (!_controller!.value.initialized) {
      } else {
        if (isFinished) {
          _betterPlayerController!.seekTo(const Duration());
        }
        _betterPlayerController!.play();
        _betterPlayerController!.cancelNextVideoTimer();
      }
    }
  }

  void _onPlayerHide() {
    _betterPlayerController!.toggleControlsVisibility(!controlsNotVisible);
    widget.onControlsVisibilityChanged(!controlsNotVisible);
  }

  void _startHideTimer() {
    if (_betterPlayerController!.controlsAlwaysVisible) {
      return;
    }
    _hideTimer = Timer(const Duration(milliseconds: 7000), () {
      changePlayerControlsNotVisible(true);
    });
  }

  void _updateState() {
    if (mounted) {
      if (!controlsNotVisible ||
          isVideoFinished(_controller!.value) ||
          _wasLoading ||
          isLoading(_controller!.value)) {
        setState(() {
          _latestValue = _controller!.value;
          if (isVideoFinished(_latestValue) &&
              _betterPlayerController?.isLiveStream() == false) {
            changePlayerControlsNotVisible(false);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    _controller?.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
    _controlsVisibilityStreamSubscription?.cancel();
  }

  @override
  void didChangeDependencies() {
    final _oldController = _betterPlayerController;
    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;
    _latestValue = _controller!.value;

    if (_oldController != _betterPlayerController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }
}
