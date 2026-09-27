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

// ===== NORMAL ULTRA - 2x =====
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

// ===== HDREAL - 4x AI LIKE - CHATGPT SARKHA =====
Future<String?> processHDREAL(Map<String, dynamic> d) async {
  try {
    final bytes = await File(d['path']).readAsBytes();
    img.Image? original = img.decodeImage(bytes);
    if(original==null) return null;

    // 1. 4x Motha - HDREAL cha main logic
    img.Image step1 = img.copyResize(original, width: original.width*4, height: original.height*4, interpolation: img.Interpolation.cubic);

    // 2. AI sarkha brightness + contrast
    img.Image step2 = img.adjustColor(step1, brightness: 15, contrast: 35, saturation: 15);

    // 3. AI Sharp - Text ekdam clear
    img.Image step3 = img.convolution(step2, filter: [0,-1,0, -1,5,-1, 0,-1,0], div: 1);

    // 4. Thoda noise clean
    img.Image step4 = img.gaussianBlur(step3, radius: 1);
    img.Image finalImg = img.adjustColor(step4, contrast: 10);

    final newPath = "${d['tmp']}/HDREAL_${DateTime.now().millisecondsSinceEpoch}.jpg";
    await File(newPath).writeAsBytes(img.encodeJpg(finalImg, quality: 98));
    return newPath;
  } catch(e){ return null; }
}

class KillerCam extends StatefulWidget {
  @override State<KillerCam> createState() => _KillerCamState();
}

class _KillerCamState extends State<KillerCam> {
  CameraController? ctrl;
  String currentMode = "PHOTO";
  bool isRec = false, isProcessing = false;
  double zoom = 1.0;
  int filter = 0, currentLens = 0;
  Offset? focusPoint;
  List<String> names = ["Original","RRR","KGF","Cinematic","DSLR"];
  List<Color> fColor = [Colors.transparent, Colors.orange, Colors.amber, Colors.brown, Colors.white];

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
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(currentMode=="HDREAL"?"🔥 HDREAL Processing 4x...":"📸 Ultra banvatoy...")));
      setState(()=> isProcessing=true);
      final dir = await getTemporaryDirectory();
      String? out;
      if(currentMode=="HDREAL"){
        out = await compute(processHDREAL, {'path': f.path, 'tmp': dir.path});
        if(out!=null){ await Gal.putImage(out, album: "KillerCam HDREAL"); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ HDREAL 4x SAVE! ChatGPT sarkha clear!"), backgroundColor: Colors.green)); }
      } else {
        out = await compute(processUltra, {'path': f.path, 'tmp': dir.path});
        if(out!=null){ await Gal.putImage(out, album: "KillerCam ULTRA"); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ ULTRA 2x SAVE!"))); }
      }
      setState(()=> isProcessing=false);
    } else {
      if(isRec){ XFile f = await ctrl!.stopVideoRecording(); setState(()=> isRec=false); await Gal.putVideo(f.path, album: currentMode=="SLO-MO"?"KillerCam SLO-MO":"KillerCam Video"); }
      else { await ctrl!.startVideoRecording(); setState(()=> isRec=true); }
    }
  }

  Widget modeBtn(String t, {bool isHD=false}){
    bool sel = currentMode==t;
    return GestureDetector(onTap: ()=> setState(()=> currentMode=t),
      child: Container(margin:EdgeInsets.symmetric(horizontal:4), padding:EdgeInsets.symmetric(horizontal: isHD? 16:12, vertical:6),
      decoration: BoxDecoration(color: sel? (isHD? Colors.cyanAccent : Colors.yellow) : Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel? (isHD? Colors.cyanAccent : Colors.yellow) : Colors.white24)),
      child: Text(t, style: TextStyle(color: sel? Colors.black:Colors.white70, fontSize: isHD?13:11, fontWeight: FontWeight.bold))));
  }

  Widget lensBtn(int i, String z, String l){ bool s=currentLens==i; return GestureDetector(onTap: () async => await initCam(i), child: Container(margin:EdgeInsets.symmetric(horizontal:4), padding:EdgeInsets.symmetric(horizontal:12, vertical:5), decoration:BoxDecoration(color:s?Colors.yellow:Colors.black54, borderRadius:BorderRadius.circular(12)), child: Column(children:[Text(z, style:TextStyle(color:s?Colors.black:Colors.white, fontWeight:FontWeight.bold, fontSize:11)), Text(l, style:TextStyle(color:s?Colors.black:Colors.white70, fontSize:8))])));}

  @override Widget build(BuildContext context){
    if(ctrl==null ||!ctrl!.value.isInitialized) return Scaffold(backgroundColor:Colors.black, body:Center(child:CircularProgressIndicator(color:Colors.yellow)));
    final size=MediaQuery.of(context).size;
    return Scaffold(backgroundColor:Colors.black, body: Stack(fit:StackFit.expand, children:[
      GestureDetector(onTapDown: (d)=> onTapToFocus(d,size), child: FittedBox(fit:BoxFit.cover, child:SizedBox(width:size.width, height:size.height/ctrl!.value.aspectRatio, child:CameraPreview(ctrl!)))),
      if(filter!=0) IgnorePointer(child: Container(color: fColor[filter].withOpacity(0.22))),
      if(focusPoint!=null) Positioned(left:focusPoint!.dx-30, top:focusPoint!.dy-30, child: Container(width:60,height:60,decoration:BoxDecoration(border:Border.all(color:Colors.yellow,width:2),borderRadius:BorderRadius.circular(8)))),
      Positioned(top:0,left:0,right:0, child: SafeArea(child: Column(children:[
        Padding(padding:EdgeInsets.all(12), child: Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[Container(padding:EdgeInsets.symmetric(horizontal:12,vertical:6), decoration:BoxDecoration(color:Colors.black54,borderRadius:BorderRadius.circular(20)), child:Text(currentLens==0?"64MP OIS • TAP":"ULTRA / MACRO", style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:11))), if(isProcessing) Row(children:[SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2,color:Colors.cyanAccent)), SizedBox(width:6), Text(currentMode=="HDREAL"?"HDREAL 4x...":"ULTRA...", style:TextStyle(color:Colors.cyanAccent,fontSize:10))])])),
        Row(mainAxisAlignment:MainAxisAlignment.center, children:[modeBtn("SLO-MO"), modeBtn("PHOTO"), modeBtn("VIDEO"), modeBtn("HDREAL", isHD:true)]),
        SizedBox(height:8), Row(mainAxisAlignment:MainAxisAlignment.center, children:[lensBtn(0,"1x","64MP"), lensBtn(1,"0.6x","ULTRA"), lensBtn(2,"2cm","MACRO")]),
      ]))),
      Positioned(right:0, top:size.height*0.25, bottom:size.height*0.25, child: RotatedBox(quarterTurns:3, child: Slider(value:zoom, min:1.0, max:8.0, activeColor:Colors.yellow, onChanged:(v) async {setState(()=>zoom=v); await ctrl!.setZoomLevel(v);}))),
      Positioned(bottom:0,left:0,right:0, child: SafeArea(child: Column(children:[
        SingleChildScrollView(scrollDirection:Axis.horizontal, child: Row(children: List.generate(names.length, (i)=> GestureDetector(onTap: ()=> setState(()=> filter=i), child: Container(margin:EdgeInsets.only(left:i==0?15:8,bottom:10), padding:EdgeInsets.symmetric(horizontal:14,vertical:7), decoration:BoxDecoration(color:filter==i?Colors.yellow:Colors.black54,borderRadius:BorderRadius.circular(20)), child:Text(names[i], style:TextStyle(color:filter==i?Colors.black:Colors.white,fontWeight:FontWeight.bold,fontSize:12))))))),
        Padding(padding:EdgeInsets.fromLTRB(20,0,20,15), child: Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[
          GestureDetector(onTap: () async {await Gal.open();}, child: Container(width:50,height:50, decoration:BoxDecoration(color:Colors.white24,borderRadius:BorderRadius.circular(12)), child:Icon(Icons.photo_library,color:Colors.white))),
          GestureDetector(onTap: isProcessing?null:capture, child: Container(width:80,height:80, decoration:BoxDecoration(color:isRec?Colors.red: (currentMode=="HDREAL"?Colors.cyanAccent:Colors.white), shape:BoxShape.circle, border:Border.all(color:Colors.yellow,width:4)), child:Icon(currentMode=="PHOTO"||currentMode=="HDREAL"?Icons.camera_alt:(isRec?Icons.stop:Icons.videocam), size:34, color:isRec?Colors.white:Colors.black))),
          IconButton(icon:Icon(Icons.cameraswitch,color:Colors.white,size:30), onPressed: () async {int idx=(currentLens+1)%cameras.length; await initCam(idx);}),
        ])),
      ]))),
    ]));
  }
}
