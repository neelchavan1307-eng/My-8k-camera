import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

List<CameraDescription> cameras = [];
const String DEEPAI_KEY = "da580bff-cac8-406f-a60f-c770e7f23718";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: KillerCam()));
}

// 1. CODE 1 - ULTRA 2x OFFLINE
Future<String?> processUltra(Map<String, dynamic> d) async {
  try {
    final bytes = await File(d['path']).readAsBytes();
    img.Image? o = img.decodeImage(bytes);
    if(o==null) return null;
    img.Image up = img.copyResize(o, width: o.width*2, height: o.height*2, interpolation: img.Interpolation.cubic);
    final p = "${d['tmp']}/ULTRA_${DateTime.now().millisecondsSinceEpoch}.jpg";
    await File(p).writeAsBytes(img.encodeJpg(up, quality: 96));
    return p;
  } catch(e){return null;}
}

// 2. CODE 2 - HDREAL 4x CLOUD AI - CHATGPT SARKHA
Future<String?> processHDREAL(Map<String, dynamic> d) async {
  try {
    final file = File(d['path']);
    var request = http.MultipartRequest('POST', Uri.parse('https://api.deepai.org/api/torch-srgan'));
    request.headers['Api-Key'] = DEEPAI_KEY;
    request.files.add(await http.MultipartFile.fromPath('image', file.path));
    var streamed = await request.send();
    var resStr = await streamed.stream.bytesToString();
    var json = jsonDecode(resStr);
    if(json['output_url']!= null){
      var imgRes = await http.get(Uri.parse(json['output_url']));
      final newPath = "${d['tmp']}/HDREAL_${DateTime.now().millisecondsSinceEpoch}.jpg";
      await File(newPath).writeAsBytes(imgRes.bodyBytes);
      return newPath;
    }
    return null;
  } catch(e){ debugPrint("AI Error $e"); return null; }
}

class KillerCam extends StatefulWidget {
  @override State<KillerCam> createState() => _KillerCamState();
}

class _KillerCamState extends State<KillerCam> {
  CameraController? ctrl;
  String currentMode = "PHOTO";
  bool isRec = false, isProcessing = false;
  double zoom = 1.0;
  int currentLens = 0;
  Offset? focusPoint;

  @override void initState(){ super.initState(); initCam(0); }
  initCam(int idx) async {
    await [Permission.camera, Permission.microphone, Permission.photos].request();
    if(idx>=cameras.length) idx=0;
    currentLens=idx;
    if(ctrl!=null) await ctrl!.dispose();
    ctrl = CameraController(cameras[idx], ResolutionPreset.max, enableAudio:true);
    await ctrl!.initialize();
    await ctrl!.setFocusMode(FocusMode.auto);
    setState((){});
  }
  onTapToFocus(TapDownDetails d, Size s) async {
    if(ctrl==null) return;
    setState(()=> focusPoint = d.localPosition);
    await ctrl!.setFocusPoint(Offset(d.localPosition.dx/s.width, d.localPosition.dy/s.height));
    Future.delayed(Duration(seconds:2), ()=> setState(()=> focusPoint=null));
  }
  capture() async {
    if(ctrl==null) return;
    if(currentMode=="PHOTO" || currentMode=="HDREAL"){
      XFile f = await ctrl!.takePicture();
      await Gal.putImage(f.path, album: "KillerCam Regular");
      setState(()=> isProcessing=true);
      final dir = await getTemporaryDirectory();
      String? out;
      if(currentMode=="HDREAL"){
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("🔥 HDREAL AI 10 sec... Internet chalu theva")));
        out = await compute(processHDREAL, {'path': f.path, 'tmp': dir.path});
        if(out!=null){ await Gal.putImage(out, album: "KillerCam HDREAL"); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ HDREAL SAVE! Ekdam Clear!"), backgroundColor: Colors.cyan)); }
        else { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Fail - Internet / Key check"), backgroundColor: Colors.red)); }
      } else {
        out = await compute(processUltra, {'path': f.path, 'tmp': dir.path});
        if(out!=null){ await Gal.putImage(out, album: "KillerCam ULTRA"); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ ULTRA 2x SAVE!"))); }
      }
      setState(()=> isProcessing=false);
    } else {
      if(isRec){ XFile f = await ctrl!.stopVideoRecording(); setState(()=> isRec=false); await Gal.putVideo(f.path, album: "Video"); }
      else { await ctrl!.startVideoRecording(); setState(()=> isRec=true); }
    }
  }
  Widget modeBtn(String t, {bool isHD=false}){
    bool sel = currentMode==t;
    return GestureDetector(onTap: ()=> setState(()=> currentMode=t),
      child: Container(margin:EdgeInsets.symmetric(horizontal:4), padding:EdgeInsets.symmetric(horizontal:16, vertical:7),
      decoration: BoxDecoration(color: sel? (isHD? Colors.cyanAccent : Colors.yellow) : Colors.black54, borderRadius: BorderRadius.circular(20)),
      child: Text(t, style: TextStyle(color: sel? Colors.black:Colors.white70, fontSize:12, fontWeight: FontWeight.bold))));
  }
  Widget lensBtn(int i, String z, String l){ bool s=currentLens==i; return GestureDetector(onTap: () async => await initCam(i), child: Container(margin:EdgeInsets.symmetric(horizontal:4), padding:EdgeInsets.symmetric(horizontal:12, vertical:5), decoration:BoxDecoration(color:s?Colors.yellow:Colors.black54, borderRadius:BorderRadius.circular(12)), child: Column(children:[Text(z, style:TextStyle(color:s?Colors.black:Colors.white, fontWeight:FontWeight.bold, fontSize:11)), Text(l, style:TextStyle(color:s?Colors.black:Colors.white70, fontSize:8))])));}
  @override Widget build(BuildContext context){
    if(ctrl==null ||!ctrl!.value.isInitialized) return Scaffold(backgroundColor:Colors.black, body:Center(child:CircularProgressIndicator(color:Colors.yellow)));
    final size=MediaQuery.of(context).size;
    return Scaffold(backgroundColor:Colors.black, body: Stack(fit:StackFit.expand, children:[
      GestureDetector(onTapDown: (d)=> onTapToFocus(d,size), child: FittedBox(fit:BoxFit.cover, child:SizedBox(width:size.width, height:size.height/ctrl!.value.aspectRatio, child:CameraPreview(ctrl!)))),
      if(focusPoint!=null) Positioned(left:focusPoint!.dx-30, top:focusPoint!.dy-30, child: Container(width:60,height:60,decoration:BoxDecoration(border:Border.all(color:Colors.yellow,width:2),borderRadius:BorderRadius.circular(8)))),
      Positioned(top:0,left:0,right:0, child: SafeArea(child: Column(children:[
        Padding(padding:EdgeInsets.all(12), child: Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[Container(padding:EdgeInsets.symmetric(horizontal:12,vertical:6), decoration:BoxDecoration(color:Colors.black54,borderRadius:BorderRadius.circular(20)), child:Text(currentMode=="HDREAL"?"HDREAL AI ✅":"ULTRA READY", style:TextStyle(color:currentMode=="HDREAL"?Colors.cyanAccent:Colors.yellow,fontWeight:FontWeight.bold,fontSize:11))), if(isProcessing) Row(children:[SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2,color:Colors.cyanAccent)), SizedBox(width:6), Text("Processing...", style:TextStyle(color:Colors.cyanAccent,fontSize:10))])])),
        Row(mainAxisAlignment:MainAxisAlignment.center, children:[modeBtn("SLO-MO"), modeBtn("PHOTO"), modeBtn("VIDEO"), modeBtn("HDREAL", isHD:true)]),
        SizedBox(height:8), Row(mainAxisAlignment:MainAxisAlignment.center, children:[lensBtn(0,"1x","64MP"), lensBtn(1,"0.6x","ULTRA"), lensBtn(2,"2cm","MACRO")]),
      ]))),
      Positioned(right:0, top:size.height*0.25, bottom:size.height*0.25, child: RotatedBox(quarterTurns:3, child: Slider(value:zoom, min:1.0, max:8.0, activeColor:Colors.yellow, onChanged:(v) async {setState(()=>zoom=v); await ctrl!.setZoomLevel(v);}))),
      Positioned(bottom:0,left:0,right:0, child: SafeArea(child: Padding(padding:EdgeInsets.fromLTRB(20,0,20,15), child: Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[
          GestureDetector(onTap: () async {await Gal.open();}, child: Container(width:50,height:50, decoration:BoxDecoration(color:Colors.white24,borderRadius:BorderRadius.circular(12)), child:Icon(Icons.photo_library,color:Colors.white))),
          GestureDetector(onTap: isProcessing?null:capture, child: Container(width:85,height:85, decoration:BoxDecoration(color:isRec?Colors.red: (currentMode=="HDREAL"?Colors.cyanAccent:Colors.white), shape:BoxShape.circle, border:Border.all(color:Colors.yellow,width:4)), child:Icon(Icons.camera_alt, size:36, color:Colors.black))),
          IconButton(icon:Icon(Icons.cameraswitch,color:Colors.white,size:30), onPressed: () async {int idx=(currentLens+1)%cameras.length; await initCam(idx);}),
        ])))),
    ]));
  }
}
