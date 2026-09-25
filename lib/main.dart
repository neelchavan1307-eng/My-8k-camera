import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraPage(),
    );
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? controller;
  bool isReady = false;
  bool isPhoto = true;
  bool isRecording = false;
  double zoom = 1.0;

  @override
  void initState() {
    super.initState();
    initCam();
  }

  Future<void> initCam() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    await Permission.photos.request();
    await Permission.storage.request();

    controller = CameraController(cameras[0], ResolutionPreset.ultraHigh, enableAudio: true);
    await controller!.initialize();
    // BLEACH FIX
    await controller!.setExposureMode(ExposureMode.auto);
    await controller!.setFocusMode(FocusMode.auto);
    await controller!.setExposureOffset(0.0);
    await controller!.setFlashMode(FlashMode.off);

    setState(() => isReady = true);
  }

  Future<void> takePhoto() async {
    if (controller == null ||!controller!.value.isInitialized) return;
    try {
      final XFile file = await controller!.takePicture();
      await Gal.putImage(file.path);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo Saved ✅ Gallery madhe bagh')));
    } catch (e) {
      print("Photo Error: $e");
    }
  }

  Future<void> toggleVideo() async {
    if (controller == null) return;
    if (isRecording) {
      final XFile file = await controller!.stopVideoRecording();
      await Gal.putVideo(file.path);
      setState(() => isRecording = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video Saved ✅')));
    } else {
      await controller!.startVideoRecording();
      setState(() => isRecording = true);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isReady || controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SizedBox.expand(child: CameraPreview(controller!)),
          // Top Bar
          SafeArea(child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(5)), child: const Text("HD", style: TextStyle(color: Colors.white))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(5)), child: const Text("1080 30", style: TextStyle(color: Colors.white))),
            ]),
          )),
          // Bottom Controls
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 30, top: 10),
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent])),
              child: Column(
                children: [
                  // Zoom
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var z in [0.6, 1, 2, 4]) GestureDetector(
                      onTap: () async { await controller!.setZoomLevel(z); setState(()=> zoom=z); },
                      child: Container(margin: const EdgeInsets.symmetric(horizontal: 5), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: zoom==z? Colors.white : Colors.white24, borderRadius: BorderRadius.circular(20)), child: Text("${z}x", style: TextStyle(color: zoom==z? Colors.black : Colors.white, fontWeight: FontWeight.bold))),
                    )
                  ]),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TextButton(onPressed: ()=> setState(()=> isPhoto=false), child: Text("Ultra HD", style: TextStyle(color:!isPhoto? Colors.yellow : Colors.white70))),
                    TextButton(onPressed: ()=> setState(()=> isPhoto=false), child: Text("Video", style: TextStyle(color:!isPhoto? Colors.yellow : Colors.white70))),
                    TextButton(onPressed: ()=> setState(()=> isPhoto=true), child: Text("Photo", style: TextStyle(color: isPhoto? Colors.yellow : Colors.white70, fontWeight: FontWeight.bold))),
                    const Text("Portrait Night", style: TextStyle(color: Colors.white70)),
                  ]),
                  const SizedBox(height: 5),
                  // Shutter
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    const SizedBox(width: 60),
                    GestureDetector(
                      onTap: () => isPhoto? takePhoto() : toggleVideo(),
                      child: Container(width: 80, height: 80, decoration: BoxDecoration(color: isRecording? Colors.red : Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)), child: Icon(isPhoto? Icons.camera_alt : (isRecording? Icons.stop : Icons.videocam), size: 40, color: Colors.black)),
                    ),
                    Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.photo, color: Colors.white)),
                  ])
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
