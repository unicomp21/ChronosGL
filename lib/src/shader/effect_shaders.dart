part of chronosshader;

ShaderObject _effectVertexShader = new ShaderObject("copyV")
  ..AddAttributeVar(aVertexPosition)
  ..AddAttributeVar(aTextureCoordinates)
  ..AddVaryingVar(vTextureCoordinates)
  ..SetBodyWithMain(
      [NullVertexBody, "${vTextureCoordinates} = ${aTextureCoordinates};"]);

List<ShaderObject> createCopyShader() {
  return [
    _effectVertexShader,
    new ShaderObject("copyF")
      ..AddVaryingVar(vTextureCoordinates)
      ..AddUniformVar(uTexture)
      ..SetBodyWithMain(
          ["gl_FragColor = texture2D(${uTexture}, ${vTextureCoordinates});"])
  ];
}

String _libFragment = """
vec3 RGBtoHSV(vec3 rgb) {
   float r = rgb.r;
   float g = rgb.g;
   float b = rgb.b;


   float minv = min(min(r, g), b);
   float maxv = max(max(r, g), b);
   float delta = maxv - minv;

   vec3 res;
   res.z = maxv;            // v
   if( maxv == 0.0 ) {
      // r = g = b = 0      // s = 0, v is undefined
      res.y = 0.0;
      res.x = -1.0;
      return res;
   }

   res.y = delta / maxv;      // s
   if (r == maxv) res.x = (g - b) / delta;  // btwn yellow & magenta
   else if (g == maxv) res.x = 2.0 + (b - r) / delta;   // btwn cyan & yellow
   else res.x = 4.0 + (r - g) / delta;   // btwn magenta & cyan

   res.x = res.x * 60.0;            // degrees
   if( res.x < 0.0 ) res.x = res.x + 360.0;

   return res;
}

vec3 HSVtoRGB(vec3 hsv) {
   float h = hsv.x / 60.0;  // sector 0 to 5
   float s = hsv.y;
   float v = hsv.z;

   if( s == 0.0 ) {
      // achromatic (grey)
      return vec3(v, v, v);
   }

   int i = int(floor( h ));
   float f = h - float(i);         // fractional part of h
   float p = v * ( 1.0 - s );
   float q = v * ( 1.0 - s * f );
   float t = v * ( 1.0 - s * ( 1.0 - f ) );

   if (i == 0) return vec3(v, t, p);
   else if (i == 1) return vec3(q, v , p);
   else if (i == 2) return vec3(p, v, t);
   else if (i == 3) return vec3(p, q, v);
   else if (i == 4) return vec3(t, p, v);
   return vec3(v, p, q);
}
""";

// Inspired by
// http://coding-experiments.blogspot.sg/2011/01/toon-pixel-shader.html
String _toonFragment = """

float nearestLevel(float col, int mode) {
   if (mode==0) return ceil(col / 80.0) * 80.0;
	 else if (mode==1) return ceil(col * 6.0) / 6.0;
	 else return ceil(col * 3.0) / 3.0;
}

// averaged pixel intensity from 3 color channels
float avg3(vec3 pix) {
 return (pix.r + pix.g + pix.b)/3.0;
}

vec3 get_pixel(vec2 coords, float dx, float dy) {
 return texture2D(${uTexture}, coords + vec2(dx, dy)).rgb;
}

// returns pixel color
float IsEdge(in vec2 coords) {
  float dxtex = 1.0 / ${uCanvasSize}.x ;
  float dytex = 1.0 / ${uCanvasSize}.y ;

  // read neighboring pixel intensities
  float pix0 = avg3(get_pixel(coords, -dxtex, -dytex));
  float pix1 = avg3(get_pixel(coords, -dxtex, 0.0));
  float pix2 = avg3(get_pixel(coords, -dxtex, dytex));
  float pix3 = avg3(get_pixel(coords, 0.0, -dytex));

  float pix5 = avg3(get_pixel(coords, 0.0, dytex));
  float pix6 = avg3(get_pixel(coords, dxtex, -dytex));
  float pix7 = avg3(get_pixel(coords, dxtex, 0.0));
  float pix8 = avg3(get_pixel(coords, dxtex, dytex));


  // average color differences around neighboring pixels
  float delta = (abs(pix1-pix7) + abs(pix5-pix3) +
                 abs(pix0-pix8) + abs(pix2-pix6)) * 0.25;
  return clamp(5.5*delta, 0.0, 1.0);
}

void main() {
    vec4 colorOrg = texture2D(${uTexture}, ${vTextureCoordinates});
    vec3 vHSV =  RGBtoHSV(colorOrg.rgb);
    vHSV.x = nearestLevel(vHSV.x, 0);
    vHSV.y = nearestLevel(vHSV.y, 1);
    vHSV.z = nearestLevel(vHSV.z, 2);
    float edg = IsEdge(${vTextureCoordinates});
    vec3 vRGB = (edg >= 0.3) ? vec3(0.0,0.0,0.0) : HSVtoRGB(vHSV);
    //vec3 vRGB = HSVtoRGB(vHSV);
    gl_FragColor = vec4(vRGB, 1.0);
}
""";

List<ShaderObject> createToonShader() {
  return [
    _effectVertexShader,
    new ShaderObject("ToonF")
      ..AddVaryingVar(vTextureCoordinates)
      ..AddUniformVar(uCanvasSize)
      ..AddUniformVar(uTexture)
      ..SetBody([_libFragment, _toonFragment])
  ];
}

// Inspired by glfx.js
// The edges of a hexagon centered at 0,0 with diameter 1.0 are:
// where is the height of an equilateral triangle with edge length 1.0
// H = sqrt(0.75)  = 0.866025404;
String _hexPixelateFragment = """

float S = 0.86602540378;

vec2 GetHexCenter(vec2 p) {
 vec2 a;
    if (p.x + p.y - floor(p.x) - floor(p.y) < 1.0) a = vec2(floor(p.x), floor(p.y));
    else a = vec2(ceil(p.x), ceil(p.y));
    vec2 b = vec2(ceil(p.x), floor(p.y));
    vec2 c = vec2(floor(p.x), ceil(p.y));

    vec3 P = vec3(p.x, p.y, 1.0 - p.x - p.y);
    vec3 A = vec3(a.x, a.y, 1.0 - a.x - a.y);
    vec3 B = vec3(b.x, b.y, 1.0 - b.x - b.y);
    vec3 C = vec3(c.x, c.y, 1.0 - c.x - c.y);

    float alen = length(P - A);
    float blen = length(P - B);
    float clen = length(P - C);

    if (alen < blen) {
        return (alen < clen) ? a : c;
    } else {
        return (blen < clen) ? b : c;
    }
}

vec2 ToPixelSpace(vec2 v) {
    vec2 p = (v * ${uCanvasSize} - ${uCenter2}) / ${uScale};
    float t = p.y / S;
    return vec2(p.x - 0.5 * t, t);
}

vec2 ToNormalizedSpace(vec2 v) {
   vec2 p = vec2(v.x + v.y * 0.5, v.y * S);
   return p * ${uScale} / ${uCanvasSize} + ${uCenter2} / ${uCanvasSize};
}

void main() {
    vec2 p = ToPixelSpace(${vTextureCoordinates});
    vec2 c = GetHexCenter(p);
    vec2 q = ToNormalizedSpace(c);
    gl_FragColor = texture2D(${uTexture}, q);
}
""";

List<ShaderObject> createHexPixelateShader() {
  return [
    _effectVertexShader,
    new ShaderObject("HexPixelateF")
      ..AddVaryingVar(vTextureCoordinates)
      ..AddUniformVar(uCanvasSize)
      ..AddUniformVar(uCenter2)
      ..AddUniformVar(uScale)
      ..AddUniformVar(uTexture)
      ..SetBody([_hexPixelateFragment])
  ];
}
