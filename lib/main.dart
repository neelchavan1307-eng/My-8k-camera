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
  double zoom = 1.0; double exp = 0.0;
  FlashMode flash = FlashMode.off;
  int camIdx = 0;

  @override void initState() { super.initState(); _init(0); }
  Future<void> _init(int i) async {
    c = CameraController(cameras[i], ResolutionPreset.veryHigh, enableAudio: true);
    await c!.initialize(); await c!.setExposureMode(ExposureMode.auto); await c!.setExposureOffset(0);
    if(mounted) setState(() {});
  }

  void photo() async {
    HapticFeedback.vibrate();
    try { await c!.takePicture(); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚡ KATAK! Photo Clicked'), backgroundColor: Colors.amber, duration: Duration(milliseconds: 800))); } catch(e){}
  }
  void startV() async { await c!.startVideoRecording(); setState((){ rec=true; s=0; }); t=Timer.periodic(Duration(seconds:1), (x){ setState(()=>s++); }); }
  void stopV() async { t?.cancel(); await c!.stopVideoRecording(); setState((){ rec=false; s=0; }); }
  String get tm => "${(s~/60).toString().padLeft(2,'0')}:${(s%60).toString().padLeft(2,'0')}";

  @override Widget build(BuildContext context) {
    if(c==null ||!c!.value.isInitialized) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.amber)));
    return Scaffold(backgroundColor: Colors.black, body: Stack(children: [
      SizedBox.expand(child: CameraPreview(c!)),
      SafeArea(child: Column(children: [
        SizedBox(height:10),
        Center(child: Container(padding: EdgeInsets.symmetric(horizontal:16, vertical:6), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)), child: Text("KILLER CAM • ${zoom}x ${rec?'• $tm 🔴':''}", style: TextStyle(fontWeight: FontWeight.bold)))),
        SizedBox(height:12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _ic(flash==FlashMode.off?Icons.flash_off:Icons.flash_on, () async { flash=flash==FlashMode.off?FlashMode.torch:FlashMode.off; await c!.setFlashMode(flash); setState((){}); }),
          Container(padding: EdgeInsets.symmetric(horizontal:8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: DropdownButton<double>(value: zoom, dropdownColor: Colors.black, underline: SizedBox(), style: TextStyle(color: Colors.white), items: [1.0,2.0,3.0,5.0,10.0].map((e)=>DropdownMenuItem(value:e, child: Text("${e}x"))).toList(), onChanged: (v) async { zoom=v!; await c!.setZoomLevel(zoom); setState((){}); })),
          _ic(Icons.brightness_6, () async { exp=0; await c!.setExposureOffset(0); setState((){}); }),
        ])
      ])),
      Positioned(right:0, top:150, bottom:150, child: RotatedBox(quarterTurns: 3, child: Slider(value: exp, min: -2, max: 2, activeColor: Colors.amber, onChanged: (v) async { exp=v; await c!.setExposureOffset(v); setState((){}); }))),
      Align(alignment: Alignment.bottomCenter, child: Padding(padding: EdgeInsets.only(bottom:30, left:20, right:20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _ic(Icons.photo_library, (){}, size: 30),
        GestureDetector(onTap: (){ if(rec) stopV(); else photo(); }, onDoubleTap: photo, onLongPress: startV, onLongPressUp: stopV, child: Container(width:85, height:85, decoration: BoxDecoration(shape: BoxShape.circle, color: rec?Colors.red:Colors.white, border: Border.all(color:Colors.white,width:4)), child: Icon(rec?Icons.stop:Icons.camera_alt, color: rec?Colors.white:Colors.black, size:40))),
        _ic(Icons.cameraswitch, () async { camIdx=camIdx==0?1:0; await c!.dispose(); await _init(camIdx); }, size: 30),
      ]))),
    ]));
  }
  Widget _ic(IconData i, VoidCallback f, {double size=22}){ return InkWell(onTap:f, child: Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: Icon(i, color: Colors.white, size: size))); }
}
