import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> cameras = [];
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: DialCam()));
}

class DialCam extends StatefulWidget {
  const DialCam({super.key});
  @override
  State<DialCam> createState() => _DialCamState();
}

class _DialCamState extends State<DialCam> {
  CameraController? ctrl;
  bool ready = false;
  bool isRec = false;
  double zoom = 1.0;
  double maxZoom = 10.0;
  String mode = "Photo";
  Timer? t;
  int sec = 0;

  Future<void> initCam() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    await Permission.photos.request();
    ctrl = CameraController(cameras[0], ResolutionPreset.ultraHigh, enableAudio: true);
    await ctrl!.initialize();
    maxZoom = await ctrl!.getMaxZoomLevel();
    if (maxZoom > 10) maxZoom = 10;
    setState(() => ready = true);
  }

  @override
  void initState() {
    super.initState();
    initCam();
  }

  Future<void> setZ(double z) async {
    if (z < 0.6) z = 0.6;
    if (z > maxZoom) z = maxZoom;
    await ctrl!.setZoomLevel(z);
    setState(() => zoom = z);
  }

  String fmt(int s) {
    int m = s ~/ 60;
    int sc = s % 60;
    return "${m.toString().padLeft(2, '0')}:${sc.toString().padLeft(2, '0')}";
  }

  Future<void> shoot() async {
    if (mode == "Video") {
      if (isRec) {
        t?.cancel();
        var f = await ctrl!.stopVideoRecording();
        await Gal.putVideo(f.path);
        setState(() {
          isRec = false;
          sec = 0;
        });
      } else {
        await ctrl!.startVideoRecording();
        setState(() => isRec = true);
        t = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => sec++);
        });
      }
    } else {
      var f = await ctrl!.takePicture();
      await Gal.putImage(f.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.yellow)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SizedBox.expand(child: CameraPreview(ctrl!)),

          // REC TIMER - Top
          if (isRec)
            Positioned(
              top: 45,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                  child: Text("REC ${fmt(sec)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),

          // Zoom value
          Positioned(
            bottom: 170,
            left: 0,
            right: 0,
            child: Center(child: Text("${zoom.toStringAsFixed(1)}x", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w300))),
          ),

          // DIAL
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: GestureDetector(
              onPanUpdate: (d) {
                double delta = -d.delta.dx * 0.04;
                setZ(zoom + delta);
              },
              child: SizedBox(height: 90, child: CustomPaint(painter: MyDialPainter(curZoom: zoom, maxZ: maxZoom))),
            ),
          ),

          // Modes
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ["Ultra HD", "Video", "Photo", "Portrait", "Night"].map((m) {
                  bool sel = m == mode;
                  return GestureDetector(
                    onTap: () => setState(() => mode = m),
                    child: Text(m, style: TextStyle(color: sel? Colors.amber : Colors.white70, fontSize: 13, fontWeight: sel? FontWeight.bold : FontWeight.normal)),
                  );
                }).toList(),
              ),
            ),
          ),

          // Shutter
          Positioned(
            bottom: 20,
            left: 25,
            right: 25,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 45, height: 45, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.photo, color: Colors.white)),
                GestureDetector(
                  onTap: shoot,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                    child: Icon(isRec? Icons.stop : Icons.circle, color: isRec? Colors.red : Colors.white, size: isRec? 32 : 68),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    var next = ctrl!.description == cameras[0]? (cameras.length > 1? cameras[1] : cameras[0]) : cameras[0];
                    ctrl = CameraController(next, ResolutionPreset.ultraHigh, enableAudio: true);
                    await ctrl!.initialize();
                    setState(() {});
                  },
                  icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 28),
