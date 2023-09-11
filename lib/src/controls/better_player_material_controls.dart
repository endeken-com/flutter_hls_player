import 'dart:async';
import 'dart:io';
import 'package:better_player/src/configuration/better_player_controls_configuration.dart';
import 'package:better_player/src/controls/better_player_clickable_widget.dart';
import 'package:better_player/src/controls/better_player_controls_state.dart';
import 'package:better_player/src/controls/better_player_material_progress_bar.dart';
import 'package:better_player/src/controls/better_player_multiple_gesture_detector.dart';
import 'package:better_player/src/controls/better_player_progress_colors.dart';
import 'package:better_player/src/core/better_player_controller.dart';
import 'package:better_player/src/core/better_player_utils.dart';
import 'package:better_player/src/subtitles/better_player_subtitles_source_type.dart';
import 'package:better_player/src/video_player/video_player.dart';
import 'package:collection/collection.dart';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      child: AbsorbPointer(
        absorbing: controlsNotVisible,
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
            _buildReturnButton(),
            _buildIosAirPlayButton(),
            _buildBottomBar(),
            _buildVolumeSlider(),
            _showSubtitlesListModal()
          ],
        ),
      ),
    );
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

  Widget _buildTopBar() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    return Container(
      child: (_controlsConfiguration.enableOverflowMenu)
          ? AnimatedOpacity(
              opacity: controlsNotVisible ? 0.0 : 1.0,
              duration: _controlsConfiguration.controlsHideTime,
              onEnd: _onPlayerHide,
              child: Container(
                height: _controlsConfiguration.controlBarHeight,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_controlsConfiguration.enablePip)
                      _buildPipButtonWrapperWidget(
                          controlsNotVisible, _onPlayerHide)
                    else
                      const SizedBox(),
                    _buildMoreButton(),
                  ],
                ),
              ),
            )
          : const SizedBox(),
    );
  }

  Widget _buildPipButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        betterPlayerController!.enablePictureInPicture(
            betterPlayerController!.betterPlayerGlobalKey!);
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          betterPlayerControlsConfiguration.pipMenuIcon,
          color: betterPlayerControlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildPipButtonWrapperWidget(
      bool hideStuff, void Function() onPlayerHide) {
    return FutureBuilder<bool>(
      future: betterPlayerController!.isPictureInPictureSupported(),
      builder: (context, snapshot) {
        final bool isPipSupported = snapshot.data ?? false;
        if (isPipSupported &&
            _betterPlayerController!.betterPlayerGlobalKey != null) {
          return AnimatedOpacity(
            opacity: hideStuff ? 0.0 : 1.0,
            duration: betterPlayerControlsConfiguration.controlsHideTime,
            onEnd: onPlayerHide,
            child: Container(
              height: betterPlayerControlsConfiguration.controlBarHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildPipButton(),
                ],
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  Widget _buildMoreButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        onShowMoreClicked();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          _controlsConfiguration.overflowMenuIcon,
          color: _controlsConfiguration.iconsColor,
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
        child: Container(
          height: _controlsConfiguration.controlBarHeight + 30.0,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Colors.black],
              stops: [0, 0.99],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8),
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
                            if (_controlsConfiguration.enablePlayPause)
                              _buildPlayPause(_controller!)
                            else
                              const SizedBox(),
                            const Spacer(),
                            if (_controlsConfiguration.enableMute)
                              _buildMuteButton(_controller)
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
            type: BetterPlayerSubtitlesSourceType.none));
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

  Widget _buildMuteButton(
    VideoPlayerController? controller,
  ) {
    return BetterPlayerMaterialClickableWidget(
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
              size: MediaQuery.of(context).orientation == Orientation.portrait
                  ? 114
                  : 30,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeSlider() {
    return Positioned(
      height: MediaQuery.of(context).size.height * .4,
      bottom: MediaQuery.of(context).size.height * .16,
      left: MediaQuery.of(context).size.width * .1,
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
    );
  }

  Widget _buildIosAirPlayButton() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    if (Platform.isAndroid) {
      return const SizedBox();
    }

    return Positioned(
      top: MediaQuery.of(context).size.height * .02,
      right: MediaQuery.of(context).size.width * .024,
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        onEnd: _onPlayerHide,
        child: Container(
          child: Stack(
            children: [
              Icon(Icons.airplay_outlined, color: Colors.white),
              AirPlayRoutePickerView(
                height: 48,
                width: 48,
                tintColor: Colors.transparent,
                activeTintColor: Colors.transparent,
                backgroundColor: Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPause(VideoPlayerController controller) {
    return BetterPlayerMaterialClickableWidget(
      key: const Key("better_player_material_controls_play_pause_button"),
      onTap: _onPlayPause,
      child: Container(
        height: double.infinity,
        alignment: Alignment.centerLeft,
        child: Icon(
          controller.value.isPlaying ? Icons.pause : Icons.play_arrow_rounded,
          color: _controlsConfiguration.iconsColor,
          size: MediaQuery.of(context).size.width * .045,
        ),
      ),
    );
  }

  Widget _buildPosition() {
    final position =
        _latestValue != null ? _latestValue!.position : Duration.zero;
    final duration = _latestValue != null && _latestValue!.duration != null
        ? _latestValue!.duration!
        : Duration.zero;

    return Padding(
      padding: _controlsConfiguration.enablePlayPause
          ? const EdgeInsets.only(right: 24)
          : const EdgeInsets.symmetric(horizontal: 22),
      child: RichText(
        text: TextSpan(
            text: BetterPlayerUtils.formatDuration(position),
            style: TextStyle(
              fontSize: 10.0,
              color: _controlsConfiguration.textColor,
              decoration: TextDecoration.none,
            ),
            children: <TextSpan>[
              TextSpan(
                text: ' / ${BetterPlayerUtils.formatDuration(duration)}',
                style: TextStyle(
                  fontSize: 10.0,
                  color: _controlsConfiguration.textColor,
                  decoration: TextDecoration.none,
                ),
              )
            ]),
      ),
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

  void _startHideTimer() {
    if (_betterPlayerController!.controlsAlwaysVisible) {
      return;
    }
    _hideTimer = Timer(const Duration(milliseconds: 3000), () {
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

  void _onPlayerHide() {
    _betterPlayerController!.toggleControlsVisibility(!controlsNotVisible);
    widget.onControlsVisibilityChanged(!controlsNotVisible);
  }

  Widget _buildReturnButton() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    return Positioned(
      top: MediaQuery.of(context).size.height * .05,
      left: MediaQuery.of(context).size.width * .026,
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        onEnd: _onPlayerHide,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: InkWell(
            onTap: () {
              dispose();
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Icon(Icons.arrow_back_ios, size: 28, color: Colors.white),
          ),
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
}
