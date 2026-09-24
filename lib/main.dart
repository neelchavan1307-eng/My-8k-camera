import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MaterialApp(home: FinalCamera(), debugShowCheckedModeBanner: false));
}

class FinalCamera extends StatefulWidget {
  @override
  _FinalCameraState createState() => _FinalCameraState();
}

class _FinalCameraState extends State<FinalCamera> {
  late CameraController controller;
  bool isReady = false;
  bool isPhoto = true;
  bool isRecording = false;
  bool isProMode = false;
  bool isMacro = false;
  int camIndex = 0;
  FlashMode flash = FlashMode.off;
  String quality = "4K";
  String filter = "Original";
  double zoom = 1.0;
  double ev = 0.0;

  Map<String, List<double>> filters = {
    "Original": [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0],
    "Vivid": [1.3,0,0,0,0, 0,1.3,0,0,0, 0,0,1.3,0,0, 0,0,0,1,0],
    "B&W": [0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0,0,0,1,0],
    "Warm": [1.2,0,0,0,15, 0,1,0,0,0, 0,0,0.8,0,0, 0,0,0,1,0],
    "Cinematic": [1.1,0,0,0,10, 0,1.05,0,0,5, 0,0,0.9,0,0, 0,0,0,1,0],
  };

  @override
  void initState(){ super.initState(); startCam(0); }

  Future<void> startCam(int index) async {
    await [Permission.camera, Permission.microphone, Permission.storage, Permission.photos].request();
    var preset = quality=="720"?ResolutionPreset.medium: quality=="1080"?ResolutionPreset.high: ResolutionPreset.ultraHigh;
    controller = CameraController(cameras[index], preset, enableAudio: true);
    await controller.initialize();
    await controller.setFlashMode(flash);
    setState((){ isReady=true; camIndex=index; });
  }

  @override
  Widget build(BuildContext context) {
    if(!isReady) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: Stack(children: [
        // FULL SCREEN FIX - 100% screen bharun disel
        Positioned.fill(child: ColorFiltered(colorFilter: ColorFilter.matrix(filters[filter]!), child: CameraPreview(controller))),

        SafeArea(child: Padding(padding: EdgeInsets.all(12), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              _btn(flash==FlashMode.off?Icons.flash_off:Icons.flash_on, () async { setState(()=> flash=flash==FlashMode.off?FlashMode.torch:FlashMode.off); await controller.setFlashMode(flash); }),
              SizedBox(width:8), _btn(Icons.cameraswitch, () async { setState(()=>isReady=false); await startCam(camIndex==0?1:0); }),
              SizedBox(width:8), _btn(Icons.macro_off, () async { if(cameras.length>2){ setState(()=>isReady=false); await startCam(isMacro?0:2); setState(()=>isMacro=!isMacro);} else { isMacro=!isMacro; controller.setZoomLevel(isMacro?2.5:1.0); setState((){});} }, active: isMacro),
            ]),
            Container(padding: EdgeInsets.symmetric(horizontal:8,vertical:2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: quality, dropdownColor: Colors.black, style: TextStyle(color: Colors.white, fontSize:12), items: ["720","1080","4K"].map((e)=>DropdownMenuItem(value:e, child:Text(e))).toList(), onChanged: (v) async { quality=v!; setState(()=>isReady=false); await startCam(camIndex); }))),
          ]),
          SizedBox(height:10),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: filters.keys.map((f)=> GestureDetector(onTap: ()=>setState(()=>filter=f), child: Container(margin: EdgeInsets.only(right:6), padding: EdgeInsets.symmetric(horizontal:12,vertical:6), decoration: BoxDecoration(color: filter==f?Colors.white:Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text(f, style: TextStyle(color: filter==f?Colors.black:Colors.white, fontSize:11, fontWeight: FontWeight.bold))))).toList())),
          if(isProMode) SizedBox(height:12),
          if(isProMode) Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: Column(children: [
            Row(children: [Text("ZOOM ${zoom.toStringAsFixed(1)}x", style: TextStyle(color:Colors.white, fontSize:10)), Expanded(child: Slider(value: zoom, min:1, max:8, onChanged: (v){ setState(()=>zoom=v); controller.setZoomLevel(v); }))]),
            Row(children: [Text("EV ${ev.toStringAsFixed(1)}", style: TextStyle(color:Colors.white, fontSize:10)), Expanded(child: Slider(value: ev, min:-2, max:2, onChanged: (v){ setState(()=>ev=v); controller.setExposureOffset(v); }))]),
          ])),
        ]))),

        Positioned(bottom:0,left:0,right:0, child: Container(padding: EdgeInsets.fromLTRB(20,15,20,35), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _mode("PRO", isProMode, ()=>setState(()=>isProMode=!isProMode)),
            SizedBox(width:18), _mode("PHOTO", isPhoto&&!isProMode, ()=>setState((){isPhoto=true; isProMode=false;})),
            SizedBox(width:18), _mode("VIDEO",!isPhoto&&!isProMode, ()=>setState((){isPhoto=false; isProMode=false;})),
            SizedBox(width:18), _mode("MACRO", isMacro, () async { if(cameras.length>2){ setState(()=>isReady=false); await startCam(isMacro?0:2); setState(()=>isMacro=!isMacro);} else { isMacro=!isMacro; controller.setZoomLevel(isMacro?2.5:1.0); setState((){});} }),
          ]),
          SizedBox(height:20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            Icon(Icons.photo_library, color: Colors.white, size:28),
            GestureDetector(onTap: () async { if(isPhoto||isProMode){ var x=await controller.takePicture(); await ImageGallerySaver.saveFile(x.path); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved!"))); } else { if(isRecording){ var x=await controller.stopVideoRecording(); await ImageGallerySaver.saveFile(x.path); setState(()=>isRecording=false);} else { await controller.startVideoRecording(); setState(()=>isRecording=true);} } }, child: Container(width:78,height:78, decoration: BoxDecoration(color: isRecording?Colors.red:Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width:4)), child: Icon(isPhoto||isProMode?Icons.camera_alt:isRecording?Icons.stop:Icons.videocam, color: isRecording?Colors.white:Colors.black, size:30))),
            GestureDetector(onTap: ()=>setState(()=>isProMode=!isProMode), child: Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: isProMode?Colors.yellow:Colors.black54, shape: BoxShape.circle), child: Icon(Icons.tune, color: isProMode?Colors.black:Colors.white))),
          ]),
        ]))),
      ]),
    );
  }
  Widget _btn(IconData i, VoidCallback t, {bool active=false}) => GestureDetector(onTap: t, child: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: active?Colors.yellow:Colors.black54, shape: BoxShape.circle), child: Icon(i, color: active?Colors.black:Colors.white, size:20)));
  Widget _mode(String t, bool a, VoidCallback tap) => GestureDetector(onTap: tap, child: Text(t, style: TextStyle(color: a?Colors.yellow:Colors.white70, fontWeight: a?FontWeight.bold:FontWeight.normal, fontSize:12)));
}2
