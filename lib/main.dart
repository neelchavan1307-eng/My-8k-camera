import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.camera.request();
  try { cameras = await availableCameras(); } catch(e){}
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.dark(), home: const CameraScreen());
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  bool isRear = true;

  @override
  void initState() { super.initState(); initCamera(); }

  Future<void> initCamera() async {
    if (cameras.isEmpty) return;
    int idx = isRear? 0 : (cameras.length > 1? 1 : 0);
    controller = CameraController(cameras[idx], ResolutionPreset.ultraHigh, enableAudio: false);
    await controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() { controller?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('8K Camera - Ultra HD')),
      body: controller == null ||!controller!.value.isInitialized
       ? const Center(child: CircularProgressIndicator())
          : Stack(children: [
              SizedBox.expand(child: CameraPreview(controller!)),
              Positioned(bottom: 30, left: 0, right: 0,
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  IconButton(icon: const Icon(Icons.switch_camera, size: 40), onPressed: (){ setState(()=> isRear =!isRear); initCamera(); }),
                  GestureDetector(
                    onTap: () async { final f = await controller!.takePicture(); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: ${f.path}'))); },
                    child: Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.red, width: 4))),
                  ),
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: const Text('8K', style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold))),
                ]),
              )
            ]),
    );
  }
}
