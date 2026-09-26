import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    if (ctrl!= null) { await ctrl!.dispose(); ctrl = null; }
    ctrl = CameraController(cam, ResolutionPreset.high, enableAudio: true);
    await ctrl!.initialize();
    await ctrl!.setFlashMode(flash);
    await ctrl!.setZoomLevel(1.0);
    if (mounted) setState(() { ready = true; isFront = cam.lensDirection == CameraLensDirection.front; zoom = 1.0; });
  }

  void setZ(double z) {
    if (z < 0.6) z = 0.6;
    if (z > 10.0) z = 10.0;
    setState(() => zoom = z);
    ctrl?.setZoomLevel(zoom);
  }

  // SOUND + VIBRATION LOGIC
  Future<void> shoot() async {
    if (mode == "Video") {
      if (rec) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.click);
        Feedback.forLongPress(context);
        var f = await ctrl!.stopVideoRecording();
        setState(() => rec = false);
        await Gal.putVideo(f.path);
      } else {
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
        Feedback.forTap(context);
        await ctrl!.startVideoRecording();
        setState(() => rec = true);
      }
    } else {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
      var f = await ctrl!.takePicture();
      await Gal.putImage(f.path);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("📸 KILLER CLICK!"), duration: Duration(milliseconds: 400)));
    }
  }

  Future<void> toggleFlash() async {
    try {
      if (flash == FlashMode.off) { await ctrl!.setFlashMode(FlashMode.torch); setState(() => flash = FlashMode.torch); }
      else { await ctrl!.setFlashMode(FlashMode.off); setState(() => flash = FlashMode.off); }
    } catch (e) {}
  }

  Future<void> switchCam() async {
    CameraDescription newCam = isFront? allCams.firstWhere((c) => c.lensDirection == CameraLensDirection.back) : allCams.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => allCams[0]);
    await initCam(newCam);
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

  @override Widget build(BuildContext context) {
    if (!ready || ctrl == null) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.amber)));
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        ColorFiltered(colorFilter: getF(), child: SizedBox.expand(child: CameraPreview(ctrl!))),
        Positioned(top: 45, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)), child: Text("KILLER CAM • ${zoom.toStringAsFixed(1)}x", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))))),
        Positioned(top: 85, left: 0, right: 0, height: 38, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: modes.map((m) => GestureDetector(onTap: () => setState(() => mode = m), child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: m == mode? Colors.white : Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text(m, style: TextStyle(color: m == mode? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold))))).toList())),
        Positioned(top: 130, left: 0, right: 0, height: 32, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: filters.map((f) => GestureDetector(onTap: () => setState(() => filter = f), child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: f == filter? Colors.amber : Colors.black54, borderRadius: BorderRadius.circular(15)), child: Text(f, style: TextStyle(color: f == filter? Colors.black : Colors.white, fontSize: 11))))).toList())),
        Positioned(bottom: 150, left: 0, right: 0, child: Center(child: GestureDetector(onLongPress: () => setState(() => showDial = true), onTap: () => setState(() => showDial =!showDial), child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7), decoration: BoxDecoration(color: showDial? Colors.amber : Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text("${zoom.toStringAsFixed(1)}x", style: TextStyle(color: showDial? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 13)))))),
        if (showDial) Positioned(bottom: 90, left: 60, right: 60, height: 50, child: GestureDetector(onHorizontalDragUpdate: (d) { setZ(zoom - (d.primaryDelta??0) * 0.06); }, child: Container(decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(25)), child: CustomPaint(painter: SmallDialPainter(zoom))))),
        Positioned(bottom: 12, left: 20, right: 20, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(onTap: toggleFlash, child: Container(width: 50, height: 50, decoration: BoxDecoration(color: flash == FlashMode.torch? Colors.amber : Colors.white24, shape: BoxShape.circle), child: Icon(flash == FlashMode.torch? Icons.flash_on : Icons.flash_off, color: flash == FlashMode.torch? Colors.black : Colors.white))),
          GestureDetector(onTap: shoot, child: Container(width: 78, height: 78, decoration: BoxDecoration(color: rec? Colors.red : Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)), child: Icon(rec? Icons.stop : Icons.circle, color: rec? Colors.white : Colors.red, size: rec? 36 : 74))),
          GestureDetector(onTap: switchCam, child: Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.cameraswitch, color: Colors.white)))
        ]))
      ]),
    );
  }
}

class SmallDialPainter extends CustomPainter {
  final double cur; SmallDialPainter(this.cur);
  @override void paint(Canvas c, Size s) {
    double cx = s.width / 2;
    c.drawLine(Offset(cx, 10), Offset(cx, 20), Paint()..color = Colors.amber..strokeWidth = 2.5);
    List<double> zs = [0.6, 1.0, 2.0, 3.0, 4.0, 6.0, 10.0];
    for (double z in zs) {
      double curT = (cur - 0.6) / 9.4; double t = (z - 0.6) / 9.4;
      double x = cx + (t - curT) * s.width * 0.8;
      if (x < 10 || x > s.width - 10) continue;
      bool isCur = (cur - z).abs() < 0.2;
      c.drawLine(Offset(x, s.height/2 - (isCur?7:4)), Offset(x, s.height/2 + (isCur?7:4)), Paint()..color = isCur? Colors.amber : Colors.white70..strokeWidth = isCur?2.5:1);
      TextPainter tp = TextPainter(text: TextSpan(text: "${z==0.6?0.6:z.toInt()}x", style: TextStyle(color: isCur? Colors.amber : Colors.white70, fontSize: isCur?10:8, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr); tp.layout(); tp.paint(c, Offset(x - tp.width/2, s.height/2 + 8));
    }
  }
  @override bool shouldRepaint(covariant SmallDialPainter o) => o.cur!= cur;
}
