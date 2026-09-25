import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

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
  bool ready = false, isRecording = false, isPaused = false;
  String filter = "DSLR Portrait";
  String mode = "Photo";
  String? lastPath;
  Timer? t;
  int sec = 0;
  double zoom = 1.0;

  List<String> filters = [
    "DSLR Portrait",
    "Bokeh Mode",
    "DSLR 1",
    "DSLR 2",
    "DSLR 3",
    "DSLR 4",
  ];

  @override void initState() { super.initState(); init(); }

  Future<void> init() async {
    controller = CameraController(cameras[0], ResolutionPreset.ultraHigh, enableAudio: true);
    await controller.initialize();
    setState(() => ready = true);
  }

  void setZoom(double z) { double nz = z.clamp(0.6, 8.0); setState(() => zoom = nz); controller.setZoomLevel(nz); }
  String fmt(int s) => "${(s~/60).toString().padLeft(2,'0')}:${(s%60).toString().padLeft(2,'0')}";

  Future<void> saveToGallery(String path) async {
    try {
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      if (path.endsWith(".jpg")) {
        await Gal.putImage(path, album: "DSLR Camera");
      } else {
        await Gal.putVideo(path, album: "DSLR Camera");
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ $filter - Gallery madhe Save!"), backgroundColor: Colors.green));
    } catch(e) {}
  }

  Future<void> takePhoto() async {
    var x = await controller.takePicture();
    var dir = await getApplicationDocumentsDirectory();
    String p = "${dir.path}/DSLR_${DateTime.now().millisecondsSinceEpoch}.jpg";
    await File(x.path).copy(p);
    setState(() => lastPath = p);
    await saveToGallery(p);
  }

  Future<void> takePhotoDuringVideo() async {
    try {
      await controller.pauseVideoRecording();
      var x = await controller.takePicture();
      var dir = await getApplicationDocumentsDirectory();
      String p = "${dir.path}/SNAP_${DateTime.now().millisecondsSinceEpoch}.jpg";
      await File(x.path).copy(p);
      setState(() => lastPath = p);
      await saveToGallery(p);
      await controller.resumeVideoRecording();
    } catch(e) { if(!isPaused) { try{ await controller.resumeVideoRecording(); }catch(_){} } }
  }

  Future<void> startVideo() async { await controller.startVideoRecording(); setState(() { isRecording = true; isPaused = false; sec = 0; }); t = Timer.periodic(Duration(seconds: 1), (timer) => setState(() => sec++)); }
  Future<void> pauseVideo() async { await controller.pauseVideoRecording(); t?.cancel(); setState(() => isPaused = true); }
  Future<void> resumeVideo() async { await controller.resumeVideoRecording(); t = Timer.periodic(Duration(seconds: 1), (timer) => setState(() => sec++)); setState(() => isPaused = false); }
  Future<void> stopVideo() async { t?.cancel(); var x = await controller.stopVideoRecording(); var dir = await getApplicationDocumentsDirectory(); String p = "${dir.path}/VIDEO_${DateTime.now().millisecondsSinceEpoch}.mp4"; await File(x.path).copy(p); setState(() { isRecording = false; isPaused = false; lastPath = p; mode = "Photo"; }); await saveToGallery(p); }

  @override Widget build(BuildContext context) {
    if (!ready) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.yellow)));
    return Scaffold(backgroundColor: Colors.black, body: Stack(children: [
      SizedBox.expand(child: CameraPreview(controller)),
      Positioned.fill(child: GestureDetector(onScaleUpdate: (d){ setZoom(zoom * d.scale); }, child: Container(color: Colors.transparent))),
      SafeArea(child: Column(children: [
        Padding(padding: EdgeInsets.all(12), child: Row(children: [Icon(Icons.camera_enhance, color: Colors.yellow), SizedBox(width: 6), Text("DSLR PRO 4K", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Spacer(), Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: filter=="Bokeh Mode"? Colors.pinkAccent:Colors.yellow, borderRadius: BorderRadius.circular(12)), child: Text(filter, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)))])),
        SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: 12), children: filters.map((f) => GestureDetector(onTap: ()=> setState(()=> filter=f), child: Container(margin: EdgeInsets.only(right: 8), padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8), decoration: BoxDecoration(color: filter==f? (f=="Bokeh Mode"? Colors.pinkAccent:Colors.yellow):Colors.black54, borderRadius: BorderRadius.circular(20)), child: Center(child: Text(f, style: TextStyle(color: filter==f? Colors.black:Colors.white, fontWeight: FontWeight.bold, fontSize: 12)))))).toList())),
      ])),
      if (isRecording) Positioned(top: 130, left:0, right:0, child: Center(child: Container(padding: EdgeInsets.symmetric(horizontal:14,vertical:6), decoration: BoxDecoration(color: isPaused? Colors.orange:Colors.red, borderRadius: BorderRadius.circular(20)), child: Text(isPaused? "⏸️ PAUSED ${fmt(sec)}":"● REC ${fmt(sec)} 4K", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),
      Positioned(bottom:0, left:0, right:0, child: Column(children: [
        Text("${zoom.toStringAsFixed(1)}x • $mode • $filter • 4K HD", style: TextStyle(color: Colors.white, fontSize: 11)),
        SizedBox(height: 6),
        GestureDetector(onPanUpdate: (d){ setZoom(zoom - d.delta.dx*0.02); }, child: SizedBox(height: 70, child: Stack(alignment: Alignment.center, children: [CustomPaint(size: Size(400,70), painter: DialPainter(zoom)), Container(width: 3, height: 16, color: Colors.yellow, margin: EdgeInsets.only(bottom: 25))]))),
        Container(padding: EdgeInsets.fromLTRB(20,10,20,30), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          isRecording? GestureDetector(onTap: () async { if(isPaused) await resumeVideo(); else await pauseVideo(); }, child: Container(width:56, height:56, decoration: BoxDecoration(color: isPaused? Colors.green:Colors.orange, shape: BoxShape.circle, border: Border.all(color: Colors.white, width:2)), child: Icon(isPaused? Icons.play_arrow:Icons.pause, color: Colors.white, size:28)))
          : GestureDetector(onTap: (){ if(lastPath==null) return; showDialog(context: context, builder: (_)=> Dialog(backgroundColor: Colors.black, child: Image.file(File(lastPath!)))); }, child: Container(width:48, height:48, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10), image: lastPath!=null && lastPath!.endsWith(".jpg")? DecorationImage(image: FileImage(File(lastPath!)), fit: BoxFit.cover):null), child: lastPath==null? Icon(Icons.photo_library, color: Colors.white):null)),
          GestureDetector(onTap: () async { if(mode=="Photo") await takePhoto(); else { if(isRecording) await stopVideo(); else await startVideo(); } }, child: Container(width:84, height:84, decoration: BoxDecoration(color: isRecording? Colors.red:Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.yellow, width:4)), child: Icon(isRecording? Icons.stop: Icons.camera_alt, color: isRecording? Colors.white:Colors.black, size:32))),
          isRecording? GestureDetector(onTap: () async { await takePhotoDuringVideo(); }, child: Column(children: [Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(Icons.camera_alt, color: Colors.black, size:20)), SizedBox(height:4), Text("Photo", style: TextStyle(color: Colors.white, fontSize:10))]))
          : GestureDetector(onTap: (){ setState(()=> mode = mode=="Photo"? "Video":"Photo"); }, child: Column(children: [Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: mode=="Video"? Colors.red:Colors.white24, shape: BoxShape.circle), child: Icon(mode=="Photo"? Icons.videocam:Icons.camera_alt, color: Colors.white, size:20)), SizedBox(height:4), Text(mode=="Photo"? "Video":"Photo", style: TextStyle(color: Colors.white, fontSize:11))])),
        ])),
      ])),
    ]));
  }
}

class DialPainter extends CustomPainter {
  final double zoom; DialPainter(this.zoom);
  @override void paint(Canvas c, Size s){
    var sp=Paint()..color=Colors.white38..strokeWidth=1; var bp=Paint()..color=Colors.white..strokeWidth=1.5;
    for(double i=0.6;i<=8.0;i+=0.2){
      double x=s.width/2 + (i-zoom)*45;
      if(x<15||x>s.width-15) continue;
      bool big=(i==0.6||i==1.0||i==2.0||i==4.0||i==8.0);
      c.drawLine(Offset(x,18), Offset(x,18+(big?14:6)), big?bp:sp);
      if(big){ String t=i==0.6?"0.6": "${i.toStringAsFixed(i==1?1:0)}x"; var tp=TextPainter(text: TextSpan(text: t, style: TextStyle(color: Colors.white70, fontSize:9)), textDirection: TextDirection.ltr)..layout(); tp.paint(c, Offset(x-7,40)); }
    }
  }
  @override bool shouldRepaint(covariant DialPainter old)=> old.zoom!=zoom;
}
