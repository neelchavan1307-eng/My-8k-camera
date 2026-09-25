import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MaterialApp(home: CameraApp(), debugShowCheckedModeBanner: false));
}

class CameraApp extends StatefulWidget {
  @override State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late CameraController controller;
  bool ready = false, isRecording = false;
  String filter = "Original";
  String? lastPath;
  Timer? t;
  int sec = 0;
  double zoom = 1.0;

  List<String> filters = ["Original", "Vivid", "Cinematic", "Warm"];

  List<double> getMatrix() {
    if (filter == "Vivid") return [1.3,0,0,0,-10, 0,1.3,0,0,-10, 0,0,1.3,0,-10, 0,0,0,1,0];
    if (filter == "Cinematic") return [0.9,0.1,0.1,0,10, 0.1,0.9,0.1,0,10, 0.1,0.1,0.9,0,10, 0,0,0,1,0];
    if (filter == "Warm") return [1.2,0,0,0,15, 0,1.1,0,0,10, 0,0,0.9,0,0, 0,0,0,1,0];
    return [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0];
  }

  @override void initState() { super.initState(); init(); }

  Future<void> init() async {
    controller = CameraController(cameras[0], ResolutionPreset.high, enableAudio: true);
    await controller.initialize();
    setState(() => ready = true);
  }

  void setZoom(double z) {
    double nz = z.clamp(0.6, 4.0);
    setState(() => zoom = nz);
    controller.setZoomLevel(nz);
  }

  String fmt(int s) => "${(s~/60).toString().padLeft(2,'0')}:${(s%60).toString().padLeft(2,'0')}";

  Future<void> takePhoto() async {
    var x = await controller.takePicture();
    var dir = await getApplicationDocumentsDirectory();
    String p = "${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";
    await File(x.path).copy(p);
    setState(() => lastPath = p);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Photo Saved ✓")));
  }

  Future<void> startVideo() async {
    await controller.startVideoRecording();
    setState(() { isRecording = true; sec = 0; });
    t = Timer.periodic(Duration(seconds: 1), (timer) => setState(() => sec++));
  }

  Future<void> stopVideo() async {
    t?.cancel();
    var x = await controller.stopVideoRecording();
    var dir = await getApplicationDocumentsDirectory();
    String p = "${dir.path}/${DateTime.now().millisecondsSinceEpoch}.mp4";
    await File(x.path).copy(p);
    setState(() { isRecording = false; lastPath = p; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Video Saved ${fmt(sec)} ✓")));
  }

  @override Widget build(BuildContext context) {
    if (!ready) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.yellow)));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // FULL SCREEN CAMERA
          SizedBox.expand(
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(getMatrix()),
              child: CameraPreview(controller),
            ),
          ),
          // Pinch Zoom
          Positioned.fill(child: GestureDetector(
            onScaleUpdate: (d){ setZoom(zoom * d.scale); },
            child: Container(color: Colors.transparent)
          )),

          SafeArea(child: Column(children: [
            Padding(padding: EdgeInsets.all(12), child: Row(children: [Icon(Icons.flash_off, color: Colors.white), Spacer(), Container(padding: EdgeInsets.symmetric(horizontal:10,vertical:4), decoration: BoxDecoration(color: Colors.yellow, borderRadius: BorderRadius.circular(12)), child: Text("AI ON", style: TextStyle(fontSize:11, fontWeight: FontWeight.bold)))])),
            SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal:12), children: filters.map((f) => GestureDetector(onTap: ()=> setState(()=> filter=f), child: Container(margin: EdgeInsets.only(right:8), padding: EdgeInsets.symmetric(horizontal:16), decoration: BoxDecoration(color: filter==f? Colors.yellow:Colors.black54, borderRadius: BorderRadius.circular(20)), child: Center(child: Text(f, style: TextStyle(color: filter==f?Colors.black:Colors.white, fontWeight: FontWeight.bold, fontSize:12)))))).toList())),
          ])),

          if (isRecording) Positioned(top: 95, left:0, right:0, child: Center(child: Container(padding: EdgeInsets.symmetric(horizontal:14,vertical:6), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)), child: Text("● REC ${fmt(sec)}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),

          // BOTTOM - ZOOM DIAL + CONTROLS
          Positioned(bottom:0, left:0, right:0, child: Column(children: [
            Text("${zoom.toStringAsFixed(1)}x • $filter", style: TextStyle(color: Colors.white, fontSize:12)),
            SizedBox(height:6),
            // ONE HAND ZOOM DIAL
            GestureDetector(
              onPanUpdate: (d){ setZoom(zoom - d.delta.dx*0.02); },
              child: SizedBox(height:75, child: Stack(alignment: Alignment.center, children: [
                CustomPaint(size: Size(400,75), painter: DialPainter(zoom)),
                Container(width:3, height:18, color: Colors.yellow, margin: EdgeInsets.only(bottom:30)),
              ])),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(20,10,20,35),
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                GestureDetector(
                  onTap: (){ if(lastPath==null) return; showDialog(context: context, builder: (_)=> Dialog(backgroundColor: Colors.black, child: lastPath!.endsWith(".jpg")? Image.file(File(lastPath!)) : Icon(Icons.videocam, color: Colors.white, size:80))); },
                  child: Container(width:48, height:48, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10), image: lastPath!=null && lastPath!.endsWith(".jpg")? DecorationImage(image: FileImage(File(lastPath!)), fit: BoxFit.cover):null), child: lastPath==null? Icon(Icons.photo, color: Colors.white):null),
                ),
                GestureDetector(
                  onTap: () async { if(isRecording) await stopVideo(); else await takePhoto(); },
                  onLongPress: () async { if(!isRecording) await startVideo(); },
                  child: Container(width:78, height:78, decoration: BoxDecoration(color: isRecording? Colors.red:Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.yellow, width:4)), child: Icon(isRecording? Icons.stop:Icons.camera_alt, color: isRecording?Colors.white:Colors.black, size:30)),
                ),
                GestureDetector(onTap: () async { if(!isRecording) await startVideo(); else await stopVideo(); }, child: Column(children: [Icon(isRecording? Icons.stop_circle:Icons.videocam, color: Colors.white, size:30), SizedBox(height:2), Text(isRecording? fmt(sec):"Video", style: TextStyle(color: Colors.white, fontSize:11))])),
              ]),
            ),
          ])),
        ],
      ),
    );
  }
}

class DialPainter extends CustomPainter {
  final double zoom; DialPainter(this.zoom);
  @override void paint(Canvas c, Size s){
    var sp=Paint()..color=Colors.white38..strokeWidth=1; var bp=Paint()..color=Colors.white..strokeWidth=1.5;
    for(double i=0.6;i<=4.0;i+=0.1){
      double x=s.width/2 + (i-zoom)*65;
      if(x<15||x>s.width-15) continue;
      bool big=(i==0.6||i==1.0||i==2.0||i==4.0);
      c.drawLine(Offset(x,20), Offset(x,20+(big?16:7)), big?bp:sp);
      if(big){ String t=i==0.6?"0.6": i==1.0?"1x":"${i.toInt()}x"; var tp=TextPainter(text: TextSpan(text: t, style: TextStyle(color: Colors.white70, fontSize:9)), textDirection: TextDirection.ltr)..layout(); tp.paint(c, Offset(x-7,45)); }
    }
  }
  @override bool shouldRepaint(covariant DialPainter old)=> old.zoom!=zoom;
}
