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
    await [Permission.camera, Permission.microphone].request();
    if (ctrl!= null) {
      await ctrl!.dispose();
    }
    ctrl = CameraController(cam, ResolutionPreset.high, enableAudio: true);
    await ctrl!.initialize();
    await ctrl!.setFlashMode(flash);
    await ctrl!.setZoomLevel(1.0);
    if (mounted) {
      setState(() {
        ready = true;
        isFront = cam.lensDirection == CameraLensDirection.front;
        zoom = 1.0;
      });
    }
  }

  void setZ(double z) {
    if (z < 0.6) z = 0.6;
    if (z > 10.0) z = 10.0;
    setState(() => zoom = z);
    ctrl?.setZoomLevel(zoom);
  }

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Flash not supported")));
    }
  }

  Future<void> switchCam() async {
    CameraDescription newCam;
    if (isFront) {
      newCam = allCams.firstWhere((c) => c.lensDirection == CameraLensDirection.back);
    } else {
      newCam = allCams.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => allCams[0]);
    }
    await initCam(newCam);
  }

  ColorFilter getF() {
    switch (filter) {
      case "Vivid":
        return const ColorFilter.matrix([1.4,0,0,0,-20, 0,1.4,0,0,-20, 0,0,1.4,0,-20, 0,0,0,1,0]);
      case "B&W":
        return const ColorFilter.matrix([0.21,0.72,0.07,0,0, 0.21,0.72,0.07,0,0, 0.21,0.72,0.07,0,0, 0,0,0,1,0]);
      case "KGF":
        return const ColorFilter.matrix([1.2,0,0,0,10, 0,1.0,0,0,0, 0,0,0.8,0,0, 0,0,0,1,0]);
      case "RRR":
        return const ColorFilter.matrix([1.3,0,0,0,20, 0,1.1,0,0,10, 0,0,0.9,0,0, 0,0,0,1,0]);
      default:
        return const ColorFilter.matrix([1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0]);
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
    if (!ready || ctrl == null) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.amber)));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ColorFiltered(colorFilter: getF(), child: SizedBox.expand(child: CameraPreview(ctrl!))),
          if (mode == "Cinematic")...[
            Positioned(top: 0, left: 0, right: 0, height: 90, child: Container(color: Colors.black)),
            Positioned(bottom: 0, left: 0, right: 0, height: 90, child: Container(color: Colors.black)),
          ],
          Positioned(
            top: 45, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)),
                child: Text("KILLER CAM • ${zoom.toStringAsFixed(1)}x", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
          ),
          Positioned(
            top: 85, left: 0, right: 0, height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: modes.map((m) {
                return GestureDetector(
                  onTap: () => setState(() => mode = m),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: m == mode? Colors.white : Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: Text(m, style: TextStyle(color: m == mode? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ),
          ),
          Positioned(
            top: 130, left: 0, right: 0, height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: filters.map((f) {
                return GestureDetector(
                  onTap: () => setState(() => filter = f),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: f == filter? Colors.amber : Colors.black54, borderRadius: BorderRadius.circular(15)),
                    child: Text(f, style: TextStyle(color: f == filter? Colors.black : Colors.white, fontSize: 11)),
                  ),
                );
              }).toList(),
            ),
          ),
          Positioned(
            bottom: 175, left: 0, right: 0,
            child: Center(
              child: GestureDetector(
                onLongPress: () => setState(() => showDial = true),
                onTap: () => setState(() => showDial =!showDial),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(color: showDial? Colors.amber : Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
                  child: Text("${zoom.toStringAsFixed(1)}x", style: TextStyle(color: showDial? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ),
          ),
          if (showDial)
            Positioned(
              bottom: 70, left: 0, right: 0, height: 150,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  double delta = details.primaryDelta?? 0;
                  double newZoom = zoom - delta * 0.07;
                  setZ(newZoom);
                },
                child: CustomPaint(painter: DialPainter(zoom)),
              ),
            ),
          Positioned(
            bottom: 12, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: toggleFlash,
                  child: Container(width: 50, height: 50, decoration: BoxDecoration(color: flash == FlashMode.torch? Colors.amber : Colors.white24, shape: BoxShape.circle), child: Icon(flash == FlashMode.torch? Icons.flash_on : Icons.flash_off, color: flash == FlashMode.torch? Colors.black : Colors.white)),
                ),
                GestureDetector(
                  onTap: shoot,
                  child: Container(width: 80, height: 80, decoration: BoxDecoration(color: rec? Colors.red : Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)), child: Icon(rec? Icons.stop : Icons.circle, color: rec? Colors.white : Colors.red, size: rec? 36 : 74)),
                ),
                GestureDetector(
                  onTap: switchCam,
                  child: Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.cameraswitch, color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DialPainter extends CustomPainter {
  final double cur;
  DialPainter(this.cur);
  @override void paint(Canvas c, Size s) {
    double cx = s.width / 2;
    double cy = s.height + 35;
    double r = s.width * 0.80;
    c.drawPath(Path()..addArc(Rect.fromCircle(center: Offset(cx, cy), radius: r + 45), pi, pi), Paint()..color = Colors.black.withOpacity(0.65)..style = PaintingStyle.fill);
    for (double z = 0.6; z <= 10.0; z += 0.1) {
      double t = (z - 0.6) / 9.4;
      double ang = pi + t * pi;
      bool isMain = [0.6, 1.0, 2.0, 4.0, 10.0].any((v) => (v - z).abs() < 0.07);
      double len = isMain? 24 : (z * 10) % 5 == 0? 14 : 6;
      double x1 = cx + r * cos(ang);
      double y1 = cy + r * sin(ang);
      double x2 = cx + (r - len) * cos(ang);
      double y2 = cy + (r - len) * sin(ang);
      bool isCur = (cur - z).abs() < 0.15;
      c.drawLine(Offset(x1, y1), Offset(x2, y2), Paint()..color = isCur? Colors.amber : (isMain? Colors.white : Colors.white38)..strokeWidth = isCur? 4.5 : isMain? 2.8 : 1.2..strokeCap = StrokeCap.round);
      if (isMain) {
        TextPainter tp = TextPainter(text: TextSpan(text: "${z.toStringAsFixed(z == 0.6? 1 : 0)}x", style: TextStyle(color: isCur? Colors.amber : Colors.white, fontSize: isCur? 16 : 12, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(c, Offset(cx + (r - 42) * cos(ang) - tp.width / 2, cy + (r - 42) * sin(ang) - 7));
      }
    }
    c.drawLine(Offset(cx, cy - r + 10), Offset(cx, cy - r + 35), Paint()..color = Colors.amber..strokeWidth = 4..strokeCap = StrokeCap.round);
  }
  @override bool shouldRepaint(covariant DialPainter o) => o.cur!= cur;
}
