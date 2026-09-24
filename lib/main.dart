import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:io';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: CameraScreen(), debugShowCheckedModeBanner: false);
  }
}

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController controller;
  bool isReady = false;
  String? lastImagePath;

  @override
  void initState() { super.initState(); initCamera(); }

  Future<void> initCamera() async {
    await Permission.camera.request();
    await Permission.storage.request();
    await Permission.photos.request();
    controller = CameraController(cameras[0], ResolutionPreset.ultraHigh);
    await controller.initialize();
    setState(() => isReady = true);
  }

  Future<void> takePicture() async {
    final image = await controller.takePicture();
    await ImageGallerySaver.saveFile(image.path);
    setState(() { lastImagePath = image.path; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gallery madhe Save Zala!')));
  }

  @override
  Widget build(BuildContext context) {
    if (!isReady) return Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(body: Stack(children: [
      CameraPreview(controller),
      Positioned(bottom: 30, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        Container(width: 60, height: 60, decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(10)), child: lastImagePath!=null?ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(lastImagePath!), fit: BoxFit.cover)):Icon(Icons.photo, color: Colors.white)),
        GestureDetector(onTap: takePicture, child: Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(width: 4, color: Colors.grey)))),
        SizedBox(width: 60),
      ])),
    ]));
  }
}
