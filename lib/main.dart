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
  CameraController? _controller;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _timer;
  double _zoom = 1.0;
  FlashMode _flash = FlashMode.off;
  double _exposure = 0.0;

  @override
  void initState() {
    super.initState();
    _initCam();
  }

  Future<void> _initCam() async {
    _controller = CameraController(cameras[0], ResolutionPreset.ultraHigh, enableAudio: true);
    await _controller!.initialize();
    // FIX 1: BRIGHTNESS FIX
    await _controller!.setExposureMode(ExposureMode.auto);
    await _controller!.setExposureOffset(0.0);
    await _controller!.setFocusMode(FocusMode.auto);
    if(mounted) setState(() {});
  }

  Future<void> takePhoto() async {
    // FIX 2: SOUND FIX (bina file cha)
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
    try {
      await _controller!.takePicture();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚡ KATAK! Photo Saved'), duration: Duration(milliseconds: 800)));
    } catch(e){print(e);}
  }

  Future<void> startVideo() async {
    try {
      // FIX 1: Video aadhi brightness parat auto
      await _controller!.setExposureMode(ExposureMode.auto);
      await _controller!.setExposureOffset(_exposure);

      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);

      await _controller!.startVideoRecording();
      setState((){ _isRecording=true; _recordSeconds=0; });

      // FIX 3: TIMING FIX
      _timer?.cancel();
      _timer = Timer.periodic(Duration(seconds: 1), (t){
        if(mounted) setState(()=> _recordSeconds++);
      });
    } catch(e){print(e);}
  }

  Future<void> stopVideo() async {
    _timer?.cancel();
    try {
      await _controller!.stopVideoRecording();
      await _controller!.setExposureOffset(_exposure);
      setState((){ _isRecording=false; _recordSeconds=0; });
    } catch(e){print(e);}
  }

  String get _timeText => "${(_recordSeconds~/60).toString().padLeft(2,'0')}:${(_recordSeconds%60).toString().padLeft(2,'0')}";

  @override
  Widget build(BuildContext context) {
    if(_controller==null ||!_controller!.value.isInitialized) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.amber)));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        SizedBox.expand(child: CameraPreview(_controller!)),
        // TOP BAR
        SafeArea(child: Column(children: [
          SizedBox(height: 10),
          Center(child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text("KILLER CAM • ${_zoom.toStringAsFixed(1)}x", style: TextStyle(fontWeight: FontWeight.bold)),
              if(_isRecording)...[SizedBox(width:10), Icon(Icons.circle, color: Colors.red, size:12), SizedBox(width:5), Text(_timeText, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]
            ]),
          )),
          SizedBox(height: 10),
          // OPTIONS ROW
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            IconButton(icon: Icon(_flash==FlashMode.off?Icons.flash_off:Icons.flash_on, color: Colors.white), onPressed: () async {
              _flash = _flash==FlashMode.off?FlashMode.torch:FlashMode.off;
              await _controller!.setFlashMode(_flash);
              setState((){});
            }),
            Container(padding: EdgeInsets.symmetric(horizontal:8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)), child: DropdownButton<double>(value: _zoom, dropdownColor: Colors.black, underline: SizedBox(), items: [1.0,2.0,3.0,5.0,8.0].map((e)=>DropdownMenuItem(value:e, child: Text("${e}x", style:TextStyle(color:Colors.white)))).toList(), onChanged: (v) async { _zoom=v!; await _controller!.setZoomLevel(_zoom); setState((){}); })),
          ])
        ])),
        // BRIGHTNESS SLIDER
        Positioned(right: 10, top: 150, child: RotatedBox(quarterTurns: 3, child: Slider(value: _exposure, min: -2, max: 2, activeColor: Colors.amber, onChanged: (v) async { _exposure=v; await _controller!.setExposureOffset(v); setState((){}); }))),
        // BOTTOM BUTTONS
        Align(alignment: Alignment.bottomCenter, child: Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            IconButton(icon: Icon(Icons.photo_library, color: Colors.white, size:30), onPressed: (){}),
            GestureDetector(
              onTap: () => _isRecording? stopVideo() : startVideo(),
              onDoubleTap: takePhoto,
              onLongPress: startVideo,
              onLongPressUp: stopVideo,
              child: Container(width:80, height:80, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width:4), color: _isRecording?Colors.red:Colors.white), child: Icon(_isRecording?Icons.stop:Icons.videocam, size:40, color: _isRecording?Colors.white:Colors.black)),
            ),
            IconButton(icon: Icon(Icons.cameraswitch, color: Colors.white, size:30), onPressed: () async {
              final newCam = cameras[0]==_controller!.description?cameras[1]:cameras[0];
              await _controller!.dispose();
              _controller = CameraController(newCam, ResolutionPreset.ultraHigh, enableAudio: true);
              await _controller!.initialize();
              await _controller!.setExposureOffset(_exposure);
              setState((){});
            }),
          ]),
        ))
      ]),
    );
  }
}
