import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> cameras = [];
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: Pro8KApp()));
}

class Pro8KApp extends StatefulWidget {
  const Pro8KApp({super.key});
  @override
  State<Pro8KApp> createState() => _Pro8KAppState();
}

class _Pro8KAppState extends State<Pro8KApp> {
  CameraController? controller;
  bool isReady = false;
  bool isRecording = false;
  bool gridOn = true;
  FlashMode flashMode = FlashMode.off;
  double zoomLevel = 1.0;
  String selectedMode = "Photo";
  int filterIdx = 0;
  List<String> modes = ["Ultra HD", "Video", "Photo", "Portrait", "Night", "Pro 8K"];
  List<String> filterNames = ["Normal", "Vivid", "B&W", "Warm", "Cool", "Cinema"];
  List<Color> filterColors = [Colors.transparent, Colors.orangeAccent.withOpacity(0.12), Colors.white.withOpacity(0.15), Colors.amber.withOpacity(0.18), Colors.blue.withOpacity(0.12), Colors.purple.withOpacity(0.10)];

  Future<void> initCam() async {
    await [Permission.camera, Permission.microphone, Permission.photos, Permission.storage].request();
    controller = CameraController(cameras[0], ResolutionPreset.ultraHigh, enableAudio: true);
    await controller!.initialize();
    setState(() => isReady = true);
  }

  @override
  void initState() { super.initState(); initCam(); }

  Future<void> takePicture() async {
    if (selectedMode == "Video") {
      if (isRecording) {
        final file = await controller!.stopVideoRecording();
        await Gal.putVideo(file.path);
        setState(() => isRecording = false);
      } else {
        await controller!.startVideoRecording();
        setState(() => isRecording = true);
      }
    } else {
      final file = await controller!.takePicture();
      await Gal.putImage(file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$selectedMode Saved ✅"), backgroundColor: Colors.green));
      }
    }
  }

  @override
  void dispose() { controller?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!isReady) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.yellow)));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SizedBox.expand(child: CameraPreview(controller!)),
          Container(color: filterColors[filterIdx]),
          if (gridOn) CustomPaint(size: Size.infinite, painter: GridLinePainter()),
          Positioned(
            bottom: 185,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              color: Colors.black54,
              child: const Text("SHOT ON 8K PRO • 108MP", style: TextStyle(color: Colors.white70, fontSize: 9)),
            ),
          ),
          // Top
          SafeArea(
            child: Container(
              color: Colors.black45,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(onTap: () async { flashMode = flashMode == FlashMode.off? FlashMode.always : FlashMode.off; await controller!.setFlashMode(flashMode); setState(() {}); }, child: Icon(flashMode == FlashMode.off? Icons.flash_off : Icons.flash_on, color: Colors.white, size: 22)),
                      const SizedBox(width: 16),
                      GestureDetector(onTap: () => setState(() => gridOn =!gridOn), child: Icon(gridOn? Icons.grid_on : Icons.grid_off, color: Colors.white, size: 22)),
                      const SizedBox(width: 16),
                      GestureDetector(onTap: () async { zoomLevel = zoomLevel == 1.0? 2.0 : 1.0; await controller!.setZoomLevel(zoomLevel); setState(() {}); }, child: const Icon(Icons.zoom_in, color: Colors.white, size: 22)),
                    ],
                  ),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.yellow, borderRadius: BorderRadius.circular(5)), child: Text(selectedMode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black))),
                ],
              ),
            ),
          ),
          // Bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 15, 10, 28),
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black, Colors.transparent])),
              child: Column(
                children: [
                  SizedBox(
                    height: 55,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: filterNames.length,
                      itemBuilder: (context, i) {
                        bool sel = i == filterIdx;
                        return GestureDetector(
                          onTap: () => setState(() => filterIdx = i),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 60,
                            decoration: BoxDecoration(color: sel? Colors.yellow : Colors.white24, borderRadius: BorderRadius.circular(8)),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.filter_alt, size: 20, color: sel? Colors.black : Colors.white), const SizedBox(height: 2), Text(filterNames[i], style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: sel? Colors.black : Colors.white))]),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 32,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: modes.length,
                      itemBuilder: (context, i) {
                        bool sel = modes[i] == selectedMode;
                        return GestureDetector(
                          onTap: () => setState(() => selectedMode = modes[i]),
                          child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: sel? Colors.white : Colors.white12, borderRadius: BorderRadius.circular(20)), child: Center(child: Text(modes[i], style: TextStyle(color: sel? Colors.black : Colors.white70, fontSize: 12, fontWeight: sel? FontWeight.bold : FontWeight.normal)))),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [0.6, 1.0, 2.0, 4.0].map((z) {
                      return GestureDetector(
                        onTap: () async { await controller!.setZoomLevel(z); setState(() => zoomLevel = z); },
                        child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: zoomLevel == z? Colors.yellow : Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)), child: Text("${z}x", style: TextStyle(color: zoomLevel == z? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.photo_library, color: Colors.white)),
                      GestureDetector(onTap: takePicture, child: Container(width: 80, height: 80, decoration: BoxDecoration(color: isRecording? Colors.red : Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)), child: Icon(selectedMode == "Video"? (isRecording? Icons.stop : Icons.videocam) : Icons.camera_alt, color: Colors.black, size: 34))),
                      GestureDetector(
                        onTap: () async { var newCam = controller!.description == cameras[0]? (cameras.length > 1? cameras[1] : cameras[0]) : cameras[0]; controller = CameraController(newCam, ResolutionPreset.ultraHigh, enableAudio: true); await controller!.initialize(); setState(() {}); },
                        child: Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.cameraswitch, color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GridLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()..color = Colors.white24..strokeWidth = 0.6;
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
