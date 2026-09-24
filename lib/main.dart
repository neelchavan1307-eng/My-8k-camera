import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';

late List<CameraDescription> cameras;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MaterialApp(home: SmoothCamera(), debugShowCheckedModeBanner: false));
}

class SmoothCamera extends StatefulWidget {
  @override State<SmoothCamera> createState() => _SmoothCameraState();
}

class _SmoothCameraState extends State<SmoothCamera> {
  late CameraController c;
  bool ready=false;
  double zoom=1.4;
  String mode="Photo";
  List<String> modes = ["Ultra HD", "Video", "Photo", "Portrait", "Night"];

  @override void initState(){ super.initState(); init(); }
  Future<void> init() async {
    c = CameraController(cameras[0], ResolutionPreset.high);
    await c.initialize();
    setState(()=> ready=true);
  }

  @override Widget build(BuildContext context){
    if(!ready) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.yellow)));

    return Scaffold(backgroundColor: Colors.black, body: Stack(children: [
      Positioned.fill(child: CameraPreview(c)),

      // STEP 4: Full screen var pinch zoom sathi ha
      Positioned.fill(child: GestureDetector(
        onScaleUpdate: (d){
          double nz = (zoom * d.scale).clamp(0.6, 4.0);
          if((nz - zoom).abs() > 0.01){ setState(()=> zoom=nz); c.setZoomLevel(zoom); }
        },
        child: Container(color: Colors.transparent),
      )),

      // Top bar
      SafeArea(child: Padding(padding: EdgeInsets.all(15), child: Row(children: [
        Icon(Icons.flash_off, color: Colors.white), SizedBox(width:20),
        Icon(Icons.filter_center_focus, color: Colors.white),
      ]))),

      // Bottom UI - tuja photo sarkha
      Positioned(bottom:0,left:0,right:0, child: Column(children: [
        Text("${zoom.toStringAsFixed(1)}x", style: TextStyle(color: Colors.white, fontSize:22)),
        SizedBox(height:10),

        // STEP 5: Ha aahe SMOOTH DIAL - yala drag kar
        GestureDetector(
          onPanUpdate: (d){
            double newZoom = (zoom - d.delta.dx * 0.03).clamp(0.6, 4.0);
            setState(()=> zoom = newZoom);
            c.setZoomLevel(zoom);
          },
          child: SizedBox(height: 85, child: Stack(alignment: Alignment.center, children: [
            CustomPaint(size: Size(400, 85), painter: DialPainter(zoom)),
            Container(width:3, height:16, color: Colors.yellow, margin: EdgeInsets.only(bottom:35)), // yellow line
          ])),
        ),

        SizedBox(height:5),
        // Modes
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: modes.map((m)=> GestureDetector(
          onTap: ()=> setState(()=> mode=m),
          child: Text(m, style: TextStyle(color: mode==m?Colors.yellow:Colors.white60, fontSize:14, fontWeight: mode==m?FontWeight.bold:FontWeight.normal))
        )).toList()),
        SizedBox(height:20),

        // Shutter button
        Padding(padding: EdgeInsets.fromLTRB(25,0,25,35), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(width:40,height:40, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8))),
          GestureDetector(
            onTap: () async { var f = await c.takePicture(); await Gal.putImage(f.path); },
            child: Container(width:75,height:75, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width:4))),
          ),
          Icon(Icons.flip_camera_ios, color: Colors.white, size:30),
        ])),
      ])),
    ]));
  }
}

class DialPainter extends CustomPainter {
  final double zoom; DialPainter(this.zoom);
  @override void paint(Canvas c, Size s){
    var small = Paint()..color=Colors.white38..strokeWidth=1;
    var big = Paint()..color=Colors.white..strokeWidth=2;
    for(double i=0.6; i<=4.0; i+=0.1){
      double x = s.width/2 + (i - zoom) * 70;
      if(x < 20 || x > s.width-20) continue;
      bool isBig = (i==0.6||i==1.0||i==2.0||i==4.0);
      double h = isBig?18:8;
      c.drawLine(Offset(x, 30), Offset(x, 30+h), isBig?big:small);
      if(isBig){
        String txt = i==0.6?"0.6": i==1.0?"1\n25mm" : "${i.toInt()}";
        var tp = TextPainter(text: TextSpan(text: txt, style: TextStyle(color: Colors.white70, fontSize:10)), textDirection: TextDirection.ltr)..layout();
        tp.paint(c, Offset(x-8, 55));
      }
    }
  }
  @override bool shouldRepaint(covariant DialPainter old) => old.zoom!= zoom;
}
