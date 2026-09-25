import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> cameras = [];
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: Pro8KCamera()));
}

class Pro8KCamera extends StatefulWidget { const Pro8KCamera({super.key}); @override State<Pro8KCamera> createState() => _Pro8KCameraState(); }

class _Pro8KCameraState extends State<Pro8KCamera> {
  CameraController? controller;
  bool ready = false, isRecording = false, gridOn = false, hdrOn = true;
  FlashMode flashMode = FlashMode.off;
  double zoom = 1.0, ev = 0.0;
  String selectedMode = "Photo";
  List<String> allModes = ["Ultra HD", "Video", "Photo", "Portrait", "Night", "Pro 8K"];

  Future<void> initCamera() async {
    await [Permission.camera, Permission.microphone, Permission.photos, Permission.storage].request();
    controller = CameraController(cameras[0], ResolutionPreset.ultraHigh, enableAudio: true);
    await controller!.initialize();
    await controller!.setExposureMode(ExposureMode.auto);
    await controller!.setFocusMode(FocusMode.auto);
    await controller!.setExposureOffset(0.0);
    setState(()=> ready = true);
  }
  @override void initState(){ super.initState(); initCamera(); }

  Future<void> takeShot() async {
    if(selectedMode == "Video"){
      if(isRecording){
        final file = await controller!.stopVideoRecording();
        await Gal.putVideo(file.path);
        setState(()=> isRecording=false);
      } else {
        await controller!.startVideoRecording();
        setState(()=> isRecording=true);
      }
    } else {
      final file = await controller!.takePicture();
      await Gal.putImage(file.path);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$selectedMode Saved ✅ 8K Pro"), backgroundColor: Colors.black));
    }
  }

  @override void dispose(){ controller?.dispose(); super.dispose(); }

  @override Widget build(BuildContext context){
    if(!ready || controller==null) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.yellow)));
    bool isPhoto = selectedMode!= "Video";
    return Scaffold(backgroundColor: Colors.black,
      body: Stack(children: [
        SizedBox.expand(child: CameraPreview(controller!)),
        if(gridOn) CustomPaint(size: Size.infinite, painter: GridPainter()),

        // TOP BAR - PRO
        SafeArea(child: Container(color: Colors.black.withOpacity(0.4), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              _topBtn(flashMode==FlashMode.off? Icons.flash_off : Icons.flash_on, () async { flashMode = flashMode==FlashMode.off? FlashMode.always:FlashMode.off; await controller!.setFlashMode(flashMode); setState((){}); }),
              _topBtn(hdrOn? Icons.hdr_on : Icons.hdr_off, ()=> setState(()=> hdrOn=!hdrOn)),
              _topBtn(Icons.grid_on, ()=> setState(()=> gridOn=!gridOn)),
              _topBtn(Icons.exposure, () async { ev = ev>=1? -1 : ev+0.5; await controller!.setExposureOffset(ev); setState((){}); }),
            ]),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.yellow, borderRadius: BorderRadius.circular(6)), child: Text("${selectedMode.toUpperCase()} ${selectedMode=="Pro 8K"?"33MP":"HD"}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)))
          ]),
        )),

        // BOTTOM - PROMO LOOK
        Positioned(bottom: 0, left: 0, right: 0, child: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black, Colors.black87, Colors.transparent])),
          padding: const EdgeInsets.fromLTRB(10, 20, 10, 28),
          child: Column(children: [
            // Mode Scroller
            SizedBox(height: 32, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: allModes.length, itemBuilder: (c,i){
              bool sel = allModes[i]==selectedMode;
              return GestureDetector(onTap: ()=> setState(()=> selectedMode=allModes[i]),
                child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: sel? Colors.white : Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Center(child: Text(allModes[i], style: TextStyle(color: sel? Colors.black:Colors.white70, fontWeight: sel? FontWeight.bold:FontWeight.w400, fontSize: 13)))));
            })),
            const SizedBox(height: 14),
            // Zoom Bar
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [0.6, 1.0, 2.0, 4.0, 8.0].map((z){
              return GestureDetector(onTap: () async { await controller!.setZoomLevel(z); setState(()=> zoom=z); },
                child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: zoom==z? Colors.yellow : Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)), child: Text("${z}x", style: TextStyle(color: zoom==z? Colors.black:Colors.white, fontSize: 12, fontWeight: FontWeight.bold))));
            }).toList()),
            const SizedBox(height: 16),
            // Shutter
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12), border: Border
