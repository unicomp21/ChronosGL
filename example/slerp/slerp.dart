import 'dart:html' as HTML;
import 'dart:async';

import 'package:chronosgl/chronosgl.dart';
import 'dart:math' as Math;
import 'package:vector_math/vector_math.dart' as VM;

Scene MakeStarScene(ChronosGL cgl, UniformGroup perspective, int num) {
  Scene scene = Scene(
      "stars",
      RenderProgram(
          "stars", cgl, pointSpritesVertexShader, pointSpritesFragmentShader),
      [perspective]);
  scene.add(Utils.MakeParticles(scene.program, num));
  return scene;
}

VM.Quaternion slerp(VM.Quaternion a, VM.Quaternion b, double t) {
  double ax = a[0], ay = a[1], az = a[2], aw = a[3];
  double bx = b[0], by = b[1], bz = b[2], bw = b[3];
  double omega, cosom, sinom, scale0, scale1;

  // calc cosine
  cosom = ax * bx + ay * by + az * bz + aw * bw;
  // adjust signs (if necessary)
  if (cosom < 0.0) {
    cosom = -cosom;
    bx = -bx;
    by = -by;
    bz = -bz;
    bw = -bw;
  }
  // calculate coefficients
  if ((1.0 - cosom) > 0.000001) {
    // standard case (slerp)
    omega = Math.acos(cosom);
    sinom = Math.sin(omega);
    scale0 = Math.sin((1.0 - t) * omega) / sinom;
    scale1 = Math.sin(t * omega) / sinom;
  } else {
    // "from" and "to" quaternions are very close
    //  ... so we can do a linear interpolation
    scale0 = 1.0 - t;
    scale1 = t;
  }
  return VM.Quaternion(scale0 * ax + scale1 * bx, scale0 * ay + scale1 * by,
      scale0 * az + scale1 * bz, scale0 * aw + scale1 * bw);
}

const String modelFile = "../ct_logo.obj";

void main() {
  HTML.CanvasElement canvas = HTML.document.querySelector('#webgl-canvas');
  ChronosGL cgl = ChronosGL(canvas);
  OrbitCamera orbit = OrbitCamera(15.0, -45.0, 0.3, canvas);
  Perspective perspective = Perspective(orbit, 1.0, 1000.0);
  final RenderPhaseResizeAware phase =
      RenderPhaseResizeAware("main", cgl, canvas, perspective);

  Scene scene = Scene(
      "demo",
      RenderProgram("demo", cgl, demoVertexShader, demoFragmentShader),
      [perspective]);
  phase.add(scene);

  phase.add(MakeStarScene(cgl, perspective, 2000));

  Material mat = Material("mat");
  Math.Random rng = Math.Random();

  List<Future<Object>> futures = [
    LoadRaw(modelFile),
  ];

  Future.wait(futures).then((List list) {
    // Setup Mesh
    GeometryBuilder ctLogo = ImportGeometryFromWavefront(list[0]);
    MeshData md = GeometryBuilderToMeshData("", scene.program, ctLogo);
    Node mesh = Node(md.name, md, mat)
      ..rotX(3.14 / 2)
      ..rotZ(3.14);
    Node node = Node.Container("wrapper", mesh);
    //n.invert = true;
    node.lookAt(VM.Vector3(100.0, 0.0, -100.0));
    //n.matrix.scale(0.02);

    VM.Vector3 axis = VM.Vector3(0.0, 0.0, 1.0);
    VM.Quaternion start = VM.Quaternion.identity();
    start.setFromRotation(node.transform.getRotation());
    VM.Quaternion end = VM.Quaternion.identity();
    end.setAxisAngle(axis, 3.14);
    double time = 0.0;

    void animateNode(double elapsedMs) {
      if (time < 1.0) {
        VM.Quaternion work = slerp(start, end, time += 0.2 * elapsedMs / 1000);
        VM.Matrix3 rm = work.asRotationMatrix();
        node.transform.setRotation(rm);
        return;
      } else {
        print("new rotation");
        time = 0.0;
        double angle;
        if (rng.nextBool()) {
          axis..setValues(rng.nextDouble(), rng.nextDouble(), rng.nextDouble());
          axis.normalize();
          angle = 2 * Math.pi * rng.nextDouble();
        } else {
          // TODO(rhulha): the original value was all zero which caused the animation to stop.
          axis.setValues(1.0, 0.0, 0.0);
          angle = 0.0;
        }
        print("new rotation axis: " + axis.toString());
        start.setFromRotation(node.transform.getRotation());
        end.setAxisAngle(axis, angle);
      }
    }

    scene.add(node);

    double _lastTimeMs = 0.0;
    void animate(num timeMs) {
      double elapsed = timeMs - _lastTimeMs;
      _lastTimeMs = timeMs + 0.0;
      orbit.azimuth += 0.001;
      orbit.animate(elapsed);
      animateNode(elapsed);

      phase.Draw();
      HTML.window.animationFrame.then(animate);
    }

    animate(0.0);
  });
}
