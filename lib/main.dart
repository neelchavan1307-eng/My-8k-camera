import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.camera.request();
  try { cameras = await availableCameras(); } catch(e){}
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.dark(), home: const CameraScreen());
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  bool isRear = true;
  double zoom = 1.0;
  double minZoom = 1.0;
  double maxZoom = 8.0;
  bool aiEnhance = false;
  int filterIndex = 0;
  List<String> filters = ['Normal', 'Vivid', 'Warm', 'Cool', 'B&W', 'Cinema'];

  @override
  void initState() { super.initState(); initCamera(); }

  Future<void> initCamera() async {
    if (cameras.isEmpty) return;
    int idx = isRear? 0 : (cameras.length > 1? 1 : 0);
    controller = CameraController(cameras[idx], ResolutionPreset.ultraHigh, enableAudio: false);
    await controller!.initialize();
    minZoom = await controller!.getMinZoomLevel();
    maxZoom = await controller!.getMaxZoomLevel();
    if (mounted) setState(() {});
  }

  @override
  void dispose() { controller?.dispose(); super.dispose(); }

  ColorFilter getColorFilter() {
    switch(filterIndex){
      case 1: return const ColorFilter.matrix([1.2,0,0,0,0, 0,1.1,0,0,0, 0,0,0.9,0,0, 0,0,0,1,0]); // Vivid
      case 2: return const ColorFilter.matrix([1.1,0,0,0,20, 0,1.0,0,0,10, 0,0,0.9,0,0, 0,0,0,1,0]); // Warm
      case 3: return const ColorFilter.matrix([0.9,0,0,0,0, 0,0.9,0,0,0, 0,0,1.2,0,10, 0,0,0,1,0]); // Cool
      case 4: return const ColorFilter.matrix([0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0,0,0,1,0]); // B&W
      case 5: return const ColorFilter.matrix([1.1,0,0,0,-10, 0,1.05,0,0,-5, 0,0,0.9,0,5, 0,0,0,1,0]); // Cinema
      default: return const ColorFilter.matrix([1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null ||!controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text('8K Pro - ${filters[filterIndex]} ${aiEnhance? "+ AI" : ""} - ${zoom.toStringAsFixed(1)}x')),
      body: Stack(children: [
        SizedBox.expand(
          child: ColorFiltered(
            colorFilter: getColorFilter(),
            child: CameraPreview(controller!),
          ),
        ),
        // Zoom Slider
        Positioned(left: 20, top: 100, bottom: 200,
          child: RotatedBox(quarterTurns: -1,
            child: Slider(value: zoom, min: minZoom, max: maxZoom,
              onChanged: (v) async { setState(()=> zoom = v); await controller!.setZoomLevel(v); },
            ),
          ),
        ),
        Positioned(top: 20, left: 20, child: Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text('${zoom.toStringAsFixed(1)}x ZOOM', style: const TextStyle(color: Colors.yellow)))),
        if(aiEnhance) Positioned(top: 20, right: 20, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(20)), child: const Row(children:[Icon(Icons.auto_awesome, size:16), SizedBox(width:4), Text('AI ENHANCE ON')]))),

        // Filter Row
        Positioned(top: 60, left: 0, right: 0, height: 40,
          child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: filters.length, itemBuilder: (c,i){
            return GestureDetector(onTap: ()=> setState(()=> filterIndex = i),
              child: Container(margin: const EdgeInsets.symmetric(horizontal:6), padding: const EdgeInsets.symmetric(horizontal:14, vertical:8),
                decoration: BoxDecoration(color: filterIndex==i? Colors.yellow : Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Text(filters[i], style: TextStyle(color: filterIndex==i? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
              ),
            );
          }),
        ),

        // Bottom Controls
        Positioned(bottom: 20, left: 0, right: 0,
          child: Column(children:[
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children:[
              IconButton(icon: Icon(Icons.switch_camera, size: 30, color: Colors.white), onPressed: (){ setState(()=> isRear =!isRear); initCamera(); }),
              GestureDetector(
                onTap: () async { final f = await controller!.takePicture(); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved Pro: ${filters[filterIndex]} ${aiEnhance? "AI" : ""} - ${f.path}'))); },
                child: Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: aiEnhance? Colors.blue : Colors.red, width: 4))),
              ),
              IconButton(icon: Icon(aiEnhance? Icons.auto_awesome : Icons.auto_awesome_outlined, color: aiEnhance? Colors.blue : Colors.white, size:30), onPressed: ()=> setState(()=> aiEnhance =!aiEnhance)),
            ]),
            const SizedBox(height:10),
            const Text('Tap AI icon for AI Enhance | Swipe filters for Colour Grading | Slider for Zoom', style: TextStyle(fontSize:10, color: Colors.white70), textAlign: TextAlign.center),
          ]),
        )
      ]),
    );
  }
}
