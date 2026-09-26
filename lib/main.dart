import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> allCams = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  allCams = await availableCameras();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: KillerCamera(),
  ));
}

class KillerCamera extends StatefulWidget {
  const KillerCamera({super.key});
  @override
  State<KillerCamera> createState() => _KillerCameraState();
}

class _KillerCameraState extends State<KillerCamera> {
  CameraController? controller;
  bool isReady = false;
  bool isRec = false;
  double zoom = 1.0;
  String mode = "Photo";
  String filter = "Original";
  int sec = 0;
  Timer? t;
  bool flashOn = false;

  List<String> modes = ["Ultra HD","Video","Photo","Portrait","Cinematic","Night"];
  List<String> filters = ["Original","KGF","RRR","Dune","Vivid","B&W"];

  @override
  void initState() {
    super.initState();
    initCam();
  }

  Future<void> initCam() async {
    await [Permission.camera, Permission.microphone].request();
    controller = CameraController(allCams[0], ResolutionPreset.veryHigh, enableAudio: true);
    await controller!.initialize();
    setState(() => isReady = true);
  }

  Future<void> setZoomLevel(double z) async {
    if (z < 0.6) z = 0.6;
    if (z > 100) z = 100;
    try {
      await controller!.setZoomLevel(z.clamp(0.6, 10.0));
    } catch(e) {}
    setState(() => zoom = z);
  }

  ColorFilter getFilter() {
    switch(filter) {
      case "Vivid":
        return const ColorFilter.matrix([1.4,0,0,0,-20, 0,1.4,0,0,-20, 0,0,1.4,0,-20, 0,0,0,1,0]);
      case "B&W":
        return const ColorFilter.matrix([0.21,0.72,0.07,0,0, 0.21,0.72,0.07,0,0, 0.21,0.72,0.07,0,0, 0,0,0,1,0]);
      case "KGF":
        return const ColorFilter.matrix([1.4,0.2,0,0,10, 0.2,1.1,0,0,5, 0,0,0.6,0,-5, 0,0,0,1,0]);
      case "RRR":
        return const ColorFilter.matrix([1.3,0,0,0,15, 0,1.2,0,0,5, 0,0,0.9,0,0, 0,0,0,1,0]);
      default:
        return const ColorFilter.matrix([1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0]);
    }
  }

  Future<void> shoot() async {
    if (mode == "Video" || mode == "Ultra HD") {
      if (isRec) {
        t?.cancel();
        await controller!.stopVideoRecording();
        setState(() => isRec = false);
      } else {
        await controller!.startVideoRecording();
        setState(() { isRec = true; sec = 0; });
        t = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => sec++);
        });
      }
    } else {
      setState(() => flashOn = true);
      await Future.delayed(const Duration(milliseconds: 150));
      await controller!.takePicture();
      setState(() => flashOn = false);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Photo Captured!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isReady) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.amber)));
    }
    bool isCine = mode == "Cinematic";
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ColorFiltered(colorFilter: getFilter(), child: SizedBox.expand(child: CameraPreview(controller!))),
          if (isCine) Positioned(top: 0, left: 0, right: 0, height: 90, child: Container(color: Colors.black)),
          if (isCine) Positioned(bottom: 0, left: 0, right: 0, height: 150, child: Container(color: Colors.black)),
          if (flashOn) Container(color: Colors.white.withOpacity(0.9)),

          Positioned(top: 45, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)), child: Text("KILLER CAMERA • ${zoom.toStringAsFixed(1)}x • $filter", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))))),

          Positioned(top: 85, left: 0, right: 0, child: SizedBox(height: 38, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: modes.map((m) { bool sel = m == mode; return GestureDetector(onTap: () => setState(() => mode = m), child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: sel? Colors.white : Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text(m, style: TextStyle(color: sel? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))); }).toList()))),

          Positioned(top: 130, left: 0, right: 0, child: SizedBox(height: 32, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: filters.map((f) { bool sel = f == filter; return GestureDetector(onTap: () => setState(() => filter = f), child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: sel? Colors.amber : Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text(f, style: TextStyle(color: sel? Colors.black : Colors.white, fontSize: 11)))); }).toList()))),

          Positioned(bottom: 170, left: 0, right: 0, child: Center(child: Text("${zoom.toStringAsFixed(1)}x ${isRec? '• $sec s' : ''}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),

          Positioned(bottom: 90, left: 20, right: 20, child: Slider(value: zoom, min: 0.6, max: 100, activeColor: Colors.amber, onChanged: setZoomLevel)),

          Positioned(bottom: 20, left: 20, right: 20, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.flash_auto, color: Colors.white)),
            GestureDetector(onTap: shoot, child: Container(width: 80, height: 80, decoration: BoxDecoration(color: isRec? Colors.red : Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)), child: Icon(isRec? Icons.stop : Icons.circle, color: isRec? Colors.white : Colors.white, size: isRec? 36 : 70))),
            GestureDetector(onTap: () async { var next = allCams.length > 1 && controller!.description == allCams[0]? allCams[1] : allCams[0]; controller = CameraController(next, ResolutionPreset.veryHigh, enableAudio: true); await controller!.initialize(); setState(() {}); }, child: Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.cameraswitch, color: Colors.white)))
          ]))
        ],
      ),
    );
  }
}
