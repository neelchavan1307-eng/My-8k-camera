import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(KillerCamApp());
}

class KillerCamApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: CameraPage());
  }
}

class CameraPage extends StatefulWidget {
  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? controller;
  int selectedFilter = 0;
  bool isRecording = false;
  double beauty = 8;
  String quality = "4K";

  List<String> filters = ["Original", "RRR", "KGF", "Cinematic", "DSLR"];
  List<ColorFilter> filterColors = [
    ColorFilter.mode(Colors.transparent, BlendMode.multiply),
    ColorFilter.mode(Colors.orange.withOpacity(0.3), BlendMode.color),
    ColorFilter.mode(Colors.amber.withOpacity(0.4), BlendMode.saturation),
    ColorFilter.mode(Colors.brown.withOpacity(0.3), BlendMode.color),
    ColorFilter.mode(Colors.white.withOpacity(0.15), BlendMode.softLight),
  ];

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  initCamera() async {
    controller = CameraController(cameras[0], ResolutionPreset.ultraHigh, enableAudio: true);
    await controller!.initialize();
    if (mounted) setState(() {});
  }

  takePhoto() async {
    if (controller == null ||!controller!.value.isInitialized) return;
    try {
      XFile file = await controller!.takePicture();
      // FIX: Direct Gallery Save
      await Gal.putImage(file.path, album: "KillerCam");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Photo Saved to Gallery - KillerCam! 🔥")));
    } catch (e) {
      print(e);
    }
  }

  recordVideo() async {
    if (isRecording) {
      XFile file = await controller!.stopVideoRecording();
      setState(() => isRecording = false);
      await Gal.putVideo(file.path, album: "KillerCam");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("🎥 Video Saved to Gallery!")));
    } else {
      await controller!.startVideoRecording();
      setState(() => isRecording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null ||!controller!.value.isInitialized) {
      return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ColorFiltered(
            colorFilter: filterColors[selectedFilter],
            child: CameraPreview(controller!),
          ),
          // Top Bar
          Positioned(top: 40, left: 20, right: 20, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text("KILLER • $quality • 1.0x", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            Icon(Icons.flash_on, color: Colors.white),
          ])),
          // Filters
          Positioned(bottom: 180, left: 0, right: 0, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: List.generate(filters.length, (i) => GestureDetector(onTap: () => setState(() => selectedFilter = i), child: Container(margin: EdgeInsets.symmetric(horizontal: 8), padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8), decoration: BoxDecoration(color: selectedFilter==i? Colors.white : Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text(filters[i], style: TextStyle(color: selectedFilter==i? Colors.black : Colors.white, fontWeight: FontWeight.bold)))))))),
          // Beauty Slider
          Positioned(right: 10, top: 200, bottom: 200, child: RotatedBox(quarterTurns: 3, child: Slider(value: beauty, min: 0, max: 100, activeColor: Colors.yellow, onChanged: (v) => setState(() => beauty = v)))),
          // Bottom Controls
          Positioned(bottom: 20, left: 20, right: 20, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(onTap: () => Gal.open(), child: Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.photo, color: Colors.black))),
            GestureDetector(onTap: takePhoto, onLongPress: recordVideo, child: Container(width: 80, height: 80, decoration: BoxDecoration(color: isRecording? Colors.red : Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 4)))),
            IconButton(icon: Icon(Icons.cameraswitch, color: Colors.white, size: 35), onPressed: () {}),
          ])),
        ],
      ),
    );
  }
}
