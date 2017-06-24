import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as VM;
import 'dart:html' as HTML;
import "dart:async";

String textureFile = "../gradient.jpg";

void main() {
  HTML.CanvasElement canvas = HTML.document.querySelector('#webgl-canvas');
  ChronosGL chronosGL = new ChronosGL(canvas, faceCulling: true);
  OrbitCamera orbit = new OrbitCamera(165.0, 0.0, 0.0, canvas);
  Perspective perspective = new Perspective(orbit, 0.1, 1000.0);
  RenderPhase phase = new RenderPhase("main", chronosGL);
  RenderProgram programBasic = phase.createProgram(createTexturedShader());

  RenderProgram perlinNoise =
      phase.createProgram(createPerlinNoiseColorShader(false));

  Material mat = new Material("torus")
    ..SetUniform(uColor, new VM.Vector3.zero());
  Node m1 = new Node("torus1", ShapeTorusKnot(programBasic), mat)
    ..setPos(-50.0, 0.0, 0.0);
  programBasic.add(m1);

  Material matDummy = new Material("mat");
  Node m2 = new Node("torus2", ShapeTorusKnot(perlinNoise), matDummy)
    ..setPos(50.0, 0.0, 0.0);
  perlinNoise.add(m2);

  RenderProgram programSprites =
      phase.createProgram(createPointSpritesShader());
  programSprites.add(Utils.MakeParticles(programSprites, 2000));

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

  double _lastTimeMs = 0.0;
  void animate(num timeMs) {
    double elapsed = timeMs - _lastTimeMs;
    _lastTimeMs = timeMs;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    matDummy.ForceUniform(uTime, timeMs / 1000.0);
    phase.draw([perspective]);
    HTML.window.animationFrame.then(animate);
  }

  List<Future<dynamic>> futures = [
    LoadImage(textureFile),
  ];

  Future.wait(futures).then((List list) {
    Texture tex = new ImageTexture(chronosGL, textureFile, list[0]);
    mat..SetUniform(uTexture, tex);
    animate(0.0);
  });
}
