import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:audioplayers/audioplayers.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const KillerApp());
}

class KillerApp extends StatelessWidget {
  const KillerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: KillerCamScreen(),
    );
  }
}

class KillerCamScreen extends StatefulWidget {
  @override
  State<KillerCamScreen> createState() => _KillerCamScreenState();
}

class _KillerCamScreenState extends State<KillerCamScreen> {
  CameraController? _controller;
  bool _isRecording = false;
  bool _isPhotoMode = true;
  int _recordSeconds = 0;
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();

  String _selectedMode = "Photo"; // Ultra HD, Video, Photo, Portrait, Cinematic
  String _selectedFilter = "Original";

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    _controller = CameraController(cameras[0], ResolutionPreset.ultraHigh,
        enableAudio: true, imageFormatGroup: ImageFormatGroup.yuv420);
    await _controller!.initialize();
    // BRIGHTNESS FIX - Photo mode la suruvatila auto exposure
    await _controller!.setExposureMode(ExposureMode.auto);
    await _controller!.setFocusMode(FocusMode.auto);
    await _controller!.setExposureOffset(0.0);
    if (mounted) setState(() {});
  }

  // PHOTO CLICK - SOUND FIX
  Future<void> takePhoto() async {
    try {
      // Sound
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('sounds/click.mp3')).catchError((_) async {
        // jar file nasel tar system sound
        await _audioPlayer.play(UrlSource('https://cdn.pixabay.com/audio/2022/03/24/audio_1a2a2b2c2d.mp3')).catchError((e){});
      });

      final file = await _controller!.takePicture();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚡ KATAK! Photo Saved'), duration: Duration(milliseconds: 800)),
      );
    } catch (e) {
      print(e);
    }
  }

  // VIDEO START - BRIGHTNESS + SOUND + TIMING FIX
  Future<void> startVideo() async {
    try {
      // BRIGHTNESS FIX - Video chalu kartana exposure reset
      await _controller!.setExposureMode(ExposureMode.auto);
      await _controller!.setExposureOffset(0.0);
      await _controller!.setFocusMode(FocusMode.auto);

      // SOUND FIX
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('sounds/start.mp3')).catchError((_) {});

      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });

      // TIMING FIX - Timer chalu
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordSeconds++;
          });
        }
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> stopVideo() async {
    try {
      _timer?.cancel();
      final file = await _controller!.stopVideoRecording();

      // BRIGHTNESS FIX - Band kelyavar parat auto
      await _controller!.setExposureMode(ExposureMode.auto);
      await _controller!.setExposureOffset(0.0);

      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video Saved')),
      );
    } catch (e) {
      print(e);
    }
  }

  String get timerText {
    int m = _recordSeconds ~/ 60;
    int s = _recordSeconds % 60;
    return "${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}";
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null ||!_controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.yellow)));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // CAMERA
          SizedBox.expand(child: CameraPreview(_controller!)),

          // TOP BAR
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                // KILLER CAM + TIMER
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("KILLER CAM • 1.0x", style: TextStyle(fontWeight: FontWeight.bold)),
                        if (_isRecording)...[
                          const SizedBox(width: 10),
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text(timerText, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ]
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Modes
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ["Ultra HD", "Video", "Photo", "Portrait", "Cinematic"].map((mode) {
                      bool selected = _selectedMode == mode;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedMode = mode),
                        child: Container(
                          margin: EdgeInsets.only(left: 8),
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected? Colors.white : Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(mode, style: TextStyle(color: selected? Colors.black : Colors.white, fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                // Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ["Original", "KGF", "RRR", "Vivid", "B&W"].map((f) {
                      bool sel = _selectedFilter == f;
                      return Container(
                        margin: EdgeInsets.only(left: 8),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: sel? Colors.amber : Colors.black54,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(f, style: TextStyle(color: sel? Colors.black : Colors.white, fontSize: 11)),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // BOTTOM
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.flash_off, color: Colors.white)),
                  // SHUTTER BUTTON
                  GestureDetector(
                    onTap: () {
                      if (_selectedMode == "Photo") {
                        takePhoto();
                      } else {
                        if (_isRecording) stopVideo(); else startVideo();
                      }
                    },
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: _isRecording? Colors.red : Colors.white,
                      ),
                      child: Icon(_isRecording? Icons.stop : Icons.circle, color: _isRecording? Colors.white : Colors.red, size: 50),
                    ),
                  ),
                  CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.cameraswitch, color: Colors.white)),
                ],
              ),
            ),
          ),
          // Zoom text
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Center(child: Text("1.0x", style: TextStyle(color: Colors.white))),
          )
        ],
      ),
    );
  }
}1
