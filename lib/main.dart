import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> allCams = [];
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  allCams = await availableCameras();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: KillerTop()));
}

class KillerTop extends StatefulWidget {
  const KillerTop({super.key});
  @override State<KillerTop> createState() => _KillerTopState();
}

class _KillerTopState extends State<KillerTop> {
  CameraController? ctrl;
  bool ready = false;
  bool rec = false;
  double zoom = 1.0;
  bool showDial = false;
  String mode = "Photo";
  String filter = "Original";
  FlashMode flash = FlashMode.off;
  bool isFront = false;

  List<String> modes = ["Ultra HD", "Video", "Photo", "Portrait", "Cinematic"];
  List<String> filters = ["Original", "KGF", "RRR", "Vivid", "B&W"];

  @override void initState() { super.initState(); initCam(allCams[0]); }

  Future<void> initCam(CameraDescription cam) async {
    if (mounted) setState(() => ready = false);
    try {
      await [Permission.camera, Permission.microphone].request();
      if (ctrl!= null) {
        await ctrl!.dispose();
        ctrl = null;
      }
      ctrl = CameraController(cam, ResolutionPreset.high, enableAudio: true);
      await ctrl!.initialize();
      await ctrl!.setFlashMode(flash);
      await ctrl!.setZoomLevel(1.0);
      if (mounted) setState(() {
        ready = true;
        isFront = cam.lensDirection == CameraLensDirection.front;
        zoom = 1.0;
      });
    } catch (e) {
      debugPrint("Cam init error: $e");
      if (mounted) setState(() => ready = false);
    }
  }

  // FIX 5 - EKDAm MAKKHAN SMOOTH - await kadhla
  void setZ(double z) {
    if (z < 0.6) z = 0.6;
    if (z > 10.0) z = 10.0;
    setState(() => zoom = z);
    ctrl?.setZoomLevel(zoom); // await nahi mhanun lag nahi
  }

  // FIX 4 - FLASH
  Future<void> toggleFlash() async {
    try {
      if (flash == FlashMode.off) {
        await ctrl!.setFlashMode(FlashMode.torch);
        setState(() => flash = FlashMode.torch);
      } else {
        await ctrl!.setFlashMode(FlashMode.off);
        setState(() => flash = FlashMode.off);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Flash ya camera var support nahi")));
    }
  }

  // FIX 3 - FRONT CAM BLACK SCREEN FIX
  Future<void> switchCam() async {
    try {
      CameraDescription newCam;
      if (isFront) {
        newCam = allCams.firstWhere((c) => c.lensDirection == CameraLensDirection.back);
      } else {
        newCam = allCams.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => allCams[0]);
      }
      await initCam(newCam);
    } catch (e) {
      await initCam(allCams[0]);
    }
  }

  ColorFilter getF() {
    switch (filter) {
      case "Vivid": return const ColorFilter.matrix([1.4,0,0,0,-20, 0,1.4,0,0,-20, 0,0,1.4,0,-20, 0,0,0,1,0]);
      case "B&W": return const ColorFilter.matrix([0.21,0.72,0.07,0,0, 0.21,0.72,0.07,0,0, 0.21,0.72,0.07,0,0, 0,0,0,1,0]);
      case "KGF": return const ColorFilter.matrix([1.2,0,0,0,10, 0,1.0,0,0,0, 0,0,0.8,0,0, 0,0,0,1,0]);
      case "RRR": return const ColorFilter.matrix([1.3,0,0,0,20, 0,1.1,0,0,10, 0,0,0.9,0,0, 0,0,0,1,0]);
      default: return const ColorFilter.matrix([1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0]);
    }
  }

  Future<void> shoot() async {
    if (mode == "Video") {
      if (rec) {
        var f = await ctrl!.stopVideoRecording();
        setState(() => rec = false);
        await Gal.putVideo(f.path);
      } else {
        await ctrl!.startVideoRecording();
        setState(() => rec = true);
      }
    } else {
      var f = await ctrl!.takePicture();
      await Gal.putImage(f.path);
    }
  }

  @override Widget build(BuildContext context) {
    if (!ready || ctrl == null ||!ctrl!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.amber)));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        ColorFiltered(colorFilter: getF(), child: SizedBox.expand(child: CameraPreview(ctrl!))),
        if (mode == "Cinematic")...[
          Positioned(top: 0, left: 0, right: 0, height: 90, child: Container(color: Colors.black)),
          Positioned(bottom: 0, left: 0, right: 0, height: 90, child: Container(color: Colors.black)),
        ],
        Positioned(top: 45, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)), child: Text("KILLER CAM • ${zoom.toStringAsFixed(1)}x", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))))),
        Positioned(top: 85, left: 0, right: 0, height: 38, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: modes.map((m) => GestureDetector(onTap: () => setState(() => mode = m), child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: m == mode? Colors.white : Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text(m, style: TextStyle(color: m == mode? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold))))).toList())),
        Positioned(top: 130, left: 0, right: 0, height: 32, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: filters.map((f) => GestureDetector(onTap: () => setState(() => filter = f), child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: f == filter? Colors.amber : Colors.black1
