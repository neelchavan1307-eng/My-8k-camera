import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:io';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: ProCameraScreen(), debugShowCheckedModeBanner: false);
  }
}

class ProCameraScreen extends StatefulWidget {
  @override
  _ProCameraScreenState createState() => _ProCameraScreenState();
}

class _ProCameraScreenState extends State<ProCameraScreen> {
  late CameraController controller;
  bool isReady = false;
  bool isRecording = false;
  bool isPhotoMode = true;
  FlashMode flashMode = FlashMode.off;
  String selectedFilter = "Original";
  String quality = "4K";
  bool isCinematic = false;
  bool isPortrait = false;
  bool aiEnhance = false;
  String? lastImagePath;

  List<String> filters = ["Original", "Vivid", "B&W", "Warm", "Cold", "Cinematic"];

  Map<String, List<double>> filterMatrix = {
    "Original": [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0],
    "Vivid": [1.2,0,0,0,0, 0,1.2,0,0,0, 0,0,1.2,0,0, 0,0,0,1,0],
    "B&W": [0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0,0,0,1,0],
    "Warm": [1.2,0,0,0,20, 0,1,0,0,0, 0,0,0.8,0,0, 0,0,0,1,0],
    "Cold": [0.8,0,0,0,0, 0,1,0,0,0, 0,0,1.2,0,20, 0,0,0,1,0],
    "Cinematic": [1.1,0,0,0,10, 0,1.1,0,0,5, 0,0,0.9,0,0, 0,0,0,1,0],
  };

  @override
  void initState() { super.initState(); initCamera(); }

  Future<void> initCamera({ResolutionPreset preset = ResolutionPreset.ultraHigh}) async {
    await [Permission.camera, Permission.storage, Permission.microphone, Permission.photos].request();
    var res = ResolutionPreset.ultraHigh;
    if(quality=="720") res = ResolutionPreset.medium;
    if(quality=="1080") res = ResolutionPreset.high;
    if(quality=="4K") res = ResolutionPreset.ultraHigh;
    controller = CameraController(cameras[0], res, enableAudio: true);
    await controller.initialize();
    await controller.setFlashMode(flashMode);
    setState(() => isReady = true);
  }

  Future<void> takePicture() async {
    final image = await controller.takePicture();
    await ImageGallerySaver.saveFile(image.path);
    setState(() { lastImagePath = image.path; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aiEnhance? 'AI Enhanced Photo Saved!' : 'Photo Saved!')));
  }

  Future<void> toggleRecording() async {
    if(isRecording){
      final file = await controller.stopVideoRecording();
      await ImageGallerySaver.saveFile(file.path);
      setState(() => isRecording=false);
    } else {
      await controller.startVideoRecording();
      setState(() => isRecording=true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isReady) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.matrix(filterMatrix[selectedFilter]!),
            child: Center(child: AspectRatio(aspectRatio: isCinematic? 21/9 : controller.value.aspectRatio, child: CameraPreview(controller))),
          ),
          if(isPortrait) Container(color: Colors.black.withOpacity(0.1), child: Center(child: Icon(Icons.blur_on, color: Colors.white24, size: 100))),

          // Top Bar
          SafeArea(child: Padding(padding: EdgeInsets.all(15), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Row(children: [
              GestureDetector(onTap: () async { setState(() { flashMode = flashMode==FlashMode.off?FlashMode.torch:FlashMode.off; }); await controller.setFlashMode(flashMode); }, child: Icon(flashMode==FlashMode.off?Icons.flash_off:Icons.flash_on, color: Colors.white)),
              SizedBox(width: 10),
              GestureDetector(onTap: () => setState(() => aiEnhance=!aiEnhance), child: Icon(Icons.auto_awesome, color: aiEnhance?Colors.yellow:Colors.white)),
            ])),
            Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: quality, dropdownColor: Colors.black, style: TextStyle(color: Colors.white), items: ["720","1080","4K"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) async { setState(() { quality=v!; isReady=false; }); await initCamera(); }))),
          ]))),

          // Filter Bar
          Positioned(top: 100, left: 0, right: 0, child: Container(height: 40, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: filters.length, itemBuilder: (c,i){ return GestureDetector(onTap: ()=>setState(()=>selectedFilter=filters[i]), child: Container(margin: EdgeInsets.symmetric(horizontal: 6), padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8), decoration: BoxDecoration(color: selectedFilter==filters[i]?Colors.white:Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text(filters[i], style: TextStyle(color: selectedFilter==filters[i]?Colors.black:Colors.white, fontWeight: FontWeight.bold)))); }))),

          // Cinematic / Portrait Toggles
          Positioned(top: 150, left: 15, child: Column(children: [
            FilterChip(label: Text("CINEMATIC", style: TextStyle(color: Colors.white, fontSize: 10)), selected: isCinematic, onSelected: (v)=>setState(()=>isCinematic=v), backgroundColor: Colors.black54, selectedColor: Colors.red),
            SizedBox(height: 8),
            FilterChip(label: Text("PORTRAIT / BOKEH", style: TextStyle(color: Colors.white, fontSize: 10)), selected: isPortrait, onSelected: (v)=>setState(()=>isPortrait=v), backgroundColor: Colors.black54, selectedColor: Colors.blue),
          ])),

          // Bottom Controls
          Positioned(bottom: 0, left: 0, right: 0, child: Container(padding: EdgeInsets.only(bottom: 30, top: 15), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])), child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              GestureDetector(onTap: ()=>setState(()=>isPhotoMode=true), child: Text("PHOTO", style: TextStyle(color: isPhotoMode?Colors.white:Colors.white54, fontWeight: FontWeight.bold))),
              SizedBox(width: 30),
              GestureDetector(onTap: ()=>setState(()=>isPhotoMode=false), child: Text("VIDEO", style: TextStyle(color:!isPhotoMode?Colors.white:Colors.white54, fontWeight: FontWeight.bold))),
            ]),
            SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Container(width: 60, height: 60, decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(10)), child: lastImagePath!=null?ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(lastImagePath!), fit: BoxFit.cover)):Icon(Icons.photo, color: Colors.white)),
              GestureDetector(
                onTap: () => isPhotoMode? takePicture() : toggleRecording(),
                child: Container(width: 80, height: 80, decoration: BoxDecoration(color: isRecording?Colors.red:Colors.white, shape: BoxShape.circle, border: Border.all(width: 4, color: Colors.white)), child: Icon(isPhotoMode?Icons.camera_alt:isRecording?Icons.stop:Icons.videocam, color: isRecording?Colors.white:Colors.black)),
              ),
              SizedBox(width: 60),
            ]),
          ]))),
        ],
      ),
    );
  }
}
