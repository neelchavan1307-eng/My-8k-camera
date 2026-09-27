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

Future<String?> process64MPImage(Map<String, dynamic> data) async {
  try {
    final bytes = await File(data['path']).readAsBytes();
    img.Image? original = img.decodeImage(bytes);
    if (original == null) return null;
    int targetW = original.width;
    int targetH = original.height;
    if(targetW > 4000){
      targetW = 4000;
      targetH = (original.height * 4000 / original.width).toInt();
    }
    img.Image resized = img.copyResize(original, width: targetW, height: targetH, interpolation: img.Interpolation.cubic);
    img.Image sharpened = img.convolution(resized, filter: [0, -1, 0, -1, 5, -1, 0, -1, 0], div: 1);
    final newPath = "${data['tmp']}/ultra64_${DateTime.now().millisecondsSinceEpoch}.jpg";
    await File(newPath).writeAsBytes(img.encodeJpg(sharpened, quality: 96));
    return newPath;
  } catch(e){ return null; }
}

class KillerCam extends StatefulWidget {
  @override
  State<KillerCam> createState() => _KillerCamState();
}

class _KillerCamState extends State<KillerCam> {
  CameraController? ctrl;
  bool isPhoto = true;
  bool isRec = false;
  double zoom = 1.0;
  int filter = 0;
  bool isProcessing = false;
  int currentLens = 0; // 0=Main 64MP, 1=Ultra-wide, 2=Macro

  List<String> names = ["Original", "RRR", "KGF", "Cinematic", "DSLR 64MP"];
  List<Color> fColor = [Colors.transparent, Colors.orange, Colors.amber, Colors.brown, Colors.white];

  @override
  void initState() { super.initState(); initCam(0); }

  initCam(int lensIndex) async {
    await [Permission.camera, Permission.microphone, Permission.photos].request();
    if(lensIndex >= cameras.length) lensIndex = 0;
    currentLens = lensIndex;
    if(ctrl!= null) await ctrl!.dispose();
    // 64MP OIS sathi MAX
    ctrl = CameraController(cameras[lensIndex], ResolutionPreset.max, enableAudio: true);
    await ctrl!.initialize();
    await ctrl!.setFocusMode(FocusMode.auto);
    await ctrl!.setExposureMode(ExposureMode.auto);
    setState(() {});
  }

  setDSLR(bool enable) async {
    if (enable) {
      setState(() { zoom = 2.0; filter = 4; });
      await ctrl!.setZoomLevel(2.0);
    } else {
      setState(() { zoom = 1.0; filter = 0; });
      await ctrl!.setZoomLevel(1.0);
    }
  }

  capture() async {
    if (ctrl == null) return;
    if (isPhoto) {
      XFile f = await ctrl!.takePicture();
      String album = currentLens==0? "KillerCam 64MP OIS" : currentLens==1? "KillerCam Ultra-Wide" : "KillerCam Macro";
      await Gal.putImage(f.path, album: album);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("📸 ${album} Save!")));

      if(currentLens==0){ // Fakt 64MP la AI Clear
        setState(()=> isProcessing = true);
        final dir = await getTemporaryDirectory();
        String? ultraPath = await compute(process64MPImage, {'path': f.path, 'tmp': dir.path});
        if(ultraPath!= null){
          await Gal.putImage(ultraPath, album: "KillerCam Ultra 64MP");
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("🔥 64MP ULTRA CLEAR SAVE!"), backgroundColor: Colors.green));
        }
        setState(()=> isProcessing = false);
      }
    } else {
      if (isRec) {
        XFile f = await ctrl!.stopVideoRecording();
        setState(() => isRec = false);
        await Gal.putVideo(f.path, album: "KillerCam");
      } else {
        await ctrl!.startVideoRecording();
        setState(() => isRec = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ctrl == null ||!ctrl!.value.isInitialized) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.yellow)));
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(fit: BoxFit.cover, child: SizedBox(width: size.width, height: size.height / ctrl!.value.aspectRatio, child: CameraPreview(ctrl!))),
          if (filter!=0) Container(color: fColor[filter].withOpacity(filter==4?0.12:0.22)),
          Positioned(top:0, left:0, right:0, child: SafeArea(child: Column(children: [
            Padding(padding: EdgeInsets.symmetric(horizontal:15, vertical:10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(padding: EdgeInsets.symmetric(horizontal:12, vertical:6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text(currentLens==0? "64MP OIS • ${zoom.toStringAsFixed(1)}x" : currentLens==1? "8MP ULTRA-WIDE • 0.6x" : "2MP MACRO • 2cm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize:11))),
              if(isProcessing) Row(children:[SizedBox(width:15, height:15, child:CircularProgressIndicator(strokeWidth:2, color:Colors.yellow)), SizedBox(width:5), Text("64MP AI...", style:TextStyle(color:Colors.yellow, fontSize:10))]) else Icon(Icons.camera_enhance, color: filter==4? Colors.yellow : Colors.white),
            ])),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [modeBtn("SLO-MO"), modeBtn("PHOTO"), modeBtn("VIDEO"), dslrBtn()]),
            SizedBox(height:10),
            // 3 LENS SWITCHER - NAVIN
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              lensBtn(0, "1x", "64MP"),
              lensBtn(1, "0.6x", "ULTRA"),
              lensBtn(2, "2cm", "MACRO"),
            ]),
          ]))),
          Positioned(right:0, top:size.height*0.25, bottom:size.height*0.25, child: RotatedBox(quarterTurns:3, child: Slider(value:zoom, min:1.0, max:8.0, activeColor:Colors.yellow, onChanged:(v) async {setState(()=>zoom=v); await ctrl!.setZoomLevel(v);}))),
          Positioned(bottom:0, left:0, right:0, child: SafeArea(child: Column(children: [
            SingleChildScrollView(scrollDirection:Axis.horizontal, child: Row(children: List.generate(names.length, (i)=> GestureDetector(onTap: () async {if(i==4) await setDSLR(true); else {setState(()=>filter=i); if(zoom==2.0){setState(()=>zoom=1.0); await ctrl!.setZoomLevel(1.0);}}}, child: Container(margin:EdgeInsets.only(left:i==0?15:8, bottom:12), padding:EdgeInsets.symmetric(horizontal:14, vertical:7), decoration:BoxDecoration(color:filter==i?Colors.yellow:Colors.black54, borderRadius:BorderRadius.circular(20)), child:Text(names[i], style:TextStyle(color:filter==i?Colors.black:Colors.white, fontWeight:FontWeight.bold, fontSize:12))))))),
            Padding(padding:EdgeInsets.fromLTRB(20,0,20,12), child: Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children: [
              GestureDetector(onTap: () async {await Gal.open();}, child: Container(width:50, height:50, decoration:BoxDecoration(color:Colors.white24, borderRadius:BorderRadius.circular(12)), child:Icon(Icons.photo_library, color:Colors.white))),
              GestureDetector(onTap: isProcessing? null : capture, child: Container(width:78, height:78, decoration:BoxDecoration(color:isRec?Colors.red:Colors.white, shape:BoxShape.circle, border:Border.all(color:filter==4?Colors.yellow:Colors.white, width:4)), child:Icon(isPhoto?Icons.camera_alt:(isRec?Icons.stop:Icons.videocam), size:33, color:isRec?Colors.white:Colors.black))),
              IconButton(icon:Icon(Icons.cameraswitch, color:Colors.white, size:30), onPressed: () async {int idx=(currentLens+1)%cameras.length; await initCam(idx);}),
            ])),
          ]))),
        ],
      ),
    );
  }

  Widget lensBtn(int idx, String zoomTxt, String label){
    bool sel = currentLens==idx;
    return GestureDetector(
      onTap: () async { await initCam(idx); },
      child: Container(margin: EdgeInsets.symmetric(horizontal:5), padding: EdgeInsets.symmetric(horizontal:12, vertical:5), decoration: BoxDecoration(color: sel? Colors.yellow : Colors.black54, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel? Colors.yellow : Colors.white24)), child: Column(children: [Text(zoomTxt, style: TextStyle(color: sel? Colors.black: Colors.white, fontWeight: FontWeight.bold, fontSize:11)), Text(label, style: TextStyle(color: sel? Colors.black: Colors.white70, fontSize:8))])),
    );
  }

  Widget modeBtn(String t){
    bool sel=(t=="PHOTO"&&isPhoto)||(t=="VIDEO"&&!isPhoto);
    return GestureDetector(onTap:()=>setState(()=>isPhoto=(t=="PHOTO")), child:Container(margin:EdgeInsets.symmetric(horizontal:5), padding:EdgeInsets.symmetric(horizontal:12, vertical:5), decoration:BoxDecoration(color:sel?Colors.white:Colors.black45, borderRadius:BorderRadius.circular(12)), child:Text(t, style:TextStyle(color:sel?Colors.black:Colors.white70, fontSize:10, fontWeight:FontWeight.bold))));
  }
  Widget dslrBtn(){
    bool sel=filter==4;
    return GestureDetector(onTap:()=>setDSLR(!sel), child:Container(margin:EdgeInsets.symmetric(horizontal:5), padding:EdgeInsets.symmetric(horizontal:12, vertical:5), decoration:BoxDecoration(color:sel?Colors.yellow:Colors.black45, borderRadius:BorderRadius.circular(12), border:Border.all(color:sel?Colors.yellow:Colors.transparent)), child:Text("DSLR 64MP", style:TextStyle(color:sel?Colors.black:Colors.white70, fontSize:10, fontWeight:FontWeight.bold))));
  }
}
