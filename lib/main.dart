import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> cameras = [];
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: KillerCam()));
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
  List<String> names = ["Original", "RRR", "KGF", "Cinematic", "DSLR"];
  List<Color> fColor = [Colors.transparent, Colors.orange, Colors.amber, Colors.brown, Colors.white];

  @override
  void initState() { super.initState(); initCam(); }

  initCam() async {
    await [Permission.camera, Permission.microphone, Permission.photos, Permission.videos, Permission.storage].request();
    ctrl = CameraController(cameras[0], ResolutionPreset.max, enableAudio: true);
    await ctrl!.initialize();
    setState(() {});
  }

  capture() async {
    if (ctrl == null) return;
    if (isPhoto) {
      XFile f = await ctrl!.takePicture();
      await Gal.putImage(f.path, album: "KillerCam");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ PHOTO SAVE!")));
    } else {
      if (isRec) {
        XFile f = await ctrl!.stopVideoRecording();
        setState(() => isRec = false);
        await Gal.putVideo(f.path, album: "KillerCam");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("🎥 VIDEO SAVE!")));
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
          // 1. FULL SCREEN CAMERA - YA MULE KALI PATTI JANAR
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(width: size.width, height: size.height / ctrl!.value.aspectRatio, child: CameraPreview(ctrl!)),
          ),

          if (filter!= 0) Container(color: fColor[filter].withOpacity(0.25)),

          // TOP BAR
          Positioned(top: 0, left: 0, right: 0, child: SafeArea(child: Column(
            children: [
              Padding(padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text("KILLER • 4K • ${zoom.toStringAsFixed(1)}x", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                Icon(Icons.flash_on, color: Colors.white),
              ])),
              SizedBox(height: 10),
              // YA MULE VARACHE OPTION DISATIL
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                modeBtn("SLO-MO"), modeBtn("PHOTO"), modeBtn("VIDEO"),
              ]),
            ],
          ))),

          // BEAUTY SLIDER
          Positioned(right: 5, top: size.height*0.25, bottom: size.height*0.25, child: RotatedBox(quarterTurns: 3, child: Slider(value: zoom, min: 1.0, max: 8.0, activeColor: Colors.yellow, onChanged: (v) async { setState(()=>zoom=v); await ctrl!.setZoomLevel(v); }))),

          // FILTERS + BOTTOM
          Positioned(bottom: 0, left: 0, right: 0, child: SafeArea(child: Column(
            children: [
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: List.generate(names.length, (i) => GestureDetector(onTap: ()=> setState(()=>filter=i), child: Container(margin: EdgeInsets.only(left: i==0?15:8, bottom: 15), padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7), decoration: BoxDecoration(color: filter==i? Colors.white : Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white30)), child: Text(names[i], style: TextStyle(color: filter==i? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 13))))))),
              Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                GestureDetector(onTap: () async { await Gal.open(); }, child: Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.photo_library, color: Colors.white))),
                GestureDetector(onTap: capture, child: Container(width: 75, height: 75, decoration: BoxDecoration(color: isRec? Colors.red : Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)), child: Icon(isPhoto? Icons.camera_alt : (isRec? Icons.stop : Icons.videocam), size: 32, color: isRec? Colors.white : Colors.black))),
                IconButton(icon: Icon(Icons.cameraswitch, color: Colors.white, size: 30), onPressed: () async {
                  int idx = ctrl!.description == cameras[0]? 1 : 0;
                  if(idx >= cameras.length) idx=0;
                  await ctrl!.dispose();
                  ctrl = CameraController(cameras[idx], ResolutionPreset.max, enableAudio: true);
                  await ctrl!.initialize();
                  setState(() {});
                }),
              ])),
            ],
          ))),
        ],
      ),
    );
  }

  Widget modeBtn(String t){
    bool sel = (t=="PHOTO" && isPhoto) || (t=="VIDEO" &&!isPhoto);
    if(t=="SLO-MO") sel = false;
    return GestureDetector(onTap: (){ setState(()=> isPhoto = (t=="PHOTO")); }, child: Container(margin: EdgeInsets.symmetric(horizontal: 6), padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: sel? Colors.yellow : Colors.black45, borderRadius: BorderRadius.circular(15)), child: Text(t, style: TextStyle(color: sel? Colors.black : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))));
  }
}
