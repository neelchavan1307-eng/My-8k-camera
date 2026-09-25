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
    await controller!.setExposureMode(ExposureMode.auto);
    await controller!.setFocusMode(FocusMode.auto);
    await controller!.setExposureOffset(0.0);
    await controller!.setFlashMode(FlashMode.off);
    setState(() => isReady = true);
  }

  Future<void> takePhoto() async {
    if (controller == null ||!controller!.value.isInitialized) return;
    final XFile file = await controller!.takePicture();
    await Gal.putImage(file.path);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo Saved ✅')));
  }

  Future<void> toggleVideo() async {
    if (controller == null) return;
    if (isRecording) {
      final XFile file = await controller!.stopVideoRecording();
      await Gal.putVideo(file.path);
      setState(() => isRecording = false);
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
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 30, top: 10),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (double z in [0.6, 1.0, 2.0, 4.0])
                      GestureDetector(
                        onTap: () async {
                          await controller!.setZoomLevel(z);
                          setState(() => zoom = z);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: zoom == z? Colors.white : Colors.white24, borderRadius: BorderRadius.circular(20)),
                          child: Text("${z}x", style: TextStyle(color: zoom == z? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      )
                  ]),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => isPhoto? takePhoto() : toggleVideo(),
                    child: Container(width: 80, height: 80, decoration: BoxDecoration(color: isRecording? Colors.red : Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)), child: Icon(isPhoto? Icons.camera_alt : (isRecording? Icons.stop : Icons.videocam), size: 40, color: Colors.black)),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
