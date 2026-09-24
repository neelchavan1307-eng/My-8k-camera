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
  State<FinalCamera> createState() => _FinalCameraState();
}

class _FinalCameraState extends State<FinalCamera> {
  late CameraController controller;
  bool isReady = false;
  bool isPhoto = true;
  bool isRecording = false;
  bool isPro = false;
  bool isMacro = false;
  int camIndex = 0;
  FlashMode flash = FlashMode.off;
  String quality = "4K";
  String filter = "Original";
  double zoom = 1.0;
  double ev = 0.0;

  final Map<String, List<double>> filters = {
    "Original": [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0],
    "Vivid": [1.3,0,0,0,0, 0,1.3,0,0,0, 0,0,1.3,0,0, 0,0,0,1,0],
    "B&W": [0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0,0,0,1,0],
  };

  @override
  void initState() { super.initState(); startCam(0); }

  Future<void> startCam(int index) async {
    await [Permission.camera, Permission.microphone, Permission.storage].request();
    var preset = quality == "720"? ResolutionPreset.medium : quality == "1080"? ResolutionPreset.high : ResolutionPreset.ultraHigh;
    controller = CameraController(cameras[index], preset, enableAudio: true);
    await controller.initialize();
    await controller.setFlashMode(flash);
    if(mounted) setState(() { isReady = true; camIndex = index; });
  }

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!isReady) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: ColorFiltered(colorFilter: ColorFilter.matrix(filters[filter]!), child: CameraPreview(controller))),
        SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              _btn(flash == FlashMode.off? Icons.flash_off : Icons.flash_on, () async { flash = flash == FlashMode.off? FlashMode.torch : FlashMode.off; await controller.setFlashMode(flash); setState((){}); }),
              const SizedBox(width: 8),
              _btn(Icons.cameraswitch, () async { setState(()=>isReady=false); await startCam(camIndex==0?1:0); }),
              const SizedBox(width: 8),
              _btn(Icons.macro_off, () { setState(()=>isMacro=!isMacro); controller.setZoomLevel(isMacro?2.5:1.0); }, active: isMacro),
            ]),
            Container(padding: const EdgeInsets.symmetric(horizontal:8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: quality, dropdownColor: Colors.black, style: const TextStyle(color: Colors.white, fontSize:12), items: const [DropdownMenuItem(value:"720", child:Text("720")), DropdownMenuItem(value:"1080", child:Text("1080")), DropdownMenuItem(value:"4K", child:Text("4K"))], onChanged: (v) async { quality=v!; setState(()=>isReady=false); await startCam(camIndex); }))),
          ])),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: filters.keys.map((f) => GestureDetector(onTap: ()=>setState(()=>filter=f), child: Container(margin: const EdgeInsets.only(left:8), padding: const EdgeInsets.symmetric(horizontal:12,vertical:6), decoration: BoxDecoration(color: filter==f?Colors.white:Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text(f, style: TextStyle(color: filter==f?Colors.black:Colors.white, fontSize:11, fontWeight: FontWeight.bold))))).toList())),
          if(isPro) Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: Column(children: [
            Row(children: [const Text("ZOOM", style: TextStyle(color:Colors.white,fontSize:10)), Expanded(child: Slider(value: zoom, min:1, max:6, onChanged: (v){ setState(()=>zoom=v); controller.setZoomLevel(v); }))]),
            Row(children: [const Text("EV", style: TextStyle(color:Colors.white,fontSize:10)), Expanded(child: Slider(value: ev, min:-2, max:2, onChanged: (v){ setState(()=>ev=v); controller.setExposureOffset(v); }))]),
          ])),
        ])),
        Positioned(bottom:0,left:0,right:0, child: Container(padding: const EdgeInsets.fromLTRB(20,15,20,35), decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black])), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _mode("PRO", isPro, ()=>setState(()=>isPro=!isPro)),
            const SizedBox(width:20), _mode("PHOTO", isPhoto&&!isPro, ()=>setState((){isPhoto=true; isPro=false;})),
            const SizedBox(width:20), _mode("VIDEO",!isPhoto&&!isPro, ()=>setState((){isPhoto=false; isPro=false;})),
          ]),
          const SizedBox(height:20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            const Icon(Icons.photo_library, color: Colors.white),
            GestureDetector(onTap: () async { if(isPhoto||isPro){ var x=await controller.takePicture(); await ImageGallerySaver.saveFile(x.path); } else { if(isRecording){ var x=await controller.stopVideoRecording(); await ImageGallerySaver.saveFile(x.path); setState(()=>isRecording=false);} else { await controller.startVideoRecording(); setState(()=>isRecording=true);} } }, child: Container(width:75,height:75, decoration: BoxDecoration(color: isRecording?Colors.red:Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width:3)), child: Icon(isRecording?Icons.stop:isPhoto||isPro?Icons.camera_alt:Icons.videocam, size:30))),
            _btn(Icons.tune, ()=>setState(()=>isPro=!isPro), active: isPro),
          ]),
        ]))),
      ]),
    );
  }
  Widget _btn(IconData i, VoidCallback t, {bool active=false}) => GestureDetector(onTap: t, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: active?Colors.yellow:Colors.black54, shape: BoxShape.circle), child: Icon(i, color: active?Colors.black:Colors.white, size:20)));
  Widget _mode(String t, bool a, VoidCallback tap) => GestureDetector(onTap: tap, child: Text(t, style: TextStyle(color: a?Colors.yellow:Colors.white70, fontWeight: a?FontWeight.bold:FontWeight.normal, fontSize:12)));
}
