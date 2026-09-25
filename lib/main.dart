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
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: KillerCameraTop()));
}

class KillerCameraTop extends StatefulWidget {
  const KillerCameraTop({super.key});
  @override State<KillerCameraTop> createState() => _KillerCameraTopState();
}

class _KillerCameraTopState extends State<KillerCameraTop> with SingleTickerProviderStateMixin {
  CameraController? ctrl; bool ready=false; bool rec=false; double zoom=1.0; double maxZoom=100;
  String mode="Photo"; String filter="Original"; int sec=0; Timer? timer; bool flash=false;
  late AnimationController pulse; stt.SpeechToText st=stt.SpeechToText(); bool listening=false;
  double exp=0;

  List<String> modes=["Ultra HD","Video","Photo","Portrait","Cinematic","Night","Astro"];
  List<String> filters=["Original","KGF","RRR","Dune","Vivid","B&W","NightVision","AstroBoost","Cinematic"];

  @override void initState(){ super.initState(); init(); pulse=AnimationController(vsync:this,duration:const Duration(milliseconds:500))..repeat(reverse:true); }
  Future<void> init() async {
    await [Permission.camera,Permission.microphone,Permission.photos,Permission.speech].request();
    ctrl=CameraController(cams[0], ResolutionPreset.ultraHigh, enableAudio: true);
    await ctrl!.initialize(); maxZoom=100; setState(()=>ready=true);
  }
  Future<void> setZoom(double z) async {
    if(z<0.6) z=0.6; if(z>100) z=100;
    try{ await ctrl!.setZoomLevel(z.clamp(0.6, 10)); }catch(e){}
    setState(()=>zoom=z);
  }
  ColorFilter getF(){
    switch(filter){
      case "Vivid": return const ColorFilter.matrix([1.4,0,0,0,-10, 0,1.4,0,0,-10, 0,0,1.4,0,-10, 0,0,0,1,0]);
      case "B&W": return const ColorFilter.matrix([0.21,0.72,0.07,0,0, 0.21,0.72,0.07,0,0, 0.21,0.72,0.07,0,0, 0,0,0,1,0]);
      case "KGF": return const ColorFilter.matrix([1.4,0.2,0,0,10, 0.2,1.1,0,0,5, 0,0,0.6,0,-5, 0,0,0,1,0]);
      case "RRR": return const ColorFilter.matrix([1.3,0,0,0,15, 0,1.2,0,0,5, 0,0,0.9,0,0, 0,0,0,1,0]);
      case "NightVision": return const ColorFilter.matrix([0.2,0.8,0,0,0, 0.2,0.8,0,0,15, 0.2,0.8,0,0,0, 0,0,0,1,0]);
      case "AstroBoost": return const ColorFilter.matrix([1.2,0,0,0,25, 0,1.2,0,0,25, 0,0,1.6,0,40, 0,0,0,1,0]);
      default: return const ColorFilter.matrix([1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0]);
    }
  }
  Future<void> shoot() async {
    if(mode=="Video"||mode=="Ultra HD"||mode=="Cinematic"){
      if(rec){ timer?.cancel(); HapticFeedback.heavyImpact(); var f=await ctrl!.stopVideoRecording(); await Gal.putVideo(f.path); setState(()=>rec=false); }
      else{ HapticFeedback.mediumImpact(); SystemSound.play(SystemSoundType.click); await ctrl!.startVideoRecording(); setState(()=>rec=true); timer=Timer.periodic(const Duration(seconds:1),(t)=>setState(()=>sec++)); }
    } else {
      setState(()=>flash=true); HapticFeedback.heavyImpact(); SystemSound.play(SystemSoundType.click);
      await Future.delayed(const Duration(milliseconds:120));
      var f=await ctrl!.takePicture(); await Gal.putImage(f.path);
      setState(()=>flash=false);
    }
  }
  void voice(){
    st.initialize().then((ok){ if(ok){ setState(()=>listening=true); st.listen(onResult:(r){ String t=r.recognizedWords.toLowerCase(); if(t.contains("photo")||t.contains("फोटो")) shoot(); if(t.contains("zoom")){ var m=RegExp(r'\d+').firstMatch(t); if(m!=null) setZoom(double.parse(m.group(0)!)); } setState(()=>listening=false); }); }});
  }

  @override Widget build(BuildContext context){
    if(!ready) return const Scaffold(backgroundColor:Colors.black,body:Center(child:CircularProgressIndicator(color:Colors.amber)));
    bool cine=mode=="Cinematic"||filter=="KGF";
    return Scaffold(backgroundColor:Colors.black, body:Stack(children:[
      ColorFiltered(colorFilter:getF(), child:SizedBox.expand(child:CameraPreview(ctrl!))),
      if(cine)...[Positioned(top:0,left:0,right:0,height:90,child:Container(color:Colors.black)), Positioned(bottom:0,left:0,right:0,height:155,child:Container(color:Colors.black))],
      if(flash) Container(color:Colors.white.withOpacity(0.92)),
      Positioned(top:40,left:0,right:0,child:Center(child:Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:6),decoration:BoxDecoration(color:Colors.amber,borderRadius:BorderRadius.circular(20)),child:Text("KILLER CAMERA TOP • ${zoom.toStringAsFixed(1)}x • $filter",style:const TextStyle(color:Colors.black,fontWeight:FontWeight.bold,fontSize:11))))),
      if(rec) Positioned(top:75,left:0,right:0,child:Center(child:FadeTransition(opacity:pulse,child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),decoration:BoxDecoration(color:Colors.red,borderRadius:BorderRadius.circular(20)),child:Text("● REC ${sec~/60}:${(sec%60).toString().padLeft(2,'0')}",style:const TextStyle(color:Colors.white,fontSize:11)))))),
      Positioned(top:105,left:0,right:0,child:SizedBox(height:32,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:12),children:filters.map((f){bool s=f==filter; return GestureDetector(onTap:()=>setState(()=>filter=f),child:Container(margin:const EdgeInsets.only(right:8),padding:const EdgeInsets.symmetric(horizontal:14,vertical:6),decoration:BoxDecoration(color:s?Colors.amber:Colors.black54,borderRadius:BorderRadius.circular(20),border:Border.all(color:s?Colors.amber:Colors.white24)),child:Text(f,style:TextStyle(color:s?Colors.black:Colors.white,fontSize:10,fontWeight:s?FontWeight.bold:FontWeight.normal))));}.toList()))),
      Positioned(bottom:165,left:0,right:0,child:Center(child:Text("${zoom.toStringAsFixed(1)}x",style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:16)))),
      Positioned(bottom:75,left:0,right:0,child:SizedBox(height:90,child:GestureDetector(onPanUpdate:(d){ double nz=zoom - d.delta.dx*0.6; if(nz<0.6) nz=0.6; if(nz>100) nz=100; setZoom(nz); }, child:CustomPaint(painter:_Dial(zoom,maxZoom))))),
      Positioned(bottom:80,left:0,right:0,child:Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:modes.map((m){bool s=m==mode; return GestureDetector(onTap:()=>setState(()=>mode=m),child:Text(m,style:TextStyle(color:s?Colors.amber:Colors.white54,fontSize:10,fontWeight:s?FontWeight.bold:FontWeight.normal)));}).toList())),
      Positioned(bottom:12,left:20,right:20,child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        GestureDetector(onTap:voice,child:Container(width:50,height:50,decoration:BoxDecoration(color:listening?Colors.red:Colors.white24,shape:BoxShape.circle),child:Icon(listening?Icons.mic:Icons.mic_none,color:Colors.white))),
        GestureDetector(onTap:shoot,child:Container(width:80,height:80,decoration:BoxDecoration(color:rec?Colors.red:Colors.white,shape:BoxShape.circle,border:Border.all(color:Colors.white,width:4)),child:Icon(rec?Icons.stop:Icons.circle,color:rec?Colors.white:Colors.white,size:rec?36:74))),
        GestureDetector(onTap:()async{ var n=cams.length>1&&ctrl!.description==cams[0]?cams[1]:cams[0]; ctrl=CameraController(n,ResolutionPreset.ultraHigh,enableAudio:true); await ctrl!.initialize(); setState((){}); },child:Container(width:50,height:50,decoration:const BoxDecoration(color:Colors.white24,shape:BoxShape.circle),child:const Icon(Icons.cameraswitch,color:Colors.white))),
      ])),
    ]));
  }
}
class _Dial extends CustomPainter {
  final double cur,max; _Dial(this.cur,this.max);
  @override void paint(Canvas c,Size s){ double cx=s.width/2,cy=s.height,r=s.width*0.48;
    for(double z=0.6;z<=max+0.01;z+=0.6){ double ang=pi+(z/max)*pi; double len=6; if([1,2,5,10,20,50,100].contains(z.round()) && (z-z.round()).abs()<0.1) len=18;
      double x1=cx+r*cos(ang),y1=cy+r*sin(ang),x2=cx+(r-len)*cos(ang),y2=cy+(r-len)*sin(ang);
      bool isCur=(cur-z).abs()<0.6; c.drawLine(Offset(x1,y1),Offset(x2,y2),Paint()..color=isCur?Colors.amber:Colors.white54..strokeWidth=isCur?2.5:1);
      if(len>6){ double lx=cx+(r-32)*cos(ang),ly=cy+(r-32)*sin(ang); TextPainter tp=TextPainter(text:TextSpan(text:"${z.toInt()}x",style:TextStyle(color:isCur?Colors.amber:Colors.white70,fontSize:11,fontWeight:isCur?FontWeight.bold:FontWeight.normal)),textDirection:TextDirection.ltr); tp.layout(); tp.paint(c,Offset(lx-tp.width/2,ly-6)); }
    } c.drawLine(Offset(cx-12,cy-2),Offset(cx+12,cy-2),Paint()..color=Colors.white..strokeWidth=2);
  }
  @override bool shouldRepaint(covariant _Dial o)=>o.cur!=cur;
}
