import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> cams = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cams = await availableCameras();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: MainCam()));
}

class MainCam extends StatefulWidget {
  const MainCam({super.key});
  @override
  State<MainCam> createState() => MainCamState();
}

class MainCamState extends State<MainCam> {
  CameraController? ctrl;
  bool ready = false;
  bool rec = false;
  double zoom = 1.0;
  double maxZoom = 10.0;
  String mode = "Photo";
  Timer? timer;
  int sec = 0;

  Future<void> initC() async {
    await [Permission.camera, Permission.microphone, Permission.photos].request();
    ctrl = CameraController(cams[0], ResolutionPreset.ultraHigh, enableAudio: true);
    await ctrl!.initialize();
    double mz = await ctrl!.getMaxZoomLevel();
    if (mz > 10) mz = 10;
    maxZoom = mz;
    setState(() => ready = true);
  }

  @override
  void initState() {
    super.initState();
    initC();
  }

  Future<void> setZoom(double z) async {
    if (z < 0.6) z = 0.6;
    if (z > maxZoom) z = maxZoom;
    await ctrl!.setZoomLevel(z);
    setState(() => zoom = z);
  }

  String fmt(int s) {
    int m = s ~/ 60;
    int sc = s % 60;
    String mm = m.toString().padLeft(2, '0');
    String ss = sc.toString().padLeft(2, '0');
    return "$mm:$ss";
  }

  Future<void> doShoot() async {
    if (mode == "Video") {
      if (rec) {
        timer?.cancel();
        var f = await ctrl!.stopVideoRecording();
        await Gal.putVideo(f.path);
        setState(() {
          rec = false;
          sec = 0;
        });
      } else {
        await ctrl!.startVideoRecording();
        setState(() => rec = true);
        timer = Timer.periodic(const Duration(seconds: 1), (t) {
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
          if (rec)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                  child: Text("REC " + fmt(sec), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          Positioned(
            bottom: 175,
            left: 0,
            right: 0,
            child: Center(
              child: Text(zoom.toStringAsFixed(1) + "x", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w300)),
            ),
          ),
          Positioned(
            bottom: 85,
            left: 0,
            right: 0,
            child: DialView(cur: zoom, maxZ: maxZoom, onChanged: (v) => setZoom(v)),
          ),
          Positioned(
            bottom: 85,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(onTap: () => setState(() => mode = "Ultra HD"), child: Text("Ultra HD", style: TextStyle(color: mode == "Ultra HD"? Colors.amber : Colors.white70, fontSize: 12))),
                  GestureDetector(onTap: () => setState(() => mode = "Video"), child: Text("Video", style: TextStyle(color: mode == "Video"? Colors.amber : Colors.white70, fontSize: 12))),
                  GestureDetector(onTap: () => setState(() => mode = "Photo"), child: Text("Photo", style: TextStyle(color: mode == "Photo"? Colors.amber : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
                  GestureDetector(onTap: () => setState(() => mode = "Portrait"), child: Text("Portrait", style: TextStyle(color: mode == "Portrait"? Colors.amber : Colors.white70, fontSize: 12))),
                  GestureDetector(onTap: () => setState(() => mode = "Night"), child: Text("Night", style: TextStyle(color: mode == "Night"? Colors.amber : Colors.white70, fontSize: 12))),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 45, height: 45, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.photo_library, color: Colors.white)),
                GestureDetector(
                  onTap: doShoot,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                    child: Icon(rec? Icons.stop : Icons.circle, color: rec? Colors.red : Colors.white, size: rec? 30 : 68),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    var next = cams[0];
                    if (cams.length > 1) {
                      next = ctrl!.description == cams[0]? cams[1] : cams[0];
                    }
                    ctrl = CameraController(next, ResolutionPreset.ultraHigh, enableAudio: true);
                    await ctrl!.initialize();
                    setState(() {});
                  },
                  child: Container(width: 45, height: 45, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.cameraswitch, color: Colors.white)),
                ),
              ],
            ),
          ),
          if (rec)
            Positioned(
              bottom: 215,
              left: 0,
              right: 0,
              child: Center(child: Text(fmt(sec), style: const TextStyle(color: Colors.white, fontSize: 16))),
            ),
        ],
      ),
    );
  }
}

class DialView extends StatelessWidget {
  final double cur;
  final double maxZ;
  final Function(double) onChanged;
  const DialView({super.key, required this.cur, required this.maxZ, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) {
        double delta = -d.delta.dx * 0.05;
        double nz = cur + delta;
        if (nz < 0.6) nz = 0.6;
        if (nz > maxZ) nz = maxZ;
        onChanged(nz);
      },
      child: SizedBox(height: 80, width: double.infinity, child: CustomPaint(painter: DialPainter(cur: cur, maxZ: maxZ))),
    );
  }
}

class DialPainter extends CustomPainter {
  final double cur;
  final double maxZ;
  DialPainter({required this.cur, required this.maxZ});

  @override
  void paint(Canvas canvas, Size size) {
    double cx = size.width / 2;
    double cy = size.height;
    double r = size.width * 0.45;

    for (double z = 0.6; z <= maxZ + 0.01; z += 0.4) {
      double angle = 3.14159 + (z / maxZ) * 3.14159;
      double len = 6;
      bool isMark = false;
      if (z.toInt() == 1 || z.toInt() == 2 || z.toInt() == 4 || z.toInt() == 6 || z.toInt() == 8 || z.toInt() == 10) {
        if ((z - z.toInt()).abs() < 0.1) {
          len = 14;
          isMark = true;
        }
      }
      double x1 = cx + r * cos(angle);
      double y1 = cy + r * sin(angle);
      double x2 = cx + (r - len) * cos(angle);
      double y2 = cy + (r - len) * sin(angle);
      bool isCur = (cur - z).abs() < 0.15;
      Paint p = Paint();
      p.color = isCur? Colors.amber : Colors.white54;
      p.strokeWidth = isCur? 2.5 : 1;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), p);

      if (isMark) {
        double lx = cx + (r - 24) * cos(angle);
        double ly = cy + (r - 24) * sin(angle);
        TextPainter tp = TextPainter(text: TextSpan(text: z.toInt().toString(), style: const TextStyle(color: Colors.white70, fontSize: 10)), textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas, Offset(lx - tp.width / 2, ly));
      }
    }
    Paint cp = Paint();
    cp.color = Colors.white54;
    cp.strokeWidth = 2;
    canvas.drawLine(Offset(cx - 8, cy - 2), Offset(cx + 8, cy - 2), cp);
  }

  @override
  bool shouldRepaint(covariant DialPainter old) {
    return old.cur!= cur;
  }
}
