import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

List<CameraDescription> cameras = [];
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: KillerCam()));
}

class KillerCam extends StatefulWidget { @override State<KillerCam> createState() => _KillerCamState(); }

class _KillerCamState extends State<KillerCam> {
  CameraController? c;
  bool rec = false; int s = 0; Timer? t;
  double zoom = 1.0; double exp = 0.0; double beauty = 0.0;
  FlashMode flash = FlashMode.off;
  int camIdx = 0;
  String filter = "Original";
  String quality = "4K";
  bool slowMo = false;
  ResolutionPreset res = ResolutionPreset.ultraHigh;

  @override void initState() { super.initState(); _init(0); }
  Future<void> _init(int i) async {
    c = CameraController(cameras[i], res, enableAudio: true);
    await c!.initialize(); await c!.setExposureMode(ExposureMode.auto);
    if(mounted) setState(() {});
  }
  Future<void> changeRes(String q) async {
    setState((){ quality=q; });
    if(q=="4K") res=ResolutionPreset.ultraHigh;
    if(q=="FHD") res=ResolutionPreset.high;
    if(q=="HD") res=ResolutionPreset.medium;
    await c!.dispose(); await _init(camIdx);
  }

  void photo() async {
    HapticFeedback.heavyImpact();
    try { await c!.takePicture(); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚡ $filter | $quality | ${slowMo?"SLO-MO ":""}KATAK!'), backgroundColor: Colors.amber, duration: Duration(milliseconds: 800))); } catch(e){}
  }
  void startV() async { await c!.startVideoRecording(); setState((){ rec=true; s=0; }); t=Timer.periodic(Duration(milliseconds: slowMo?500:1000), (x){ setState(()=>s++); }); }
  void stopV() async { t?.cancel(); await c!.stopVideoRecording(); setState((){ rec=false; s=0; }); }
  String get tm => "${(s~/60).toString().padLeft(2,'0')}:${(s%60).toString().padLeft(2,'0')}";

  ColorFilter getFilter() {
    double b = beauty;
    switch(filter){
      case "RRR": return ColorFilter.matrix([1.3+b,0,0,0,-10, 0,1.1+b,0,0,-10, 0,0,0.9,0,5, 0,0,0,1,0]);
      case "KGF": return ColorFilter.matrix([1.4,0,0,0,20, 0.1,1.2,0,0,-10, -0.2,0,0.7,0,-30, 0,0,0,1,0]);
      case "Cinematic": return ColorFilter.matrix([1.1,0,0,0,0, 0,1,0,0,0, 0,0,1.3,0,0, 0,0,0,1,0]);
      case "DSLR": return ColorFilter.matrix([1.2+b,0,0,0,10, 0,1.2+b,0,0,10, 0,0,1.2,0,10, 0,0,0,1,0]);
      case "Beauty": return ColorFilter.matrix([1.1+b,0,0,0,15, 0,1.1+b,0,0,15, 0,0,1.1+b,0,15, 0,0,0,1,0]);
      case "B&W": return ColorFilter.matrix([0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0,0,0,1,0]);
      case "Vintage": return ColorFilter.matrix([1.1,0,0,0,10, 0.2,1,0,0,5, 0,0,0.8,0,0, 0,0,0,1,0]);
      default: return ColorFilter.matrix([1+b*0.3,0,0,0,b*10, 0,1+b*0.3,0,0,b*10, 0,0,1+b*0.3,0,b*10, 0,0,0,1,0]);
    }
  }

  @override Widget build(BuildContext context) {
    if(c==null ||!c!.value.isInitialized) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.amber)));
    return Scaffold(backgroundColor: Colors.black, body: Stack(children: [
      ColorFiltered(colorFilter: getFilter(), child: SizedBox.expand(child: CameraPreview(c!))),
      if(filter=="Cinematic")...[Align(alignment: Alignment.topCenter, child: Container(height:80, color: Colors.black)), Align(alignment: Alignment.bottomCenter, child: Container(height:120, color: Colors.black))],

      SafeArea(child: Column(children: [
        SizedBox(height:8),
        Center(child: Container(padding: EdgeInsets.symmetric(horizontal:12, vertical:5), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)), child: Text("KILLER • $filter • $quality ${slowMo?"• SLO-MO 0.5x":""} • ${zoom}x ${rec?'• $tm 🔴':''}", style: TextStyle(fontWeight: FontWeight.bold, fontSize:10)))),
        SizedBox(height:6),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ["Original","RRR","KGF","Cinematic","DSLR","Beauty","B&W","Vintage"].map((f)=>Padding(padding: EdgeInsets.symmetric(horizontal:3), child: ChoiceChip(label: Text(f, style:TextStyle(fontSize:11)), selected: filter==f, selectedColor: Colors.amber, onSelected: (v){ setState(()=>filter=f); }))).toList())),
        SizedBox(height:6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _ic(flash==FlashMode.off?Icons.flash_off:Icons.flash_on, () async { flash=flash==FlashMode.off?FlashMode.torch:FlashMode.off; await c!.setFlashMode(flash); setState((){}); }),
          Container(padding: EdgeInsets.symmetric(horizontal:6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)), child: DropdownButton<String>(value: quality, dropdownColor: Colors.black, underline: SizedBox(), style: TextStyle(color: Colors.white, fontSize:11), items: ["HD","FHD","4K"].map((e)=>DropdownMenuItem(value:e, child: Text(e))).toList(), onChanged: (v)=>changeRes(v!))),
          Container(padding: EdgeInsets.symmetric(horizontal:6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)), child: DropdownButton<double>(value: zoom, dropdownColor: Colors.black, underline: SizedBox(), style: TextStyle(color: Colors.white, fontSize:11), items: [1.0,2.0,3.0,5.0,10.0].map((e)=>DropdownMenuItem(value:e, child: Text("${e}x"))).toList(), onChanged: (v) async { zoom=v!; await c!.setZoomLevel(zoom); setState((){}); })),
          InkWell(onTap:(){ setState(()=>slowMo=!slowMo); }, child: Container(padding: EdgeInsets.symmetric(horizontal:10, vertical:6), decoration: BoxDecoration(color: slowMo?Colors.amber:Colors.black54, borderRadius: BorderRadius.circular(10)), child: Text("SLO-MO", style: TextStyle(color: slowMo?Colors.black:Colors.white, fontSize:10, fontWeight: FontWeight.bold)))),
        ]),
        if(filter=="Beauty" || filter=="Original" || filter=="DSLR") Padding(padding: EdgeInsets.symmetric(horizontal:20), child: Row(children: [Icon(Icons.face_retouching_natural, color: Colors.white, size:16), Expanded(child: Slider(value: beauty, min:0, max:0.5, activeColor: Colors.pink, onChanged: (v){ setState(()=>beauty=v); })), Text("${(beauty*100).toInt()}%", style:TextStyle(color:Colors.white, fontSize:10)) ])),
      ])),
      Positioned(right:0, top:220, bottom:150, child: RotatedBox(quarterTurns: 3, child: Slider(value: exp, min: -2, max: 2, activeColor: Colors.amber, onChanged: (v) async { exp=v; await c!.setExposureOffset(v); setState((){}); }))),
      Align(alignment: Alignment.bottomCenter, child: Padding(padding: EdgeInsets.only(bottom:20, left:20, right:20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _ic(Icons.photo_library, (){}, size: 28),
        GestureDetector(onTap: (){ if(rec) stopV(); else photo(); }, onDoubleTap: photo, onLongPress: startV, onLongPressUp: stopV, child: Container(width:85, height:85, decoration: BoxDecoration(shape: BoxShape.circle, color: rec?Colors.red:Colors.white, border: Border.all(color:Colors.white,width:4)), child: Icon(rec?Icons.stop:Icons.camera_alt, color: rec?Colors.white:Colors.black, size:40))),
        _ic(Icons.cameraswitch, () async { camIdx=camIdx==0?1:0; await c!.dispose(); await _init(camIdx); }, size: 28),
      ]))),
    ]));
  }
  Widget _ic(IconData i, VoidCallback f, {double size=20}){ return InkWell(onTap:f, child: Container(padding: EdgeInsets.all(9), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: Icon(i, color: Colors.white, size: size))); }
}
