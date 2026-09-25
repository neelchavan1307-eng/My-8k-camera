import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> cameras = [];
void main() async { WidgetsFlutterBinding.ensureInitialized(); cameras = await availableCameras(); runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: DialCamera())); }

class DialCamera extends StatefulWidget { const DialCamera({super.key}); @override State<DialCamera> createState()=> _DialCameraState(); }

class _DialCameraState extends State<DialCamera> {
  CameraController? c; bool ready=false, rec=false; double zoom=1.0, maxZoom=10.0; String mode="Photo"; Timer? recTimer; int sec=0; FlashMode flash=FlashMode.off;

  Future<void> initCam() async {
    await [Permission.camera, Permission.microphone, Permission.photos].request();
    c = CameraController(cameras[0], ResolutionPreset.ultraHigh, enableAudio:true);
    await c!.initialize(); maxZoom=await c!.getMaxZoomLevel(); if(maxZoom>10) maxZoom=10; setState(()=> ready=true);
  }
  @override void initState(){ super.initState(); initCam(); }
  String fmt(int s)=> "${(s~/60).toString().padLeft(2,'0')}:${(s%60).toString().padLeft(2,'0')}";

  Future<void> setZoom(double z) async { if(z<0.6) z=0.6; if(z>maxZoom) z=maxZoom; await c!.setZoomLevel(z); setState(()=> zoom=z); }

  Future<void> shoot() async {
    if(mode=="Video"){
      if(rec){ recTimer?.cancel(); var f=await c!.stopVideoRecording(); await Gal.putVideo(f.path); setState(()=> rec=false); sec=0; }
      else { await c!.startVideoRecording(); setState(()=> rec=true); recTimer=Timer.periodic(const Duration(seconds:1), (t){ setState(()=> sec++); }); }
    } else { var f=await c!.takePicture(); await Gal.putImage(f.path); }
  }

  @override Widget build(BuildContext context){
    if(!ready) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    return Scaffold(backgroundColor: Colors.black, body: Stack(children:[
      SizedBox.expand(child: CameraPreview(c!)),

      // REC TIMER - FIXED
      if(rec) Positioned(top: 0, left:0, right:0, child: SafeArea(child: Center(child: Container(margin: const EdgeInsets.only(top:12), padding: const EdgeInsets.symmetric(horizontal:14, vertical:6), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)), child: Text("REC ${fmt(sec)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize:13)))))),
      if(rec) Positioned(top: 80, left:0, right:0, child: Center(child: Text(fmt(sec), style: const TextStyle(color: Colors.white, fontSize:20, fontWeight: FontWeight.bold)))),

      // Top
      SafeArea(child: Padding(padding: const EdgeInsets.all(14), child: Row(children:[ GestureDetector(onTap: () async { flash=flash==FlashMode.off?FlashMode.always:FlashMode.off; await c!.setFlashMode(flash); setState((){}); }, child: Icon(flash==FlashMode.off?Icons.flash_off:Icons.flash_on, color: Colors.white)), const SizedBox(width:18), const Icon(Icons.center_focus_strong, color: Colors.white), ])))),

      // BOTTOM - EXACT PHOTO STYLE
      Positioned(bottom:0,left:0,right:0,child: Container(height: 260, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors:[Colors.black, Colors.transparent])), child: Stack(alignment: Alignment.bottomCenter, children:[

        // ZOOM DIAL ARC - PHOTO SARKE
        Positioned(bottom: 70, left:0, right:0, child: Column(children:[
          Text("${zoom.toStringAsFixed(1)}x", style: const TextStyle(color: Colors.white, fontSize:22, fontWeight: FontWeight.w300)),
          const SizedBox(height:6),
          GestureDetector(
            onPanUpdate: (d){ double delta = -d.delta.dx * 0.05; setZoom(zoom+delta); },
            child: SizedBox(height: 110, width: double.infinity, child: CustomPaint(painter: DialPainter(zoom: zoom, maxZoom: maxZoom))),
          ),
          // Modes like photo
          Padding(padding: const EdgeInsets.symmetric(horizontal:20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: ["Ultra HD","Video","Photo","Portrait","Night"].map((m){ bool sel=m==mode; return GestureDetector(onTap: ()=> setState(()=> mode=m), child: Text(m, style: TextStyle(color: sel?Colors.amber:Colors.white70, fontSize:13, fontWeight: sel?FontWeight.bold:FontWeight.normal))); }).toList())),
        ])),

        // Shutter Row
        Positioned(bottom: 18, left:20, right:20, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
          Container(width:44,height:44, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(6), image: const DecorationImage(image: AssetImage(''), fit: BoxFit.cover)), child: const Icon(Icons.photo, color: Colors.white70, size:18)),
          GestureDetector(onTap: shoot, child: Container(width:72,height:72,decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width:3)), child: Icon(rec?Icons.stop:Icons.circle, color: rec?Colors.red:Colors.white, size: rec?30:68))),
          IconButton(onPressed: () async { var nc=c!.description==cameras[0]? (cameras.length>1?cameras[1]:cameras[0]):cameras[0]; c=CameraController(nc, ResolutionPreset.ultraHigh, enableAudio:true); await c!.initialize(); setState((){}); }, icon: const Icon(Icons.flip_camera_ios_outlined, color: Colors.white, size:28)),
        ])),
      ])))
    ]));
  }
}

class DialPainter extends CustomPainter {
  final double zoom; final double maxZoom;
  DialPainter({required this.zoom, required this.maxZoom});
  @override void paint(Canvas canvas, Size size){
    double centerX = size.width/2; double centerY = size.height; double radius = size.width*0.48;
    Paint arcPaint = Paint()..color=Colors.white.withOpacity(0.3)..style=PaintingStyle.stroke..strokeWidth=12..strokeCap=StrokeCap.round;
    Paint activePaint = Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=1.2;
    Paint yellowTick = Paint()..color=Colors.amber..strokeWidth=2.5;

    // Base arc background
    Rect rect = Rect.fromCircle(center: Offset(centerX, centerY), radius: radius);
    canvas.drawArc(rect, pi, pi, false, Paint()..color=Colors.white.withOpacity(0.15)..style=PaintingStyle.fill);

    // Ticks 0.6 to 10
    for(double z=0.6; z<=maxZoom; z+=0.2){
      double angle = pi + (z/maxZoom)*pi; // map
      double tickLen = (z==1||z==2||z==4||z==6||z==8||z==10)? 16 : 8;
      double x1 = centerX + radius*cos(angle); double y1 = centerY + radius*sin(angle);
      double x2 = centerX + (radius-tickLen)*cos(angle); double y2 = centerY + (radius-tickLen)*sin(angle);
      bool isCurrent = (zoom-z).abs()<0.15;
      canvas.drawLine(Offset(x1,y1), Offset(x2,y2), isCurrent? yellowTick : activePaint);
      if(z==1||z==2||z==4||z==6||z==8||z==10){
        double lx = centerX + (radius-28)*cos(angle); double ly = centerY + (radius-28)*sin(angle);
        TextPainter tp = TextPainter(text: TextSpan(text: z.toInt().toString(), style: const TextStyle(color: Colors.white70, fontSize:11)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(lx-tp.width/2, ly-tp.height/2));
      }
    }
    // Center marker
    double curAngle = pi + (zoom/maxZoom)*pi;
    double mx = centerX + radius*cos(curAngle); double my = centerY + radius*sin(curAngle);
    canvas.drawLine(Offset(mx,my), Offset(centerX + (radius-20)*cos(curAngle), centerY + (radius-20)*sin(curAngle)), yellowTick);
    // Bottom line
    canvas.drawLine(Offset(centerX-10, centerY-2), Offset(centerX+10, centerY-2), Paint()..color=Colors.white54..strokeWidth=2);
  }
  @override bool shouldRepaint(covariant DialPainter old)=> old.zoom!=zoom;
}
