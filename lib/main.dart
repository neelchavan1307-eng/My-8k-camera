import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: CamScreen()));
}

class CamScreen extends StatefulWidget {
  @override
  State<CamScreen> createState() => _CamScreenState();
}

class _CamScreenState extends State<CamScreen> {
  CameraController? controller;
  bool isRecording = false;
  int sec = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    initCam();
  }

  Future<void> initCam() async {
    controller = CameraController(cameras[0], ResolutionPreset.ultraHigh, enableAudio: true);
    await controller!.initialize();
    // BRIGHTNESS FIX
    await controller!.setExposureMode(ExposureMode.auto);
    await controller!.setExposureOffset(0.0);
    await controller!.setFocusMode(FocusMode.auto);
    setState(() {});
  }

  Future<void> takePhoto() async {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click); // SOUND FIX
    await controller!.takePicture();
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KATAK! Photo Saved')));
  }

  Future<void> startVideo() async {
    // BRIGHTNESS FIX - Video adhi
    await controller!.setExposureMode(ExposureMode.auto);
    await controller!.setExposureOffset(0.0);

    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click); // SOUND FIX

    await controller!.startVideoRecording();
    setState((){ isRecording=true; sec=0; });

    // TIMING FIX
    timer = Timer.periodic(Duration(seconds: 1), (t){
      setState(()=> sec++);
    });
  }

  Future<void> stopVideo() async {
    timer?.cancel();
    await controller!.stopVideoRecording();
    await controller!.setExposureOffset(0.0); // parat light vadhva
    setState((){ isRecording=false; sec=0; });
  }

  String get timeText => "${(sec~/60).toString().padLeft(2,'0')}:${(sec%60).toString().padLeft(2,'0')}";

  @override
  Widget build(BuildContext context) {
    if(controller==null ||!controller!.value.isInitialized) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.amber)));
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        SizedBox.expand(child: CameraPreview(controller!)),
        SafeArea(child: Column(children: [
          SizedBox(height: 10),
          Center(child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text("KILLER CAM • 1.0x", style: TextStyle(fontWeight: FontWeight.bold)),
              if(isRecording)...[SizedBox(width:10), Icon(Icons.circle, color: Colors.red, size:12), SizedBox(width:5), Text(timeText, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]
            ]),
          )),
        ])),
        Align(alignment: Alignment.bottomCenter, child: Padding(
          padding: EdgeInsets.only(bottom: 30),
          child: GestureDetector(
            onTap: () => isRecording? stopVideo() : startVideo(),
            onDoubleTap: takePhoto,
            child: Container(width:80, height:80, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width:4), color: isRecording?Colors.red:Colors.white), child: Icon(isRecording?Icons.stop:Icons.videocam, size:40)),
          ),
        ))
      ]),
    );
  }
}
