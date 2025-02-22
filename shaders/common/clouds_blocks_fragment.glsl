/* Exits */
out vec4 outColor0;

#include "/lib/config.glsl"

#ifdef THE_END
  #include "/lib/color_utils_end.glsl"
#elif defined NETHER
  #include "/lib/color_utils_nether.glsl"
#else
  #include "/lib/color_utils.glsl"
#endif

/* Config, uniforms, ins, outs */
uniform sampler2D gtexture;
uniform float far;
uniform float alphaTestRef;

#if V_CLOUDS == 0
  uniform float pixel_size_x;
  uniform float pixel_size_y;
  uniform sampler2D gaux4;
#endif

// Varyings (per thread shared variables)
in vec2 texcoord;
in vec4 tint_color;
in float frog_adjust;
in float var_fog_frag_coord;

void main() {
  #if V_CLOUDS == 0
    vec4 block_color = texture(gtexture, texcoord) * tint_color;
    #include "/src/cloudfinalcolor.glsl"
  #else
    vec4 block_color = vec4(0.0);
  #endif

  if(block_color.a < alphaTestRef) discard;  // Full transparency
  #include "/src/writebuffers.glsl"
}
