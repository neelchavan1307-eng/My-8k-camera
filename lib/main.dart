import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
  double blurPower = 0.0;
  int filter = 0;
  bool isProcessing = false;

  List<String> names = ["Original", "RRR", "KGF", "Cinematic", "DSLR"];
  List<Color> fColor = [Colors.transparent, Colors.orange, Colors.amber, Colors.brown, Colors.white];

  @override
  void initState() { super.initState(); initCam(); }

  initCam() async {
    await [Permission.camera, Permission.microphone, Permission.photos, Permission.videos, Permission.storage].request();
    ctrl = CameraController(cameras[0], ResolutionPreset.max, enableAudio: true);
    await ctrl!.initialize();
    await ctrl!.setFocusMode(FocusMode.auto);
    await ctrl!.setExposureMode(ExposureMode.auto);
    setState(() {});
  }

  // DSLR SETTING - f/1.8 + 2x Zoom
  setDSLR(bool enable) async {
    if (enable) {
      setState(() { zoom = 2.0; blurPower = 20; filter = 4; });
      await ctrl!.setZoomLevel(2.0);
    } else {
      setState(() { zoom = 1.0; blurPower = 0.0; filter = 0; });
      await ctrl!.setZoomLevel(1.0);
    }
  }

  // AI ULTRA CLEAR - ZOOM PHOTO CLEAR KARNE
  Future<void> makeUltraClear(String originalPath) async {
    try {
      setState(() => isProcessing = true);
      final bytes = await File(originalPath).readAsBytes();
      img.Image? original = img.decodeImage(bytes);
      if (original == null) return;

      // 2X Upscale - AI Sarkha
      img.Image upscaled = img.copyResize(
        original,
        width: original.width * 2,
        height: original.height * 2,
        interpolation: img.Interpolation.cubic,
      );

      // Sharpen - Ultra Clear
      img.Image sharpened = img.convolution(
        upscaled,
        filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
        div: 1,
      );

      final dir = await getTemporaryDirectory();
      final newPath = "${dir.path}/ultra_${DateTime.now().millisecondsSinceEpoch}.jpg";
      await File(newPath).writeAsBytes(img.encodeJpg(sharpened, quality: 98));

      await Gal.putImage(newPath, album: "KillerCam Ultra");
      setState(() => isProcessing = false);

      if(mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🔥 AI ULTRA CLEAR SAVE ZHALA! Gallery > KillerCam Ultra"), backgroundColor: Colors.green)
      );
    } catch (e) {
      setState(() => isProcessing = false);
    }
  }

  capture() async {
    if (ctrl == null) return;
    if (isPhoto) {
      XFile f = await ctrl!.takePicture();
      await Gal.putImage(f.path, album: "KillerCam");

      if(mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("📸 Original Save! AI Clear hotay..."))
      );

      // AI Clear banav
      await makeUltraClear(f.path);

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
    if (ctrl == null ||!ctrl!.value.isInitialized) {
      return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.yellow)));
    }
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // FULL SCREEN CAMERA - kali patti 100% janar
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: size.width,
              height: size.height / ctrl!.value.aspectRatio,
              child: CameraPreview(ctrl!),
            ),
          ),

          if (filter!= 0) Container(color: fColor[filter].withOpacity(filter == 4? 0.12 : 0.22)),

          // TOP BAR
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                        child: Text("KILLER • 4K • ${zoom.toStringAsFixed(1)}x • f/1.8", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                      if(isProcessing) Row(children: [SizedBox(width:15, height:15, child: CircularProgressIndicator(strokeWidth:2, color: Colors.yellow)), SizedBox(width:5), Text("AI...", style: TextStyle(color: Colors.yellow, fontSize: 10))]) else Icon(Icons.bokeh, color: filter == 4? Colors.yellow : Colors.white),
                    ]),
                  ),
                  SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    modeBtn("SLO-MO"), modeBtn("PHOTO"), modeBtn("VIDEO"), dslrBtn(),
                  ]),
                ],
              ),
            ),
          ),

          // RIGHT ZOOM SLIDER
          Positioned(
            right: 0, top: size.height * 0.25, bottom: size.height * 0.25,
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                value: zoom, min: 1.0, max: 8.0,
                activeColor: Colors.yellow, inactiveColor: Colors.white30,
                onChanged: (v) async { setState(() => zoom = v); await ctrl!.setZoomLevel(v); },
              ),
            ),
          ),

          // BOTTOM
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(names.length, (i) => GestureDetector(
                        onTap: () async {
                          if (i == 4) await setDSLR(true); else { setState(() => filter = i); if(zoom==2.0) { setState(()=> zoom=1.0); await ctrl!.setZoomLevel(1.0);} }
                        },
                        child: Container(
                          margin: EdgeInsets.only(left: i == 0? 15 : 8, bottom: 12),
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(color: filter == i? Colors.yellow : Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white30)),
                          child: Text(names[i], style: TextStyle(color: filter == i? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      )),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      GestureDetector(onTap: () async { await Gal.open(); }, child: Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.photo_library, color: Colors.white))),
                      GestureDetector(
                        onTap: isProcessing? null : capture,
                        child: Container(width: 78, height: 78, decoration: BoxDecoration(color: isRec? Colors.red : Colors.white, shape: BoxShape.circle, border: Border.all(color: filter == 4? Colors.yellow : Colors.white, width: 4)), child: Icon(isPhoto? Icons.camera_alt : (isRec? Icons.stop : Icons.videocam), size: 33, color: isRec? Colors.white : Colors.black)),
                      ),
                      IconButton(icon: Icon(Icons.cameraswitch, color: Colors.white, size: 30), onPressed: () async {
                        int idx = ctrl!.description == cameras[0]? 1 : 0;
                        if (idx >= cameras.length) idx = 0;
                        await ctrl!.dispose();
                        ctrl = CameraController(cameras[idx], ResolutionPreset.max, enableAudio: true);
                        await ctrl!.initialize();
                        setState(() {});
                      }),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget modeBtn(String t) {
    bool sel = (t == "PHOTO" && isPhoto) || (t == "VIDEO" &&!isPhoto);
    return GestureDetector(
      onTap: () => setState(() => isPhoto = (t == "PHOTO")),
      child: Container(margin: EdgeInsets.symmetric(horizontal: 5), padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: sel? Colors.white : Colors.black45, borderRadius: BorderRadius.circular(12)), child: Text(t, style: TextStyle(color: sel? Colors.black : Colors.white70, fontSize: 10, fontWeight: FontWeight.bold))),
    );
  }

  Widget dslrBtn() {
    bool sel = filter == 4;
    return GestureDetector(
      onTap: () => setDSLR(!sel),
      child: Container(margin: EdgeInsets.symmetric(horizontal: 5), padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: sel? Colors.yellow : Colors.black45, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel? Colors.yellow : Colors.transparent)), child: Text("DSLR", style: TextStyle(color: sel? Colors.black : Colors.white70, fontSize: 10, fontWeight: FontWeight.bold))),
    );
  }
}
