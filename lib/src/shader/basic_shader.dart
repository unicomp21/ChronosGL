part of chronosshader;

//  Gouraud shading - most action happens in vertext shader - cheaper
final ShaderObject lightVertexShaderGourad = new ShaderObject("LightGouradV")
  ..AddAttributeVars([aPosition, aNormal, aTexUV])
  ..AddVaryingVars([vColor])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix, uNormalMatrix])
  ..AddUniformVars([uLightDescs, uLightTypes, uShininess])
  ..AddUniformVars([uEyePosition, uTexture])
  ..SetBody(["""
void main() {
    vec4 pos = ${uModelMatrix} * vec4(${aPosition}, 1.0);
    gl_Position = ${uPerspectiveViewMatrix} * pos;
    vec3 normal = ${uNormalMatrix} * ${aNormal};

    ColorComponents acc = CombinedLight(pos.xyz, normal, ${uEyePosition},
                  ${uLightDescs},
                  ${uLightTypes},
                  ${uShininess});

     ${vColor} = acc.diffuse +
                 acc.specular +
                 texture(${uTexture}, ${aTexUV}).rgb;
}
        """
  ], prolog: [
    StdLibShader
  ]);

final ShaderObject lightFragmentShaderGourad = new ShaderObject("LightGrouradV")
  ..AddVaryingVars([vColor])
  ..SetBodyWithMain(["${oFragColor} = vec4(${vColor}, 1.0 );"]);

// Phong shader - most action happens in fragment shader - expensive
// Light Matrix m organization:
// m[0].xyz light direction
//
final ShaderObject lightVertexShaderBlinnPhong =
    new ShaderObject("LightBlinnPhongV")
      ..AddAttributeVars([aPosition, aNormal, aTexUV])
      ..AddVaryingVars([vVertexPosition, vNormal, vTexUV])
      ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix, uNormalMatrix])
      ..SetBody(["""
void main() {
    vec4 pos = ${uModelMatrix} * vec4(${aPosition}, 1.0);
    gl_Position = ${uPerspectiveViewMatrix} * pos;
    ${vVertexPosition} = pos.xyz;
    ${vTexUV} = ${aTexUV};
    ${vNormal} = ${uNormalMatrix} * ${aNormal};
}
"""]);
final ShaderObject lightFragmentShaderBlinnPhong =
    new ShaderObject("LightBlinnPhongF")
      ..AddVaryingVars([vVertexPosition, vNormal, vTexUV])
      ..AddUniformVars([uLightDescs, uLightTypes, uShininess])
      ..AddUniformVars([uEyePosition, uTexture])
      ..SetBodyWithMain([
        """
ColorComponents acc = CombinedLight(${vVertexPosition},
                                    ${vNormal},
                                    ${uEyePosition},
                                    ${uLightDescs},
                                    ${uLightTypes},
                                    ${uShininess});

${oFragColor}.rgb = acc.diffuse +
                    acc.specular +
                    texture(${uTexture}, ${vTexUV}).rgb;
${oFragColor}.a = 1.0;
"""
      ], prolog: [
        StdLibShader
      ]);
