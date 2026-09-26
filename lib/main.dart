import 'dart:async';
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
  @override
  State<KillerTop> createState() => _KillerTopState();
}

class _KillerTopState extends State<KillerTop> {
  CameraController? ctrl;
  bool ready = false;
  bool rec = false;
  double zoom = 1.0;
  bool showDial = false;
  Timer? _debounce;
  String mode = "Photo";
  String filter = "Original";
  int sec = 0;
  Timer? timer;

  List<String> modes = ["Ultra HD", "Video", "Photo", "Portrait", "Cinematic"];
  List<String> filters = ["Original", "KGF", "RRR", "Vivid", "B&W"];

  @override
  void initState() { super.initState(); initCam(); }

  Future<void> initCam() async {
    await [Permission.camera, Permission.microphone, Permission.photos].request();
    ctrl = CameraController(allCams[0], ResolutionPreset.veryHigh, enableAudio: true);
    await ctrl!.initialize();
    if(mounted) setState(() => ready = true);
  }

  Future<void> setZ(double z) async {
    if (z < 0.6) z = 0.6;
    if (z > 10.0) z = 10.0;
    setState(() => zoom = z);
    if (_debounce?.isActive?? false) return;
    _debounce = Timer(const Duration(milliseconds: 30), () async {
      try { await ctrl!.setZoomLevel(zoom); } catch(e){}
    });
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
        timer?.cancel();
        var f = await ctrl!.stopVideoRecording();
        setState(() => rec = false);
        await Gal.putVideo(f.path);
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Video Gallery madhe Save zala!")));
      } else {
        await ctrl!.startVideoRecording();
        setState(() { rec = true; sec = 0; });
        timer = Timer.periodic(const Duration(seconds: 1), (t) => setState(() => sec++));
      }
    } else {
      var f = await ctrl!.takePicture();
      await Gal.putImage(f.path);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Photo Gallery madhe Save zala!"), duration: Duration(seconds: 1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.amber)));
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        ColorFiltered(colorFilter: getF(), child: SizedBox.expand(child: CameraPreview(ctrl!))),
        if(mode=="Cinematic")...[
          Positioned(top:0, left:0, right:0, height: 90, child: Container(color: Colors.black)),
          Positioned(bottom:0, left:0, right:0, height: 90, child: Container(color: Colors.black)),
        ],
        Positioned(top: 45, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)), child: Text("KILLER CAM • ${zoom.toStringAsFixed(1)}x", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))))),
        Positioned(top: 85, left: 0, right: 0, height: 38, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: modes.map((m) => GestureDetector(onTap: () => setState(() => mode = m), child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: m==mode? Colors.white : Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text(m, style: TextStyle(color: m==mode? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold))))).toList())),
        Positioned(top: 130, left: 0, right: 0, height: 32, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: filters.map((f) => GestureDetector(onTap: () => setState(() => filter = f), child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: f==filter? Colors.amber : Colors.black54, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white24)), child: Text(f, style: TextStyle(color: f==filter? Colors.black : Colors.white, fontSize: 11))))).toList())),

        // 1x Long Press Dial
        Positioned(
          bottom: 165, left: 0, right: 0,
          child: GestureDetector(
            onLongPress: () => setState(() => showDial = true),
            onTap: () { if(showDial) setState(() => showDial = false); },
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                decoration: BoxDecoration(color: showDial? Colors.amber : Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
                child: Text("${zoom.toStringAsFixed(1)}x ${showDial? '• Band karayla Tap kara' : '• Dial sathi Dabun Dhara'}", style: TextStyle(color: showDial? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 13))
              )
            ),
          )
        ),

        if (showDial) Positioned(
          bottom: 75, left: 0, right: 0, height: 120,
          child: GestureDetector(
            onPanUpdate: (d) => setZ(zoom - d.delta.dx * 0.035),
            child: CustomPaint(painter: DialPainter(zoom)),
          )
        ),

        Positioned(bottom: 12, left: 20, right: 20, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.flash_auto, color: Colors.white)),
          GestureDetector(onTap: shoot, child: Container(width: 80, height: 80, decoration: BoxDecoration(color: rec? Colors.red : Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)), child: Icon(rec? Icons.stop : Icons.circle, color: rec? Colors.white : Colors.red, size: rec? 36 : 74))),
          GestureDetector(onTap: () async { var n = allCams.length > 1 && ctrl!.description == allCams[0]? allCams[1] : allCams[0]; ctrl = CameraController(n, ResolutionPreset.veryHigh, enableAudio: true); await ctrl!.initialize(); setState(() {}); }, child: Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.cameraswitch, color: Colors.white)))
        ]))
      ]),
    );
  }
}

class DialPainter extends CustomPainter {
  final double cur; DialPainter(this.cur);
  @override
  void paint(Canvas c, Size s) {
    double cx = s.width / 2; double cy = s.height + 25; double r = s.width * 0.70;
    c.drawPath(Path()..addArc(Rect.fromCircle(center: Offset(cx, cy), radius: r+35), pi, pi), Paint()..color = Colors.black.withOpacity(0.5)..style = PaintingStyle.fill);
    for (double z = 0.6; z <= 10; z += 0.1) {
      double t = (z - 0.6) / 9.4; double ang = pi + t * pi;
      bool isMain = [0.6, 1.0, 2.0, 4.0, 10.0].contains(double.parse(z.toStringAsFixed(1)));
      double len = isMain? 22 : (z*10)%5==0? 12 : 5;
      double x1 = cx + r * cos(ang); double y1 = cy + r * sin(ang);
      double x2 = cx + (r - len) * cos(ang); double y2 = cy + (r - len) * sin(ang);
      bool isCur = (cur - z).abs() < 0.09;
      c.drawLine(Offset(x1,y1), Offset(x2,y2), Paint()..color = isCur? Colors.amber : (isMain? Colors.white : Colors.white38)..strokeWidth = isCur? 4 : isMain? 2.5 : 1.2..strokeCap = StrokeCap.round);
      if (isMain) {
        TextPainter tp = TextPainter(text: TextSpan(text: "${z.toStringAsFixed(z==0.6?1:0)}x", style: TextStyle(color: isCur? Colors.amber : Colors.white, fontSize: isCur? 15 : 12, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr); tp.layout();
        c.drawCircle(Offset(cx + (r - 38) * cos(ang), cy + (r - 38) * sin(ang)), isCur?14:0, Paint()..color=Colors.amber.withOpacity(0.15));
        tp.paint(c, Offset(cx + (r - 38) * cos(ang) - tp.width/2, cy + (r - 38) * sin(ang) - 7));
      }
    }
    c.drawLine(Offset(cx, cy - r + 8), Offset(cx, cy - r + 30), Paint()..color = Colors.amber..strokeWidth = 3.5..strokeCap = StrokeCap.round);
  }
  @override bool shouldRepaint(covariant DialPainter o) => o.cur!= cur;
}
