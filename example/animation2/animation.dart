import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/chronosutil.dart';
import 'dart:html' as HTML;
import 'dart:async';
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart' as VM;

String meshFile = "../asset/knight/knight.js";

String skinningVertexShader = """

mat4 adjustMatrix() {
    return aBoneWeight.x * uBoneMatrices[int(aBoneIndex.x)] +
           aBoneWeight.y * uBoneMatrices[int(aBoneIndex.y)] +
           aBoneWeight.z * uBoneMatrices[int(aBoneIndex.z)] +
           aBoneWeight.w * uBoneMatrices[int(aBoneIndex.w)];
}

void main() {
   mat4 skinMat = uModelMatrix * adjustMatrix();
   vec4 pos = skinMat * vec4(aVertexPosition, 1.0);
   // vVertexPosition = pos.xyz;
   // This is not quite accurate
   //${vNormal} = normalize(mat3(skinMat) * aNormal);
   gl_Position = uPerspectiveViewMatrix * pos;


   ${vColor} = vec3( sin(${aVertexPosition}.x)/2.0+0.5,
                      cos(${aVertexPosition}.y)/2.0+0.5,
                      sin(${aVertexPosition}.z)/2.0+0.5);
   //vTextureCoordinates = aTextureCoordinates;
}

""";

String skinningFragmentShader = """
void main() {
  gl_FragColor.rgb = ${vColor};
}
""";

List<ShaderObject> createAnimationShader() {
  return [
    new ShaderObject("AnimationV")
      ..AddAttributeVar(aVertexPosition)
      //..AddAttributeVar(aNormal)
      //..AddAttributeVar(aTextureCoordinates)
      ..AddAttributeVar(aBoneIndex)
      ..AddAttributeVar(aBoneWeight)
      ..AddVaryingVar(vVertexPosition)
      //..AddVaryingVar(vTextureCoordinates)
      //..AddVaryingVar(vNormal)
      ..AddVaryingVar(vColor)
      ..AddUniformVar(uPerspectiveViewMatrix)
      ..AddUniformVar(uModelMatrix)
      ..AddUniformVar(uBoneMatrices)
      ..SetBody([skinningVertexShader]),
    new ShaderObject("AnimationV")
      ..AddVaryingVar(vColor)
      //..AddVaryingVar(vTextureCoordinates)
      //..AddUniformVar(uTextureSampler)
      ..SetBody([skinningFragmentShader]),
  ];
}

// A very simple shaders - many other are available out of the box.
List<ShaderObject> demoShader() {
  return [
    new ShaderObject("demoVertexShader")
      ..AddAttributeVar(aVertexPosition)
      ..AddVaryingVar(vColor)
      ..AddUniformVar(uPerspectiveViewMatrix)
      ..AddUniformVar(uModelMatrix)
      ..SetBody([
        """
        void main(void) {
          gl_Position = ${uPerspectiveViewMatrix} *
                        ${uModelMatrix} *
                        vec4(${aVertexPosition}, 1.0);
          ${vColor}.r = sin(${aVertexPosition}.x)/2.0+0.5;
          ${vColor}.g = cos(${aVertexPosition}.y)/2.0+0.5;
          ${vColor}.b = sin(${aVertexPosition}.z)/2.0+0.5;
        }
        """
      ]),
    new ShaderObject("demoFragmentShader")
      ..AddVaryingVar(vColor)
      ..SetBodyWithMain(["gl_FragColor.rgb = ${vColor};"])
  ];
}




VM.Vector3 MakeVector3(List<num> lst) {
  return new VM.Vector3(
      lst[0].toDouble(), lst[1].toDouble(), lst[2].toDouble());
}

VM.Vector3 MakeTransVector3(List<num> lst) {
  if (lst == null) return new VM.Vector3.zero();
  return MakeVector3(lst);
}

VM.Vector3 MakeScaleVector3(List<num> lst) {
  if (lst == null) return new VM.Vector3(1.0, 1.0, 1.0);
  return MakeVector3(lst);
}

VM.Quaternion MakeQuaternion(List<num> lst) {
  if (lst == null) return new VM.Quaternion.identity();

  return new VM.Quaternion(lst[0].toDouble(), lst[1].toDouble(),
      lst[2].toDouble(), lst[3].toDouble());
}

List<Bone> ReadBones(Map json) {
  final Map metadata = json["metadata"];
  final List<Map> Bones = json["bones"];
  List<Bone> bones = new List<Bone>(metadata["bones"]);
  for (int i = 0; i < Bones.length; i++) {
    Map m = Bones[i];
    String name = m["name"];
    int parent = m["parent"];
    final VM.Vector3 s = MakeScaleVector3(m["scl"]);
    final VM.Vector3 t = MakeTransVector3(m["pos"]);
    final VM.Quaternion r = MakeQuaternion(m["qrot"]);
    VM.Matrix4 mat = new VM.Matrix4.zero()
      ..setFromTranslationRotationScale(t, r, s);
    if (i != 0 && parent < 0) {
      print("found unusal root node ${i} ${parent}");
    }
    bones[i] = new Bone(name, i, parent, new VM.Matrix4.identity(), mat);
  }
  print("bones: ${bones.length}");
  return bones;
}

SkeletonAnimation ReadAnimation(Map json) {
  final Map animation = json["animation"];
  final List<Map> hierarchy = animation["hierarchy"];
  SkeletonAnimation s = new SkeletonAnimation(
      animation["name"], animation["length"], hierarchy.length);
  assert(hierarchy.length == json["bones"].length);
  for (int i = 0; i < hierarchy.length; ++i) {
    List<double> pTimes = [];
    List<VM.Vector3> pValues = [];
    List<double> rTimes = [];
    List<VM.Quaternion> rValues = [];
    List<double> sTimes = [];
    List<VM.Vector3> sValues = [];
    for (Map m in hierarchy[i]["keys"]) {
      double t = m["time"].toDouble();

      if (m.containsKey("pos")) {
        pTimes.add(t);
        pValues.add(MakeTransVector3(m["pos"]));
      }

      if (m.containsKey("scale")) {
        sTimes.add(t);
        sValues.add(MakeScaleVector3(m["scl"]));
      }


      if (m.containsKey("rot")) {
        rTimes.add(t);
        rValues.add(MakeQuaternion(m["rot"]));
      }
    }
    BoneAnimation ba =
        new BoneAnimation(i, pTimes, pValues, rTimes, rValues, sTimes, sValues);
    s.InsertBone(ba);
  }
  print("anim-bones: ${s.animList.length}");
  return s;
}

void main() {
  StatsFps fps =
      new StatsFps(HTML.document.getElementById("stats"), "blue", "gray");
  HTML.CanvasElement canvas = HTML.document.querySelector('#webgl-canvas');
  ChronosGL chronosGL = new ChronosGL(canvas);
  OrbitCamera orbit = new OrbitCamera(20.0);
  Perspective perspective = new Perspective(orbit);

  RenderPhase phase = new RenderPhase("main", chronosGL.gl);
  //RenderProgram prg = phase.createProgram(createDemoShader());
  RenderProgram prg = phase.createProgram(createAnimationShader());

  final RenderProgram prgWire = phase.createProgram(createSolidColorShader());
  final Material matWire = new Material("wire")
    ..SetUniform(uColor, new VM.Vector3(1.0, 1.0, 0.0));

  Material mat = new Material("mat");
  VM.Matrix4 identity = new VM.Matrix4.identity();
  Float32List matrices = new Float32List(16 * 128);
  for (int i = 0; i < matrices.length; ++i) {
    matrices[i] = identity[i % 16];
  }
  mat.SetUniform(uBoneMatrices, matrices);

  void resolutionChange(HTML.Event ev) {
    int w = canvas.clientWidth;
    int h = canvas.clientHeight;
    canvas.width = w;
    canvas.height = h;
    print("size change $w $h");
    perspective.AdjustAspect(w, h);
    phase.viewPortW = w;
    phase.viewPortH = h;
  }

  resolutionChange(null);
  HTML.window.onResize.listen(resolutionChange);

  List<Bone> skeleton;
  SkeletonAnimation anim;
  PosedSkeleton posedSkeleton;
  VM.Matrix4 globalOffsetTransform = new VM.Matrix4.identity();
  MeshData mdWire;

  double _lastTimeMs = 0.0;

  void animate(timeMs) {
    timeMs = 0.0 + timeMs;
    double elapsed = timeMs - _lastTimeMs;
    _lastTimeMs = timeMs;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    fps.UpdateFrameCount(timeMs);
    phase.draw([perspective]);
    HTML.window.animationFrame.then(animate);

    final double relTime = (timeMs / 1000.0) % anim.duration;
    //print("${relTime}");
    PoseSkeleton(skeleton, globalOffsetTransform, anim, posedSkeleton, relTime);
    FlattenMatrix4List(posedSkeleton.skinningTransforms, matrices);
    List<VM.Vector3> bonePos =
        BonePosFromPosedSkeleton(skeleton, posedSkeleton);
    mdWire.ChangeVertices(FlattenVector3List(bonePos));
  }

  List<Future<dynamic>> futures = [
    LoadJson(meshFile),
  ];

  Future.wait(futures).then((List list) {
    // Setup Mesh
    List<GeometryBuilder> gb = ReadThreeJsMeshes(list[0]);
    skeleton = ReadBones(list[0]);
    anim = ReadAnimation(list[0]);
    posedSkeleton = new PosedSkeleton(skeleton.length);
    {
      MeshData md = GeometryBuilderToMeshData(meshFile, chronosGL.gl, gb[0]);
      Node mesh = new Node(md.name, md, mat)..rotX(-3.14 / 4);
      Node n = new Node.Container("wrapper", mesh);
      n.lookAt(new VM.Vector3(100.0, 0.0, 0.0));
      //prg.add(n);
    }

    {
      PoseSkeleton(skeleton, globalOffsetTransform, anim, posedSkeleton, 0.0);
      mdWire = LineEndPointsToMeshData("wire", chronosGL.gl,
          BonePosFromPosedSkeleton(skeleton, posedSkeleton));
      Node mesh = new Node(mdWire.name, mdWire, matWire)..rotX(3.14 / 4);
      Node n = new Node.Container("wrapper", mesh);
      n.lookAt(new VM.Vector3(100.0, 0.0, 0.0));
      prgWire.add(n);
    }

    // Start
    animate(0.0);
  });
}