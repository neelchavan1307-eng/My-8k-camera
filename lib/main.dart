import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MaterialApp(home: CameraApp(), debugShowCheckedModeBanner: false));
}

class CameraApp extends StatefulWidget {
  @override State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late CameraController controller;
  bool ready = false, isRecording = false;
  String selectedFilter = "DSLR Portrait";
  String mode = "Photo"; // Photo / Video
  String? lastPath;
  Timer? t;
  int sec = 0;
  double zoom = 1.0;
  int camIndex = 0;

  List<String> filters = ["DSLR Portrait","Bokeh Mode","DSLR 1","DSLR 2","DSLR 3","DSLR 4"];

  @override void initState() { super.initState(); initCam(0); }

  Future<void> initCam(int idx) async {
    setState(() => ready = false);
    controller = CameraController(cameras[idx], ResolutionPreset.high, enableAudio: true);
    await controller.initialize();
    await controller.setZoomLevel(1.0);
    setState(() => ready = true);
  }

  void setZoom(double z) { double nz = z.clamp(0.6, 8.0); setState(() => zoom = nz); controller.setZoomLevel(nz); }
  String fmt(int s) => "${(s~/60).toString().padLeft(2,'0')}:${(s%60).toString().padLeft(2,'0')}";

  Future<void> saveToGallery(String path) async {
    try {
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      if (path.endsWith(".jpg")) await Gal.putImage(path, album: "DSLR Camera");
      else await Gal.putVideo(path, album: "DSLR Camera");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ $selectedFilter - Save jhala!"), backgroundColor: Colors.green, duration: Duration(seconds: 1)));
    } catch(e) {}
  }

  Future<void> takePhoto() async {
    var x = await controller.takePicture();
    var dir = await getApplicationDocumentsDirectory();
    String p = "${dir.path}/DSLR_${DateTime.now().millisecondsSinceEpoch}.jpg";
    await File(x.path).copy(p);
    setState(() => lastPath = p);
    await saveToGallery(p);
  }

  Future<void> startVideo() async { await controller.startVideoRecording(); setState(() { isRecording = true; sec = 0; }); t = Timer.periodic(Duration(seconds: 1), (timer) => setState(() => sec++)); }
  Future<void> stopVideo() async { t?.cancel(); var x = await controller.stopVideoRecording(); var dir = await getApplicationDocumentsDirectory(); String p = "${dir.path}/VID_${DateTime.now().millisecondsSinceEpoch}.mp4"; await File(x.path).copy(p); setState(() { isRecording = false; lastPath = p; }); await saveToGallery(p); }

  @override Widget build(BuildContext context) {
    if (!ready) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    return Scaffold(backgroundColor: Colors.black, body: Stack(children: [
      SizedBox.expand(child: CameraPreview(controller)),

      SafeArea(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Row(children: [
        Icon(Icons.flash_off, color: Colors.white, size: 22),
        SizedBox(width: 20),
        Icon(Icons.hdr_on_outlined, color: Colors.white, size: 22),
        Spacer(),
        Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(12)), child: Text(selectedFilter, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black))),
      ]))),

      if (isRecording) Positioned(top: 90, left: 0, right: 0, child: Center(child: Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)), child: Text("● REC ${fmt(sec)}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))))),

      // BOTTOM - TUZYA SCREEN SARKHA
      Positioned(bottom: 0, left: 0, right: 0, child: Container(
        padding: EdgeInsets.only(bottom: 28, top: 10),
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])),
        child: Column(children: [
          // 0.6 1x 2 4
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _zoomBtn("0.6", 0.6),
              _zoomBtn("1x", 1.0),
              _zoomBtn("2", 2.0),
              _zoomBtn("4", 4.0),
            ]),
          ),
          SizedBox(height: 14),

          // === AAPLE 6 OPTIONS SLIDE MADHE ===
          SizedBox(height: 36, child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: filters.length,
            itemBuilder: (c,i) {
              bool sel = filters[i]==selectedFilter;
              return GestureDetector(
                onTap: () => setState(()=> selectedFilter = filters[i]),
                child: Container(
                  margin: EdgeInsets.only(right: 18),
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(border: sel? Border(bottom: BorderSide(color: Colors.amber, width: 2)):null),
                  child: Text(filters[i], style: TextStyle(color: sel? Colors.amber:Colors.white70, fontWeight: sel? FontWeight.bold:FontWeight.normal, fontSize: sel? 15:14)),
                ),
              );
            },
          )),
          SizedBox(height: 14),

          Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.white24, image: lastPath!=null && lastPath!.endsWith(".jpg")? DecorationImage(image: FileImage(File(lastPath!)), fit: BoxFit.cover):null)),
            GestureDetector(
              onTap: () async { if(isRecording) await stopVideo(); else { if(mode=="Photo") await takePhoto(); else await startVideo(); } },
              child: Container(width: 72, height: 72, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)), child: Icon(isRecording? Icons.stop: Icons.camera_alt, color: isRecording? Colors.red:Colors.black, size: 30)),
            ),
            Row(children: [
              GestureDetector(onTap: ()=> setState(()=> mode = mode=="Photo"? "Video":"Photo"), child: Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: Icon(mode=="Photo"? Icons.videocam:Icons.camera_alt, color: Colors.white, size: 20))),
              SizedBox(width: 10),
              GestureDetector(onTap: () async { camIndex = camIndex==0?1:0; if(cameras.length>1) await initCam(camIndex); }, child: Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: Icon(Icons.cameraswitch, color: Colors.white, size: 20))),
            ])
          ]))
        ]),
      ))
    ]));
  }

  Widget _zoomBtn(String txt, double zVal) {
    bool sel = (zoom==zVal) || (zoom>0.9 && zoom<1.1 && zVal==1.0);
    return GestureDetector(onTap: ()=> setZoom(zVal), child: Container(margin: EdgeInsets.symmetric(horizontal: 6), padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: sel? Colors.white:Colors.transparent, borderRadius: BorderRadius.circular(10)), child: Text(txt, style: TextStyle(color: sel? Colors.black:Colors.white, fontSize: 12, fontWeight: FontWeight.bold))));
  }
}
