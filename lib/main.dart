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
  String filter="Original";
  bool aiOn=true;
  List<String> modes = ["Ultra HD", "Video", "Photo", "Portrait", "Night"];
  List<String> filters = ["Original", "Vivid", "Cinematic", "Warm", "B&W"];

  @override void initState(){ super.initState(); init(); }
  Future<void> init() async {
    c = CameraController(cameras[0], ResolutionPreset.high);
    await c.initialize();
    setState(()=> ready=true);
  }

  List<double> getFilter(){
    if(filter=="Vivid") return [1.3,0,0,0,-15, 0,1.3,0,0,-15, 0,0,1.3,0,-15, 0,0,0,1,0];
    if(filter=="Cinematic") return [0.9,0.1,0.1,0,5, 0.1,0.9,0.05,0,5, 0.05,0.1,1.0,0,5, 0,0,0,1,0];
    if(filter=="Warm") return [1.2,0,0,0,10, 0,1.1,0,0,5, 0,0,0.9,0,0, 0,0,0,1,0];
    if(filter=="B&W") return [0.33,0.33,0.33,0,0, 0.33,0.33,0.33,0,0, 0.33,0.33,0.33,0,0, 0,0,0,1,0];
    return [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0];
  }

  @override Widget build(BuildContext context){
    if(!ready) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.yellow)));
    return Scaffold(backgroundColor: Colors.black, body: Stack(children: [
      Positioned.fill(child: ColorFiltered(colorFilter: ColorFilter.matrix(getFilter()), child: CameraPreview(c))),
      Positioned.fill(child: GestureDetector(onScaleUpdate: (d){ double nz = (zoom * d.scale).clamp(0.6, 4.0); if((nz - zoom).abs() > 0.01){ setState(()=> zoom=nz); c.setZoomLevel(zoom); } }, child: Container(color: Colors.transparent))),

      // Top - Filter + AI
      SafeArea(child: Column(children: [
        Padding(padding: EdgeInsets.all(12), child: Row(children: [Icon(Icons.flash_off, color: Colors.white), Spacer(), GestureDetector(onTap: ()=> setState(()=> aiOn=!aiOn), child: Container(padding: EdgeInsets.symmetric(horizontal:10,vertical:4), decoration: BoxDecoration(color: aiOn?Colors.yellow:Colors.black54, borderRadius: BorderRadius.circular(15)), child: Text("AI ${aiOn?"ON":"OFF"}", style: TextStyle(color: aiOn?Colors.black:Colors.white, fontSize:11, fontWeight: FontWeight.bold))))])),
        SizedBox(height:60, child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.only(left:12), children: filters.map((f)=> GestureDetector(onTap: ()=> setState(()=> filter=f), child: Container(margin: EdgeInsets.only(right:10), padding: EdgeInsets.symmetric(horizontal:16,vertical:8), decoration: BoxDecoration(color: filter==f?Colors.yellow:Colors.black54, borderRadius: BorderRadius.circular(20)), child: Center(child: Text(f, style: TextStyle(color: filter==f?Colors.black:Colors.white, fontWeight: FontWeight.bold)))))).toList())),
      ])),

      // Bottom - Smooth Dial + Shutter
      Positioned(bottom:0,left:0,right:0, child: Column(children: [
        Text("${zoom.toStringAsFixed(1)}x • $filter", style: TextStyle(color: Colors.white, fontSize:16)),
        SizedBox(height:10),
        GestureDetector(onPanUpdate: (d){ double newZoom = (zoom - d.delta.dx * 0.03).clamp(0.6, 4.0); setState(()=> zoom = newZoom); c.setZoomLevel(zoom); }, child: SizedBox(height: 85, child: Stack(alignment: Alignment.center, children: [CustomPaint(size: Size(400, 85), painter: DialPainter(zoom)), Container(width:3, height:16, color: Colors.yellow, margin: EdgeInsets.only(bottom:35))]))),
        SizedBox(height:5),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: modes.map((m)=> GestureDetector(onTap: ()=> setState(()=> mode=m), child: Text(m, style: TextStyle(color: mode==m?Colors.yellow:Colors.white60, fontSize:13, fontWeight: mode==m?FontWeight.bold:FontWeight.normal)))).toList()),
        SizedBox(height:20),
        Padding(padding: EdgeInsets.fromLTRB(25,0,25,35), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(width:40,height:40, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8), image: DecorationImage(image: NetworkImage("https://images.unsplash.com/photo-1518895949257-7621c3c786d7"), fit: BoxFit.cover))),
          GestureDetector(onTap: () async { var f = await c.takePicture(); await Gal.putImage(f.path); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Saved $filter!"), backgroundColor: Colors.yellow)); }, child: Container(width:75,height:75, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.yellow, width:3)))),
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
      c.drawLine(Offset(x, 30), Offset(x, 30+(isBig?18:8)), isBig?big:small);
      if(isBig){
        String txt = i==0.6?"0.6": i==1.0?"1\n25mm" : "${i.toInt()}";
        var tp = TextPainter(text: TextSpan(text: txt, style: TextStyle(color: Colors.white70, fontSize:10)), textDirection: TextDirection.ltr)..layout();
        tp.paint(c, Offset(x-8, 55));
      }
    }
  }
  @override bool shouldRepaint(covariant DialPainter old) => old.zoom!= zoom;
}
