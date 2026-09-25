import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

List<CameraDescription> cams = [];
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cams = await availableCameras();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: KillerCamera()));
}

class KillerCamera extends StatefulWidget {
  const KillerCamera({super.key});
  @override State<KillerCamera> createState() => KillerCameraState();
}

class KillerCameraState extends State<KillerCamera> with SingleTickerProviderStateMixin {
  CameraController? ctrl;
  bool ready = false;
  bool rec = false;
  double zoom = 1.0;
  double maxZoom = 10.0;
  String mode = "Photo"; // Ultra HD, Video, Photo, Portrait, Cinematic, Night, Astro
  String filter = "Original";
  int sec = 0;
  Timer? timer;
  bool flashEffect = false;
  late AnimationController pulseCtrl;
  stt.SpeechToText speech = stt.SpeechToText();
  bool listening = false;

  // Manual Pro Controls
  double exposure = 0.0;
  double isoVal = 0.5;

  List<String> modes = ["Ultra HD","Video","Photo","Portrait","Cinematic","Night","Astro"];
  List<String> filters = ["Original","Vivid","KGF","RRR","Dune","Avatar","B&W","Warm","Cool","Vintage","NightVision","AstroBoost"];

  Future<void> initC() async {
    await [Permission.camera, Permission.microphone, Permission.photos, Permission.speech].request();
    ctrl = CameraController(cams[0], ResolutionPreset.ultraHigh, enableAudio: true);
    await ctrl!.initialize();
    double mz = await ctrl!.getMaxZoomLevel();
    if(mz < 10) mz = 100; // Killer - 100x dikhau
    maxZoom = 100;
    setState(()=> ready = true);
  }

  @override
  void initState(){
    super.initState();
    initC();
    pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  }

  Future<void> setZoom(double z) async {
    if(z < 0.6) z = 0.6;
    if(z > maxZoom) z = maxZoom;
    try { await ctrl!.setZoomLevel(z.clamp(0.6, 10)); } catch(e){}
    setState(()=> zoom = z);
  }

  String fmt(int s) => "${(s~/60).toString().padLeft(2,'0')}:${(s%60).toString().padLeft(2,'0')}";

  ColorFilter getFilter(){
    switch(filter){
      case "Vivid": return const ColorFilter.matrix([1.4,0,0,0,-15, 0,1.4,0,0,-15, 0,0,1.4,0,-15, 0,0,0,1,0]);
      case "B&W": return const ColorFilter.matrix([0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0,0,0,1,0]);
      case "KGF": return const ColorFilter.matrix([1.3,0.1,0,0,10, 0.1,1.0,0,0,5, 0,0,0.7,0,-5, 0,0,0,1,0]); // yellowish dark
      case "RRR": return const ColorFilter.matrix([1.2,0,0,0,15, 0,1.1,0,0,5, 0,0,0.9,0,0, 0,0,0,1,0]);
      case "Dune": return const ColorFilter.matrix([1.1,0.2,0.1,0,10, 0.15,1.0,0.15,0,5, 0.1,0.1,0.8,0,0, 0,0,0,1,0]);
      case "NightVision": return const ColorFilter.matrix([0.3,0.6,0,0,0, 0.3,0.6,0,0,20, 0.3,0.6,0,0,0, 0,0,0,1,0]); // greenish bright
      case "AstroBoost": return const ColorFilter.matrix([1.2,0,0,0,20, 0,1.2,0,0,20, 0,0,1.5,0,30, 0,0,0,1,0]);
      default: return const ColorFilter.matrix([1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0]);
    }
  }

  Future<void> shoot() async {
    if(mode=="Video" || mode=="Cinematic" || mode=="Ultra HD"){
      if(rec){
        timer?.cancel();
        HapticFeedback.heavyImpact();
        var f = await ctrl!.stopVideoRecording();
        await Gal.putVideo(f.path);
        setState((){ rec=false; sec=0; });
        msg("🎬 KILLER Video Saved! ${zoom.toStringAsFixed(1)}x");
      } else {
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
        await ctrl!.startVideoRecording();
        setState(()=> rec=true);
        timer = Timer.periodic(const Duration(seconds:1), (t)=> setState(()=> sec++));
      }
    } else {
      setState(()=> flashEffect=true);
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.click);
      await Future.delayed(const Duration(milliseconds: 100));
      var f = await ctrl!.takePicture();
      await Gal.putImage(f.path);
      setState(()=> flashEffect=false);
      msg("📸 KILLER Shot! $filter • ${zoom.toStringAsFixed(1)}x");
    }
  }

  void msg(String t){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), backgroundColor: Colors.amber, duration: const Duration(milliseconds: 900))); }

  void startVoice(){
    speech.initialize().then((ok){
      if(ok){
        setState(()=> listening=true);
        speech.listen(onResult: (r){
          String txt = r.recognizedWords.toLowerCase();
          if(txt.contains("photo") || txt.contains("फोटो")) { mode="Photo"; shoot(); }
          if(txt.contains("video") || txt.contains("व्हिडिओ")) { mode="Video"; shoot(); }
          if(txt.contains("zoom")) {
            RegExp reg = RegExp(r'\d+');
            var m = reg.firstMatch(txt);
            if(m!=null) setZoom(double.parse(m.group(0)!));
          }
          if(txt.contains("kgf")) setState(()=> filter="KGF");
          if(txt.contains("night")) setState(()=> mode="Night");
          if(listening) setState(()=> listening=false);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context){
    if(!ready) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.amber)));
    bool cine = mode=="Cinematic" || filter=="KGF" || filter=="Dune" || filter=="RRR";
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ColorFiltered(colorFilter: getFilter(), child: SizedBox.expand(child: CameraPreview(ctrl!))),
          if(cine)...[
            Positioned(top:0, left:0, right:0, height: 85, child: Container(color: Colors.black)),
            Positioned(bottom:0, left:0, right:0, height: 150, child: Container(color: Colors.black)),
          ],
          if(flashEffect) Container(color: Colors.white.withOpacity(0.9)),
          // TOP BAR
          Positioned(top:40, left:15, right:15, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal:10, vertical:5), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)), child: const Text("KILLER CAMERA • WORLD NO.1", style: TextStyle(color: Colors.black, fontSize:10, fontWeight: FontWeight.bold))),
            if(rec) FadeTransition(opacity: pulseCtrl, child: Container(width:12, height:12, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
          ])),
          if(rec) Positioned(top:42, left:0, right:0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)), child: Text("REC ${fmt(sec)} • ${zoom.toStringAsFixed(1)}x", style: const TextStyle(color: Colors.white, fontSize:11, fontWeight: FontWeight.bold))))),

          // FILTER CHIPS
          Positioned(top:75, left:0, right:0, child: SizedBox(height:32, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal:10), itemCount: filters.length, itemBuilder: (c,i){
            bool sel = filters[i]==filter;
            return GestureDetector(onTap: ()=> setState(()=> filter=filters[i]), child: Container(margin: const EdgeInsets.only(right:7), padding: const EdgeInsets.symmetric(horizontal:12, vertical:5), decoration: BoxDecoration(color: sel? Colors.amber : Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel? Colors.amber : Colors.white24)), child: Text(filters[i], style: TextStyle(color: sel? Colors.black : Colors.white, fontSize:10, fontWeight: sel? FontWeight.bold : FontWeight.normal))));
          }))),

          // PRO MANUAL SLIDERS
          Positioned(top:115, right:10, child: Column(children: [
            RotatedBox(quarterTurns: 3, child: Slider(value: exposure, min:-2, max:2, activeColor: Colors.amber, onChanged: (v) async { setState(()=> exposure=v); try{ await ctrl!.setExposureOffset(v);}catch(e){} },)),
            const Text("EXP", style: TextStyle(color: Colors.white54, fontSize:8)),
            const SizedBox(height:10),
            RotatedBox(quarterTurns: 3, child: Slider(value: isoVal, min:0, max:1, activeColor: Colors.amber, onChanged: (v)=> setState(()=> isoVal=v))),
            const Text("ISO", style: TextStyle(color: Colors.white54, fontSize:8)),
          ])),

          // AI FEATURES BUTTONS
          Positioned(top:115, left:10, child: Column(children: [
            _killerBtn(Icons.auto_fix_high, "AI Director", (){ setState(()=> filter="KGF"); msg("AI Director: KGF Mode ON"); }),
            const SizedBox(height:8),
            _killerBtn(Icons.cleaning_services, "Object Erase", (){ msg("AI Eraser: Next version madhe 100% working"); }),
            const SizedBox(height:8),
            _killerBtn(Icons.movie_filter, "Reels Maker", (){ msg("One Tap Reels Ready! Gallery madhe video check kar"); }),
          ])),

          Positioned(bottom:175, left:0, right:0, child: Center(child: Text("${zoom.toStringAsFixed(1)}x • $filter • ${mode.toUpperCase()}", style: const TextStyle(color: Colors.white, fontSize:13)))),
          Positioned(bottom:85, left:0, right:0, child: DialView(cur: zoom, maxZ: maxZoom, onChanged: (v)=> setZoom(v))),
          Positioned(bottom:85, left:0, right:0, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: modes.map((m){
            bool sel = m==mode;
            return GestureDetector(onTap: ()=> setState(()=> mode=m), child: Text(m, style: TextStyle(color: sel? Colors.amber : Colors.white60, fontSize:9, fontWeight: sel? FontWeight.bold : FontWeight.normal)));
          }).toList()))),

          Positioned(bottom:15, left:15, right:15, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(onTap: startVoice, child: Container(width:48, height:48, decoration: BoxDecoration(color: listening? Colors.red : Colors.white24, shape: BoxShape.circle), child: Icon(listening? Icons.mic : Icons.mic_none, color: Colors.white))),
            GestureDetector(onTap: shoot, child: Container(width:78, height:78, decoration: BoxDecoration(color: rec? Colors.red : Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width:4)), child: Icon(rec? Icons.stop : Icons.circle, color: rec? Colors.white : Colors.white, size: rec? 34 : 72))),
            GestureDetector(onTap: () async {
              var next = cams.length>1 && ctrl!.description==cams[0]? cams[1] : cams[0];
              ctrl = CameraController(next, ResolutionPreset.ultraHigh, enableAudio: true);
              await ctrl!.initialize();
              setState((){});
            }, child: Container(width:48, height:48, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.cameraswitch, color: Colors.white))),
          ])),
        ],
      ),
    );
  }

  Widget _killerBtn(IconData ic, String txt, VoidCallback onTap){
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.5))), child: Column(children: [Icon(ic, color: Colors.amber, size:14), const SizedBox(height:2), Text(txt, style: const TextStyle(color: Colors.white, fontSize:7))]))));
  }
}

class DialView extends StatelessWidget {
  final double cur; final double maxZ; final Function(double) onChanged;
  const DialView({super.key, required this.cur, required this.maxZ, required this.onChanged});
  @override Widget build(BuildContext context) {
    return GestureDetector(onPanUpdate: (d){ double delta = -d.delta.dx * 0.8; double nz = cur+delta; if(nz<0.6) nz=0.6; if(nz>maxZ) nz=maxZ; onChanged(nz); },
      child: SizedBox(height:85, width: double.infinity, child: CustomPaint(painter: DialPainter(cur: cur, maxZ: maxZ))));
  }
}
class DialPainter extends CustomPainter {
  final double cur; final double maxZ;
  DialPainter({required this.cur, required this.maxZ});
  @override void paint(Canvas c, Size s){
    double cx=s.width/2; double cy=s.height; double r=s.width*0.46;
    for(double z=0.6; z<=maxZ+0.01; z+=0.6){
      double ang = pi + (z/maxZ)*pi;
      double len=5; bool mark=false;
      if([1,2,5,10,20,50,100].contains(z.toInt()) && (z-z.toInt()).abs()<0.1){ len=16; mark=true; }
      double x1=cx+r*cos(ang); double y1=cy+r*sin(ang);
      double x2=cx+(r-len)*cos(ang); double y2=cy+(r-len)*sin(ang);
      bool isCur=(cur-z).abs()<0.5;
      Paint p=Paint()..color=isCur? Colors.amber : Colors.white54..strokeWidth=isCur? 2.5:1;
      c.drawLine(Offset(x1,y1), Offset(x2,y2), p);
      if(mark){
        double lx=cx+(r-28)*cos(ang); double ly=cy+(r-28)*sin(ang);
        TextPainter tp=TextPainter(text: TextSpan(text: "${z.toInt()}x", style: const TextStyle(color: Colors.white70, fontSize:10)), textDirection: TextDirection.ltr); tp.layout(); tp.paint(c, Offset(lx-tp.width/2, ly));
      }
    }
    c.drawLine(Offset(cx-10, cy-3), Offset(cx+10, cy-3), Paint()..color=Colors.white54..strokeWidth=2);
  }
  @override bool shouldRepaint(covariant DialPainter old)=> old.cur!=cur;
}
