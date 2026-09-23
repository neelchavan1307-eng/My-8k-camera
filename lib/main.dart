import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

late List<CameraDescription> _cameras;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: CameraScreen());
  }
}
class CameraScreen extends StatefulWidget {
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}
class _CameraScreenState extends State<CameraScreen> {
  late CameraController controller;
  @override
  void initState() {
    super.initState();
    controller = CameraController(_cameras[0], ResolutionPreset.ultraHigh);
    controller.initialize().then((_) { if(mounted) setState((){}); });
  }
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) return Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(body: CameraPreview(controller), floatingActionButton: FloatingActionButton(onPressed: () async { await controller.takePicture(); }, child: Icon(Icons.camera)));
  }
}2
