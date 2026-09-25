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
  bool ready = false, isRecording = false, isPaused = false, showTopPanel = false, showZoomDial = false;
  String mode = "Photo";
  String? lastPath;
  Timer? t;
  int sec = 0;
  double zoom = 1.0;
  int camIndex = 0;

  List<String> modes = ["Ultra HD", "Video", "Photo", "Portrait", "Night", "Bokeh Mode", "DSLR Mode"];

  // ===== DSLR VIVID COLOR FILTERS =====
  // Normal - thoda sharp
  List<double> get normalFilter => [1.1,0,0,0,-10, 0,1.1,0,0,-10, 0,0,1.1,0,-10, 0,0,0,1,0];
  // Bokeh - Peach skin + Green pop
  List<double> get bokehFilter => [1.25,0.05,0,0,-15, 0,1.15,0.05,0,-10, 0,0,1.05,0,-5, 0,0,0,1,0];
  // DSLR Mode - Ekdam Vivid - Mothya camera sarkha
  List<double> get dslrVividFilter => [1.4,0.1,0,0,-20, 0,1.35,0.1,0,-20, 0,0.05,1.25,0,-15, 0,0,0,1,0];
  // Night - Bright
  List<double> get nightFilter => [1.2,0,0,0,20, 0,1.2,0,0,20, 0,0,1.2,0,20, 0,0,0,1,0];

  List<double> getCurrentFilter() {
    if (mode == "Bokeh Mode") return bokehFilter;
    if (mode == "DSLR Mode") return dslrVividFilter;
    if (mode == "Night") return nightFilter;
    if (mode == "Portrait") return bokehFilter;
    return normalFilter;
  }

  @override void initState() { super.initState(); initCam(0); }

  Future<void> initCam(int idx) async {
    setState(() => ready = false);
    controller = CameraController(cameras[idx], ResolutionPreset.veryHigh, enableAudio: true);
    await controller.initialize();
    await controller.setFocusMode(FocusMode.auto);
    await controller.setExposureMode(ExposureMode.auto);
    await controller.setZoomLevel(1.0);
    setState(() => ready = true);
  }

  void setZoom(double z) { double nz = z.clamp(0.6, 10.0); setState(() { zoom = nz; showZoomDial = true; }); controller.setZoomLevel(nz); Future.delayed(Duration(seconds: 2), (){ if(mounted) setState(()=> showZoomDial=false); }); }
  String fmt(int s) => "${(s~/60).toString().padLeft(2,'0')}:${(s%60).toString().padLeft(2,'0')}";
  Future<void> save(String path) async { try { if (!await Gal.hasAccess()) await Gal.requestAccess(); if (path.endsWith(".jpg")) await Gal.putImage(path, album: "DSLR Camera"); else await Gal.putVideo(path, album: "DSLR Camera"); } catch(e){} }
  Future<void> takePhoto() async { var x = await controller.takePicture(); var dir = await getApplicationDocumentsDirectory(); String p = "${dir.path}/DSLR_${DateTime.now().millisecondsSinceEpoch}.jpg"; await File(x.path).copy(p); setState(()=> lastPath=p); await save(p); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ $mode - DSLR Vivid Save!"), backgroundColor: Colors.green, duration: Duration(seconds:1))); }
  Future<void> startVideo() async { await controller.startVideoRecording(); setState(() { isRecording=true; sec=0; }); t=Timer.periodic(Duration(seconds:1), (tm)=> setState(()=> sec++)); }
  Future<void> stopVideo() async { t?.cancel(); var x = await controller.stopVideoRecording(); var dir = await getApplicationDocumentsDirectory(); String p="${dir.path}/DSLR_${DateTime.now().millisecondsSinceEpoch}.mp4"; await File(x.path).copy(p); setState((){ isRecording=false; lastPath=p; }); await save(p); }

  @override Widget build(BuildContext context) {
    if (!ready) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    bool isVideoMode = isRecording;

    return Scaffold(backgroundColor: Colors.black, body: Stack(children: [
      // ===== CAMERA WITH VIVID FILTER - CLARITY BOOST =====
      SizedBox.expand(child: ColorFiltered(
        colorFilter: ColorFilter.matrix(getCurrentFilter()),
        child: CameraPreview(controller),
      )),

      // CLARITY OVERLAY - Sharpness effect
      if(mode=="DSLR Mode" || mode=="Bokeh Mode")
      Positioned.fill(child: IgnorePointer(child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(center: Alignment.center, radius: 1.2, colors: [Colors.transparent, Colors.transparent, Colors.black12], stops: [0.6,0.85,1.0])
        ),
      ))),

      SafeArea(child: Column(children: [
        Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Row(children: [
          Icon(Icons.flash_off, color: Colors.white, size: 22),
          SizedBox(width: 8),
          Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: mode=="DSLR Mode"? Colors.amber:Colors.white24, borderRadius: BorderRadius.circular(10)), child: Row(children: [Icon(Icons.hd, size: 14, color: mode=="DSLR Mode"? Colors.black:Colors.white), SizedBox(width:3), Text(mode=="DSLR Mode"? "DSLR VIVID ON":"HD", style: TextStyle(color: mode=="DSLR Mode"? Colors.black:Colors.white, fontSize: 10, fontWeight: FontWeight.bold))])),
          Spacer(),
          GestureDetector(onTap: ()=> setState(()=> showTopPanel=!showTopPanel), child: Container(padding: EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: Icon(showTopPanel? Icons.keyboard_arrow_up:Icons.keyboard_arrow_down, color: Colors.white, size: 20))),
          Spacer(),
          if(isVideoMode) Text("● ${fmt(sec)}", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          if(!isVideoMode) Text("1080·30", style: TextStyle(color: Colors.white70, fontSize: 11)),
        ])),
        if(showTopPanel) Container(color: Colors.black87, padding: EdgeInsets.all(16), child: GridView.count(crossAxisCount: 4, shrinkWrap: true, children: [
          _topOpt(Icons.hdr_on,"HDR","HDR"), _topOpt(Icons.auto_awesome,"AI","AI Camera"), _topOpt(Icons.macro_off,"Macro","Macro"), _topOpt(Icons.aspect_ratio,"9:16","Ratio"),
          _topOpt(Icons.timer,"Timer","Timer"), _topOpt(Icons.panorama,"Tilt","Tilt-shift"), _topOpt(Icons.burst_mode,"Burst","Timed burst"), _topOpt(Icons.grid_view,"Assist","Assist"),
        ])),
      ])),

      Positioned(bottom: 0, left: 0, right: 0, child: Container(
        padding: EdgeInsets.only(bottom: 26, top: 8),
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])),
        child: Column(children: [
          if(!isVideoMode) Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [_zoomPill("0.6",0.6), _zoomPill("1x",1.0), _zoomPill("2",2.0), _zoomPill("4",4.0)])),
          SizedBox(height: 12),
          SizedBox(height: 32, child: ListView.builder(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: 12), itemCount: modes.length, itemBuilder: (c,i){ bool sel = modes[i]==mode &&!isVideoMode; bool vsel = modes[i]=="Video" && isVideoMode; return GestureDetector(onTap: (){ if(!isVideoMode) setState(()=> mode=modes[i]); }, child: Container(margin: EdgeInsets.symmetric(horizontal: 10), padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: sel && (modes[i]=="Bokeh Mode"||modes[i]=="DSLR Mode")? Colors.amber:Colors.transparent, borderRadius: BorderRadius.circular(12), border: sel? Border(bottom: BorderSide(color: Colors.amber, width: 2)):null), child: Text(modes[i], style: TextStyle(color: sel? (modes[i]=="Bokeh Mode"||modes[i]=="DSLR Mode"? Colors.black:Colors.amber):Colors.white70, fontWeight: sel? FontWeight.bold:FontWeight.normal, fontSize: sel? 15:13)))); })),
          if(showZoomDial) SizedBox(height: 90, child: Stack(alignment: Alignment.center, children: [CustomPaint(size: Size(380,90), painter: DialPainter(zoom)), Positioned(top: 8, child: Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(10)), child: Text("${zoom.toStringAsFixed(1)}x DSLR VIVID", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold))))])),
          SizedBox(height: 8),
          Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: Colors.white24, image: lastPath!=null? DecorationImage(image: FileImage(File(lastPath!)), fit: BoxFit.cover):null)),
            GestureDetector(onTap: () async { if(mode=="Video"||mode=="Ultra HD") { if(isRecording) await stopVideo(); else await startVideo(); } else await takePhoto(); }, child: Container(width: 72, height: 72, decoration: BoxDecoration(color: isVideoMode? Colors.red:Colors.white, shape: BoxShape.circle, border: Border.all(color: mode=="DSLR Mode"? Colors.amber:Colors.white, width: 4)), child: Icon(isVideoMode? Icons.stop:Icons.camera_alt, color: isVideoMode? Colors.white:Colors.black, size: isVideoMode? 28:32))),
            GestureDetector(onTap: () async { camIndex = camIndex==0?1:0; if(cameras.length>1) await initCam(camIndex); }, child: Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: Icon(Icons.cameraswitch, color: Colors.white, size: 20))),
          ]))
        ]),
      )),
      Positioned.fill(child: GestureDetector(onScaleUpdate: (d){ setZoom(zoom*d.scale); }, child: Container(color: Colors.transparent))),
    ]));
  }
  Widget _topOpt(IconData ic, String t1, String t2) => Column(children: [Icon(ic, color: Colors.white, size: 22), SizedBox(height: 4), Text(t1, style: TextStyle(color: Colors.white, fontSize: 10))]);
  Widget _zoomPill(String txt, double v){ bool sel = (zoom==v) || (zoom>0.9 && zoom<1.1 && v==1.0); return GestureDetector(onTap: ()=> setZoom(v), child: Container(margin: EdgeInsets.symmetric(horizontal: 4), padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: sel? Colors.white:Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Text(txt, style: TextStyle(color: sel? Colors.black:Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))); }
}

class DialPainter extends CustomPainter {
  final double zoom; DialPainter(this.zoom);
  @override void paint(Canvas c, Size s){
    var p = Paint()..color=Colors.white38..strokeWidth=1; var bp = Paint()..color=Colors.amber..strokeWidth=2;
    double cx = s.width/2;
    for(double i=0.6; i<=10; i+=0.2){ double x = cx + (i-zoom)*38; if(x<10||x>s.width-10) continue; bool maj = (i==0.6||i==1||i==2||i==4||i==10); double h=maj?18:8; c.drawLine(Offset(x,40), Offset(x,40+h), maj?bp:p); if(maj){ var tp=TextPainter(text: TextSpan(text: i==1?"1":i.toStringAsFixed(0), style: TextStyle(color: Colors.white70, fontSize: 9)), textDirection: TextDirection.ltr)..layout(); tp.paint(c, Offset(x-4,62)); } }
    c.drawLine(Offset(cx,30), Offset(cx,65), Paint()..color=Colors.amber..strokeWidth=2);
  }
  @override bool shouldRepaint(covariant DialPainter old)=> old.zoom!=zoom;
}
