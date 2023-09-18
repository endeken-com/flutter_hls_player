import 'package:better_player/better_player.dart';
import 'package:better_player_example/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NormalPlayerPage extends StatefulWidget {
  @override
  _NormalPlayerPageState createState() => _NormalPlayerPageState();
}

class _NormalPlayerPageState extends State<NormalPlayerPage> {
  late BetterPlayerController _betterPlayerController;
  late BetterPlayerDataSource _betterPlayerDataSource;

  @override
  void initState() {
    final String _filmefilmeTrailerUrl = "https://76vod-adaptive.akamaized.net/exp=1695074865~acl=%2F79bf09ea-3ff0-4745-829b-3b506ede6023%2F%2A~hmac=d714ad533d7ece8e8a525a2cae72057ea634e6fedc6db4276bdd8c207760a3aa/79bf09ea-3ff0-4745-829b-3b506ede6023/sep/video/3fbaa12d,44a95e9b,6e293a03,72880436/audio/c0d68610/master.m3u8?absolute=1&query_string_ranges=1";
    String _normalPlayerUrl = Constants.forBiggerBlazesUrl;

    BetterPlayerConfiguration betterPlayerConfiguration =
        BetterPlayerConfiguration(
      aspectRatio: 16 / 2,
      fit: BoxFit.contain,
      autoPlay: true,
      looping: true,
      expandToFill: false,
      controlsConfiguration: BetterPlayerControlsConfiguration(
        movieName: "AAAAAAAAAA BBBBBBBBBBB AAAAAAAA AAAA ",
        showControlsOnInitialize: false,
        onPlayerCloses: (currentTime) {
          print(currentTime);
        },
        directorsName: "Brasília verde água",
        progressBarPlayedColor: Color(0xffbbfa34),
        closeButtonIcon: SvgPicture.asset("assets/close-button.svg",
            color: Colors.white, height: 8, width: 8, fit: BoxFit.fitWidth),
      ),
      fullScreenByDefault: true,
    );
    _betterPlayerDataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      _filmefilmeTrailerUrl,
    );
    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _betterPlayerController.setupDataSource(_betterPlayerDataSource);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Normal player page"),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(controller: _betterPlayerController),
          ),
        ],
      ),
    );
  }
}
