import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

List<CameraDescription> cameras = [];
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: KillerCam()));
}

// === ULTRA CLEAR - 2X + BRIGHT + SHARP ===
Future<String?> process64MPImage(Map<String, dynamic> data) async {
  try {
    final bytes = await File(data['path']).readAsBytes();
    img.Image? original = img.decodeImage(bytes);
    if (original == null) return null;
    img.Image upscaled = img.copyResize(original, width: original.width * 2, height: original.height * 2, interpolation: img.Interpolation.cubic);
    img.Image bright = img.adjustColor(upscaled, brightness: 20, contrast: 30, saturation: 10);
    img.Image sharp = img.convolution(bright, filter: [-1, -2, -1, -2, 12, -2, -1, -2, -1], div: 2);
    final newPath = "${data['tmp']}/ULTRA_${DateTime.now().millisecondsSinceEpoch}.jpg";
    await File(newPath).writeAsBytes(img.encodeJpg(sharp, quality: 98));
    return newPath;
  } catch(e){ return null; }
}

class KillerCam extends StatefulWidget {
  @override
  State<KillerCam> createState() => _KillerCamState();
}

class _KillerCamState extends State<KillerCam> {
  CameraController? ctrl;
  String currentMode = "PHOTO"; // SLO-MO, PHOTO, VIDEO
  bool isRec = false;
  double zoom = 1.0;
  int filter = 0;
  bool isProcessing = false;
  int currentLens = 0;
  Offset? focusPoint;

  List<String> names = ["Original", "RRR", "KGF", "Cinematic", "DSLR 64MP"];
  List<Color> fColor = [Colors.transparent, Colors.orange, Colors.amber, Colors.brown, Colors.white];

  @override
  void initState() { super.initState(); initCam(0); }

  initCam(int lensIndex) async {
    await [Permission.camera, Permission.microphone, Permission.photos].request();
    if(lensIndex >= cameras.length) lensIndex = 0;
    currentLens = lensIndex;
    if(ctrl!= null) await ctrl!.dispose();
    ctrl = CameraController(cameras[lensIndex], ResolutionPreset.max, enableAudio: true);
    await ctrl!.initialize();
    await ctrl!.setFocusMode(FocusMode.auto);
    await ctrl!.setExposureMode(ExposureMode.auto);
    setState(() {});
  }

  Future<void> onTapToFocus(TapDownDetails details, Size size) async {
    if(ctrl==null) return;
    final x = details.localPosition.dx / size.width;
    final y = details.localPosition.dy / size.height;
    setState(()=> focusPoint = details.localPosition);
    await ctrl!.setFocusPoint(Offset(x,y));
    await ctrl!.setExposurePoint(Offset(x,y));
    Future.delayed(Duration(seconds:2), ()=> setState(()=> focusPoint=null));
  }

  capture() async {
    if (ctrl == null) return;
    if (currentMode == "PHOTO") {
      XFile f = await ctrl!.takePicture();
      await Gal.putImage(f.path, album: "KillerCam Regular");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("📸 Regular Save... Ultra banvatoy")));
      setState(()=> isProcessing = true);
      final dir = await getTemporaryDirectory();
      String? ultraPath = await compute(process64MPImage, {'path': f.path, 'tmp': dir.path});
      if(ultraPath!= null){
        await Gal.putImage(ultraPath, album: "KillerCam ULTRA CLEAR");
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("🔥 ULTRA CLEAR SAVE! 2x + Bright + Sharp!"), backgroundColor: Colors.green));
      }
      setState(()=> isProcessing = false);
    } else {
      if (isRec) {
        XFile f = await ctrl!.stopVideoRecording();
        setState(() => isRec = false);
        String album = currentMode == "SLO-MO"? "KillerCam SLO-MO" : "KillerCam Video";
        await Gal.putVideo(f.path, album: album);
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ ${album} Save!")));
      } else {
        await ctrl!.startVideoRecording();
        setState(() => isRec = true);
      }
    }
  }

  Widget modeBtn(String t){
    bool sel = currentMode == t;
    return GestureDetector(
      onTap: (){
        setState(()=> currentMode = t);
        if(t=="SLO-MO" && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("🐢 SLO-MO ON - Video kadh")));
      },
      child: Container(margin:EdgeInsets.symmetric(horizontal:5), padding:EdgeInsets.symmetric(horizontal:14, vertical:6), decoration:BoxDecoration(color:sel?Colors.yellow:Colors.black54, borderRadius:BorderRadius.circular(20), border: Border.all(color: sel? Colors.yellow : Colors.white24)), child:Text(t, style:TextStyle(color:sel?Colors.black:Colors.white70, fontSize:11, fontWeight:FontWeight.bold))),
    );
  }

  Widget lensBtn(int idx, String zoomTxt, String label){
    bool sel = currentLens==idx;
    return GestureDetector(onTap: () async { await initCam(idx); }, child: Container(margin: EdgeInsets.symmetric(horizontal:5), padding: EdgeInsets.symmetric(horizontal:12, vertical:5), decoration: BoxDecoration(color: sel? Colors.yellow : Colors.black54, borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(zoomTxt, style: TextStyle(color: sel? Colors.black: Colors.white, fontWeight: FontWeight.bold, fontSize:11)), Text(label, style: TextStyle(color: sel? Colors.black: Colors.white70, fontSize:8))])));
  }

  @override
  Widget build(BuildContext context) {
    if (ctrl == null ||!ctrl!.value.isInitialized) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.yellow)));
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        GestureDetector(onTapDown: (d) => onTapToFocus(d, size), child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: size.width, height: size.height / ctrl!.value.aspectRatio, child: CameraPreview(ctrl!)))),
        if (filter!=0) IgnorePointer(child: Container(color: fColor[filter].withOpacity(filter==4?0.12:0.22))),
        if(focusPoint!=null) Positioned(left: focusPoint!.dx-30, top: focusPoint!.dy-30, child: Container(width:60, height:60, decoration: BoxDecoration(border: Border.all(color: Colors.yellow, width:2), borderRadius: BorderRadius.circular(8)))),
        Positioned(top:0, left:0, right:0, child: SafeArea(child: Column(children: [
          Padding(padding: EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(padding: EdgeInsets.symmetric(horizontal:12, vertical:6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text(currentLens==0? "64MP OIS • TAP FOCUS" : currentLens==1? "8MP ULTRA" : "2MP MACRO • 2cm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize:11))),
            if(isProcessing) Row(children:[SizedBox(width:14, height:14, child:CircularProgressIndicator(strokeWidth:2, color:Colors.yellow)), SizedBox(width:6), Text("ULTRA...", style:TextStyle(color:Colors.yellow, fontSize:10))])
          ])),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [modeBtn("SLO-MO"), modeBtn("PHOTO"), modeBtn("VIDEO")]),
          SizedBox(height:8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [lensBtn(0, "1x", "64MP"), lensBtn(1, "0.6x", "ULTRA"), lensBtn(2, "2cm", "MACRO")]),
        ]))),
        Positioned(right:0, top:size.height*0.25, bottom:size.height*0.25, child: RotatedBox(quarterTurns:3, child: Slider(value:zoom, min:1.0, max:8.0, activeColor:Colors.yellow, onChanged:(v) async {setState(()=>zoom=v); await ctrl!.setZoomLevel(v);}))),
        Positioned(bottom:0, left:0, right:0, child: SafeArea(child: Column(children: [
          SingleChildScrollView(scrollDirection:Axis.horizontal, child: Row(children: List.generate(names.length, (i)=> GestureDetector(onTap: () async {setState(()=>filter=i);}, child: Container(margin:EdgeInsets.only(left:i==0?15:8, bottom:10), padding:EdgeInsets.symmetric(horizontal:14, vertical:7), decoration:BoxDecoration(color:filter==i?Colors.yellow:Colors.black54, borderRadius:BorderRadius.circular(20)), child:Text(names[i], style:TextStyle(color:filter==i?Colors.black:Colors.white, fontWeight:FontWeight.bold, fontSize:12))))))),
          Padding(padding:EdgeInsets.fromLTRB(20,0,20,15), child: Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children: [
            GestureDetector(onTap: () async {await Gal.open();}, child: Container(width:50, height:50, decoration:BoxDecoration(color:Colors.white24, borderRadius:BorderRadius.circular(12)), child:Icon(Icons.photo_library, color:Colors.white))),
            GestureDetector(onTap: isProcessing? null : capture, child: Container(width:80, height:80, decoration:BoxDecoration(color:isRec?Colors.red:Colors.white, shape:BoxShape.circle, border:Border.all(color:Colors.yellow, width:4)), child:Icon(currentMode=="PHOTO"?Icons.camera_alt:(isRec?Icons.stop:Icons.videocam), size:34, color:isRec?Colors.white:Colors.black))),
            IconButton(icon:Icon(Icons.cameraswitch, color:Colors.white, size:30), onPressed: () async {int idx=(currentLens+1)%cameras.length; await initCam(idx);}),
          ])),
        ]))),
      ]),
    );
  }
}
