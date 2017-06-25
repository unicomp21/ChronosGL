library core;

// This library does not depend on "dart:html"
// It would be nice if we could also break the dependency on dart:web_gl
// for easier testing.
import 'dart:typed_data';
import 'dart:web_gl' as WEBGL;  // only chronosgl.dart uses WEBGL

import 'package:vector_math/vector_math.dart' as VM;

import "../base/lib.dart";

/// # Layer: Core (uses Base Layer, dart:web_gl)
/// The **core layer** adds abstractions to the *base layer**
/// which require the use of  **dart:web_gl**.
/// Code using the **core layer** can currently not be unit tested
/// but requires more elaborate browser tests.

part "render_program.dart";
part "mesh_data.dart";
part "textures.dart";
part "material.dart";
part "node.dart";
part "framebuffer.dart";
part "chronosgl.dart";
part "constants.dart";