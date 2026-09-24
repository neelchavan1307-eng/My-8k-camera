import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

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
  bool ready=false;
  double zoom=1.0;
  String mode="Photo";
  String filter="Original";
  List<String> modes = ["Ultra HD", "Video", "Photo", "Portrait", "Night"];
  List<String> filters = ["Original", "Vivid", "Cinematic", "Warm"];

  List<double> getFilterMatrix(){
    if(filter=="Vivid") return [1.3,0,0,0,-15, 0,1.3,0,0,-15, 0,0,1.3,0,-15, 0,0,0,1,0];
    if(filter=="Cinematic") return [0.9,0.1,0.1,0,5, 0.1,0.9,0.05,0,5, 0.05,0.1,1.0,0,5, 0,0,0,1,0];
    if(filter=="Warm") return [1.2,0,0,0,10, 0,1.1,0,0,5, 0,0,0.9,0,0, 0,0,0,1,0];
    return [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0];
  }

  @override void initState(){ super.initState(); init(); }
  Future<void> init() async {
    c = CameraController(cameras[0], ResolutionPreset.high);
    await c.initialize();
    setState(()=> ready=true);
  }

  @override Widget build(BuildContext context){
    if(!ready) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.yellow)));
    return Scaffold(backgroundColor: Colors.black, body: Stack(children: [
      Positioned.fill(child: ColorFiltered(colorFilter: ColorFilter.matrix(getFilterMatrix()), child: CameraPreview(c))),
      Positioned.fill(child: GestureDetector(onScaleUpdate: (d){ double nz = (zoom * d.scale).clamp(0.6, 4.0); if((nz - zoom).abs() > 0.01){ setState(()=> zoom=nz); c.setZoomLevel(zoom); } }, child: Container(color: Colors.transparent))),

      SafeArea(child: Padding(padding: EdgeInsets.all(12), child: Column(children: [
        Row(children: [Icon(Icons.flash_off, color: Colors.white), Spacer(), Container(padding: EdgeInsets.symmetric(horizontal:10,vertical:4), decoration: BoxDecoration(color: Colors.yellow, borderRadius: BorderRadius.circular(12)), child: Text("AI ON", style: TextStyle(fontSize:11, fontWeight: FontWeight.bold)))]),
        SizedBox(height:15),
        SizedBox(height:35, child: ListView(scrollDirection: Axis.horizontal, children: filters.map((f)=> GestureDetector(onTap: ()=> setState(()=> filter=f), child: Container(margin: EdgeInsets.only(right:8), padding: EdgeInsets.symmetric(horizontal:14), decoration: BoxDecoration(color: filter==f?Colors.yellow:Colors.black54, borderRadius: BorderRadius.circular(15)), child: Center(child: Text(f, style: TextStyle(color: filter==f?Colors.black:Colors.white, fontWeight: FontWeight.bold, fontSize:12)))))).toList())),
      ]))),

      Positioned(bottom:0,left:0,right:0, child: Column(children: [
        Text("${zoom.toStringAsFixed(1)}x • $filter", style: TextStyle(color: Colors.white, fontSize:14)),
        SizedBox(height:8),
        GestureDetector(onPanUpdate: (d){ double nz = (zoom - d.delta.dx * 0.03).clamp(0.6, 4.0); setState(()=> zoom=nz); c.setZoomLevel(nz); }, child: SizedBox(height: 80, child: Stack(alignment: Alignment.center, children: [CustomPaint(size: Size(400, 80), painter: DialPainter(zoom)), Container(width:3, height:15, color: Colors.yellow, margin: EdgeInsets.only(bottom:30))]))),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: modes.map((m)=> GestureDetector(onTap: ()=> setState(()=> mode=m), child: Text(m, style: TextStyle(color: mode==m?Colors.yellow:Colors.white60, fontSize:13, fontWeight: mode==m?FontWeight.bold:FontWeight.normal)))).toList()),
        SizedBox(height:18),
        Padding(padding: EdgeInsets.fromLTRB(20,0,20,30), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(width:38,height:38, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(6))),
          GestureDetector(onTap: () async { var f = await c.takePicture(); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Clicked ${zoom}x $filter! Saved to ${f.path.split('/').last}"))); }, child: Container(width:70,height:70, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.yellow, width:3)))),
          Icon(Icons.cameraswitch, color: Colors.white, size:28),
        ])),
      ])),
    ]));
  }
}

class DialPainter extends CustomPainter {
  final double zoom; DialPainter(this.zoom);
  @override void paint(Canvas c, Size s){
    var small = Paint()..color=Colors.white38..strokeWidth=1;
    var big = Paint()..color=Colors.white..strokeWidth=1.5;
    for(double i=0.6; i<=4.0; i+=0.1){
      double x = s.width/2 + (i - zoom) * 70;
      if(x < 15 || x > s.width-15) continue;
      bool isBig = (i==0.6||i==1.0||i==2.0||i==4.0);
      c.drawLine(Offset(x, 25), Offset(x, 25+(isBig?16:7)), isBig?big:small);
      if(isBig){
        String txt = i==0.6?"0.6": i==1.0?"1\n25mm" : "${i.toInt()}";
        var tp = TextPainter(text: TextSpan(text: txt, style: TextStyle(color: Colors.white70, fontSize:9)), textDirection: TextDirection.ltr)..layout();
        tp.paint(c, Offset(x-7, 50));
      }
    }
  }
  @override bool shouldRepaint(covariant DialPainter old) => old.zoom!=zoom;
}
