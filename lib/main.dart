import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

late List<CameraDescription> cameras;
Future<void> main() async { WidgetsFlutterBinding.ensureInitialized(); cameras = await availableCameras(); runApp(MaterialApp(home: HighCamera(), debugShowCheckedModeBanner: false)); }

class HighCamera extends StatefulWidget { @override State<HighCamera> createState() => _HighCameraState(); }

class _HighCameraState extends State<HighCamera> {
  late CameraController controller; bool ready = false; bool isPro = true; bool ai = true;
  String mode = "PHOTO"; String filter = "Cinematic"; double zoom = 1.0; double ev = 0.0; int cam = 0;

  Map<String, List<double>> f = {
    "Original": [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0],
    "Vivid": [1.4,0,0,0,0, 0,1.4,0,0,0, 0,0,1.4,0,0, 0,0,0,1,0],
    "B&W": [0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0,0,0,1,0],
    "Cinematic": [1.15,0.1,0,0,10, 0.05,1.1,0,0,5, 0,0,0.9,0,-5, 0,0,0,1,0],
    "Warm": [1.25,0,0,0,15, 0,1.1,0,0,8, 0,0,0.8,0,0, 0,0,0,1,0],
    "Cold": [0.9,0,0,0,0, 0,1,0,0,0, 0,0,1.25,0,15, 0,0,0,1,0],
  };

  @override
  void initState() { super.initState(); start(0); }
  Future<void> start(int i) async {
    if(ready) await controller.dispose();
    setState(()=> ready=false);
    controller = CameraController(cameras[i % cameras.length], ResolutionPreset.high, enableAudio: true);
    await controller.initialize();
    if(mounted) setState(()=> ready=true);
  }

  List<double> getFilter() {
    var base = f[filter]!;
    if(!ai) return base;
    return [base[0]*1.15, base[1], base[2], base[3], base[4]+10, base[5], base[6]*1.15, base[7], base[8], base[9]+10, base[10], base[11], base[12]*1.15, base[13], base[14]+10, 0,0,0,1,0];
  }

  @override
  Widget build(BuildContext context) {
    if(!ready) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.yellow)));
    return Scaffold(backgroundColor: Colors.black, body: Stack(children: [
      Positioned.fill(child: ColorFiltered(colorFilter: ColorFilter.matrix(getFilter()), child: CameraPreview(controller))),
      SafeArea(child: Padding(padding: EdgeInsets.all(10), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            _btn(Icons.cameraswitch, ()=> start(cam==0?1:0)),
            SizedBox(width:8),
            _btn(Icons.macro_off, (){ setState(()=> zoom=zoom==1.0?2.8:1.0); controller.setZoomLevel(zoom); }, active: zoom>2),
            SizedBox(width:8),
            _btn(Icons.auto_awesome, ()=> setState(()=> ai=!ai), active: ai),
          ]),
          Container(padding: EdgeInsets.symmetric(horizontal:10,vertical:5), decoration: BoxDecoration(color: Colors.yellow, borderRadius: BorderRadius.circular(20)), child: Text("4K • PRO • AI", style: TextStyle(color: Colors.black, fontSize:10, fontWeight: FontWeight.bold))),
        ]),
        SizedBox(height:12),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: f.keys.map((k)=> GestureDetector(onTap: ()=> setState(()=> filter=k), child: Container(margin: EdgeInsets.only(right:6), padding: EdgeInsets.symmetric(horizontal:14,vertical:7), decoration: BoxDecoration(color: filter==k?Colors.yellow:Colors.black54, borderRadius: BorderRadius.circular(20), border: k=="Cinematic"?Border.all(color: Colors.yellow,width:1):null), child: Text(k, style: TextStyle(color: filter==k?Colors.black:Colors.white, fontSize:11, fontWeight: FontWeight.bold))))).toList())),
        SizedBox(height:10),
        Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12)), child: Column(children: [
          Row(children: [Text("ZOOM ${zoom.toStringAsFixed(1)}x", style: TextStyle(color: Colors.white, fontSize:10)), Expanded(child: Slider(value: zoom, min:1, max:6, activeColor: Colors.yellow, onChanged: (v){ setState(()=>zoom=v); controller.setZoomLevel(v); }))]),
          Row(children: [Text("EV ${ev.toStringAsFixed(1)}", style: TextStyle(color: Colors.white, fontSize:10)), Expanded(child: Slider(value: ev, min:-2, max:2, activeColor: Colors.yellow, onChanged: (v){ setState(()=>ev=v); controller.setExposureOffset(v); }))]),
          Text("CINEMATIC COLOUR GRADING + AI ENHANCE = ON", style: TextStyle(color: Colors.yellow, fontSize:8, fontWeight: FontWeight.bold)),
        ])),
      ]))),
      Positioned(bottom:0,left:0,right:0, child: Container(padding: EdgeInsets.fromLTRB(15,10,15,30), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black])), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _mode("PRO", true, (){}),
          _mode("PHOTO", mode=="PHOTO", ()=> setState(()=> mode="PHOTO")),
          _mode("VIDEO", mode=="VIDEO", ()=> setState(()=> mode="VIDEO")),
          _mode("CINEMATIC", filter=="Cinematic", ()=> setState(()=> filter="Cinematic")),
          _mode("MACRO", zoom>2, ()=> setState(()=> zoom=2.8)),
        ]),
        SizedBox(height:18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          Icon(Icons.photo_library, color: Colors.white, size:28),
          Container(width:80,height:80, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.yellow, width:4)), child: Icon(Icons.camera_alt, size:35)),
          Icon(Icons.tune, color: Colors.yellow, size:28),
        ]),
      ]))),
    ]));
  }
  Widget _btn(IconData i, VoidCallback t, {bool active=false}) => GestureDetector(onTap: t, child: Container(padding: EdgeInsets.all(9), decoration: BoxDecoration(color: active?Colors.yellow:Colors.black54, shape: BoxShape.circle), child: Icon(i, color: active?Colors.black:Colors.white, size:18)));
  Widget _mode(String t, bool a, VoidCallback tap) => GestureDetector(onTap: tap, child: Text(t, style: TextStyle(color: a?Colors.yellow:Colors.white70, fontWeight: a?FontWeight.bold:FontWeight.w600, fontSize:11)));
}
