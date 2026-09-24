import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';

List<CameraDescription> cameras = [];
Future<void> main() async {
 WidgetsFlutterBinding.ensureInitialized();
 await [Permission.camera, Permission.photos, Permission.storage].request();
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
 double zoom = 1.0, minZoom = 1.0, maxZoom = 8.0;
 bool aiEnhance = false;
 int filterIndex = 0;
 List<String> filters = ['Normal', 'Vivid', 'Warm', 'Cool', 'B&W', 'Cinema'];
 String? lastImagePath;
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
 case 1: return const ColorFilter.matrix([1.2,0,0,0,0, 0,1.1,0,0,0, 0,0,0.9,0,0, 0,0,0,1,0]);
 case 2: return const ColorFilter.matrix([1.1,0,0,0,20, 0,1.0,0,0,10, 0,0,0.9,0,0, 0,0,0,1,0]);
 case 3: return const ColorFilter.matrix([0.9,0,0,0,0, 0,0.9,0,0,0, 0,0,1.2,0,10, 0,0,0,1,0]);
 case 4: return const ColorFilter.matrix([0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0,0,0,1,0]);
 case 5: return const ColorFilter.matrix([1.1,0,0,0,-10, 0,1.05,0,0,-5, 0,0,0.9,0,5, 0,0,0,1,0]);
 default: return const ColorFilter.matrix([1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0]);
 }
 }
 Future<void> takePhoto() async {
 if(controller==null) return;
 final file = await controller!.takePicture();
 await Gal.putImage(file.path);
 setState(()=> lastImagePath = file.path);
 if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Gallery madhe Save Zala!'), backgroundColor: Colors.green));
 }
 @override
 Widget build(BuildContext context) {
 if (controller == null ||!controller!.value.isInitialized) { return const Scaffold(body: Center(child: CircularProgressIndicator())); }
 return Scaffold(
 appBar: AppBar(title: Text('8K Pro - ${filters[filterIndex]} - ${zoom.toStringAsFixed(1)}x')),
 body: Stack(children: [
 SizedBox.expand(child: ColorFiltered(colorFilter: getColorFilter(), child: CameraPreview(controller!))),
 Positioned(left: 15, top: 100, bottom: 200, child: RotatedBox(quarterTurns: -1, child: Slider(value: zoom, min: minZoom, max: maxZoom, onChanged: (v) async { setState(()=> zoom = v); await controller!.setZoomLevel(v); }))),
 Positioned(top: 15, left: 15, child: Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text('${zoom.toStringAsFixed(1)}x ZOOM', style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)))),
 Positioned(top: 55, left: 0, right: 0, height: 40, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: filters.length, itemBuilder: (c,i){ return GestureDetector(onTap: ()=> setState(()=> filterIndex = i), child: Container(margin: const EdgeInsets.symmetric(horizontal:6), padding: const EdgeInsets.symmetric(horizontal:14, vertical:8), decoration: BoxDecoration(color: filterIndex==i? Colors.yellow : Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text(filters[i], style: TextStyle(color: filterIndex==i? Colors.black : Colors.white, fontWeight: FontWeight.bold)))); })),
 Positioned(bottom: 20, left: 20, right: 20, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
 GestureDetector(onTap: () async { await Gal.open(); }, child: Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 2)), child: lastImagePath!=null? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(lastImagePath!), fit: BoxFit.cover)) : const Icon(Icons.photo_library, color: Colors.white, size: 30))),
 GestureDetector(onTap: takePhoto, child: Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: aiEnhance? Colors.blue : Colors.red, width: 4)), child: const Icon(Icons.camera_alt, color: Colors.black, size: 35))),
 Column(children:[ IconButton(icon: const Icon(Icons.switch_camera, color: Colors.white, size: 28), onPressed: (){ setState(()=> isRear =!isRear); initCamera(); }), IconButton(icon: Icon(aiEnhance? Icons.auto_awesome : Icons.auto_awesome_outlined, color: aiEnhance? Colors.blue : Colors.white, size: 26), onPressed: ()=> setState(()=> aiEnhance =!aiEnhance)), ])
 ])),
 ]),
 );
 }
}
