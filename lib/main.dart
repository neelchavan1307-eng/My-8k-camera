import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

late List<CameraDescription> cameras;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MaterialApp(home: FinalCamera(), debugShowCheckedModeBanner: false));
}

class FinalCamera extends StatefulWidget {
  @override State<FinalCamera> createState() => _FinalCameraState();
}

class _FinalCameraState extends State<FinalCamera> {
  late CameraController c;
  bool ready = false, isRecording = false;
  double zoom = 1.0;
  String mode = "Photo";
  String filter = "Original";
  String? lastImagePath;
  Timer? timer;
  int sec = 0;

  List<String> modes = ["Ultra HD", "Video", "Photo", "Portrait", "Night"];
  List<String> filters = ["Original", "Vivid", "Cinematic", "Warm"];

  List<double> getFilter(){
    if(filter=="Vivid") return [1.3,0,0,0,-15, 0,1.3,0,0,-15, 0,0,1.3,0,-15, 0,0,0,1,0];
    if(filter=="Cinematic") return [0.9,0.1,0.1,0,5, 0.1,0.9,0.05,0,5, 0.05,0.1,1.0,0,5, 0,0,0,1,0];
    if(filter=="Warm") return [1.2,0,0,0,10, 0,1.1,0,0,5, 0,0,0.9,0,0, 0,0,0,1,0];
    return [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0];
  }

  @override void initState(){ super.initState(); init(); }
  Future<void> init() async {
    c = CameraController(cameras[0], ResolutionPreset.ultraHigh, enableAudio: true);
    await c.initialize();
    setState(()=> ready=true);
  }

  String formatTime(int s){ int m=s~/60; int sc=s%60; return "${m.toString().padLeft(2,'0')}:${sc.toString().padLeft(2,'0')}"; }

  Future<void> takePhoto() async {
    var x = await c.takePicture();
    var dir = await getApplicationDocumentsDirectory();
    String newPath = "${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";
    await File(x.path).copy(newPath);
    setState(()=> lastImagePath = newPath);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Photo Captured ✓")));
  }

  Future<void> startVideo() async {
    await c.startVideoRecording();
    setState(()=> isRecording=true); sec=0;
    timer = Timer.periodic(Duration(seconds: 1), (t){ setState(()=> sec++); });
  }

  Future<void> stopVideo() async {
    timer?.cancel();
    var x = await c.stopVideoRecording();
    var dir = await getApplicationDocumentsDirectory();
    String newPath = "${dir.path}/${DateTime.now().millisecondsSinceEpoch}.mp4";
    await File(x.path).copy(newPath);
    setState(()=> isRecording=false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Video Saved ${formatTime(sec)} ✓")));
  }

  @override Widget build(BuildContext context){
    if(!ready) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.yellow)));
    return Scaffold(backgroundColor: Colors.black, body: Stack(children: [
      Positioned.fill(child: ColorFiltered(colorFilter: ColorFilter.matrix(getFilter()), child: CameraPreview(c))),
      Positioned.fill(child: GestureDetector(
        onScaleUpdate: (d){ double nz=(zoom*d.scale).clamp(0.6,4.0); if((nz-zoom).abs()>0.01){ setState(()=> zoom=nz); c.setZoomLevel(nz);} },
        child: Container(color: Colors.transparent)
      )),
      if(isRecording) Positioned(top:50, left:0, right:0, child: Center(child: Container(padding: EdgeInsets.symmetric(horizontal:14,vertical:6), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)), child: Text("● REC ${formatTime(sec)}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),
      SafeArea(child: Padding(padding: EdgeInsets.all(12), child: Row(children: [Icon(Icons.flash_off, color: Colors.white), Spacer(), if(mode=="Photo") Container(padding: EdgeInsets.symmetric(horizontal:10,vertical:4), decoration: BoxDecoration(color: Colors.yellow, borderRadius: BorderRadius.circular(12)), child: Text("AI ON", style: TextStyle(fontSize:11, fontWeight: FontWeight.bold)))]))),
      Positioned(top:60, left:0, right:0, child: SizedBox(height:35, child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal:12), children: filters.map((f)=> GestureDetector(onTap: ()=> setState(()=> filter=f), child: Container(margin: EdgeInsets.only(right:8), padding: EdgeInsets.symmetric(horizontal:14), decoration: BoxDecoration(color: filter==f?Colors.yellow:Colors.black54, borderRadius: BorderRadius.circular(15)), child: Center(child: Text(f, style: TextStyle(color: filter==f?Colors.black:Colors.white, fontSize:12, fontWeight: FontWeight.bold)))))).toList()))),
      Positioned(bottom:0,left:0,right:0, child: Column(children: [
        Text("${zoom.toStringAsFixed(1)}x • $filter ${isRecording?'• ${formatTime(sec)}':''}", style: TextStyle(color: Colors.white, fontSize:12)),
        SizedBox(height:8),
        GestureDetector(onPanUpdate: (d){ double nz=(zoom - d.delta.dx*0.03).clamp(0.6,4.0); setState(()=> zoom=nz); c.setZoomLevel(nz); }, child: SizedBox(height:80, child: Stack(alignment: Alignment.center, children: [CustomPaint(size: Size(400,80), painter: DialPainter(zoom)), Container(width:3,height:15,color: Colors.yellow, margin: EdgeInsets.only(bottom:30))]))),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: modes.map((m)=> GestureDetector(onTap: ()=> setState(()=> mode=m), child: Text(m, style: TextStyle(color: mode==m?Colors.yellow:Colors.white60, fontSize:13, fontWeight: mode==m?FontWeight.bold:FontWeight.normal)))).toList()),
        SizedBox(height:18),
        Padding(padding: EdgeInsets.fromLTRB(20,0,20,30), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(
            onTap: (){
              if(lastImagePath==null){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Aadhi ek photo kadh!"))); return; }
              showDialog(context: context, builder: (_)=> Dialog(backgroundColor: Colors.black, child: Column(mainAxisSize: MainAxisSize.min, children: [Image.file(File(lastImagePath!)), SizedBox(height:10), TextButton(onPressed: ()=> Navigator.pop(context), child: Text("Band Kara", style: TextStyle(color: Colors.yellow)))])));
            },
            child: Container(width:44,height:44, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8), image: lastImagePath!=null? DecorationImage(image: FileImage(File(lastImagePath!)), fit: BoxFit.cover):null), child: lastImagePath==null? Icon(Icons.photo, color: Colors.white):null),
          ),
          GestureDetector(
            onTap: () async { if(mode=="Video"){ if(isRecording) await stopVideo(); else await startVideo(); } else { await takePhoto(); } },
            child: Container(width:72,height:72, decoration: BoxDecoration(color: isRecording?Colors.red:Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.yellow, width:3)), child: Icon(mode=="Video"? (isRecording?Icons.stop:Icons.videocam):Icons.camera_alt, color: isRecording?Colors.white:Colors.black)),
          ),
          Icon(Icons.cameraswitch, color: Colors.white, size:28),
        ])),
      ])),
    ]));
  }
}
class DialPainter extends CustomPainter {
  final double zoom; DialPainter(this.zoom);
  @override void paint(Canvas c, Size s){
    var sp=Paint()..color=Colors.white38..strokeWidth=1; var bp=Paint()..color=Colors.white..strokeWidth=1.5;
    for(double i=0.6;i<=4.0;i+=0.1){ double x=s.width/2 + (i-zoom)*70; if(x<15||x>s.width-15) continue; bool big=(i==0.6||i==1.0||i==2.0||i==4.0); c.drawLine(Offset(x,25), Offset(x,25+(big?16:7)), big?bp:sp); if(big){ String t=i==0.6?"0.6": i==1.0?"1\n25mm":"${i.toInt()}"; var tp=TextPainter(text: TextSpan(text: t, style: TextStyle(color: Colors.white70, fontSize:9)), textDirection: TextDirection.ltr)..layout(); tp.paint(c, Offset(x-7,50)); } }
  }
  @override bool shouldRepaint(covariant DialPainter old)=> old.zoom!=zoom;
}
