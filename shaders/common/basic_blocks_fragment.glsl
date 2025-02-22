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
uniform float alphaTestRef;

in vec4 tint_color;
in vec2 texcoord;

void main() {
  vec4 block_color = tint_color;

  if(block_color.a < alphaTestRef) discard;  // Full transparency
  #include "/src/writebuffers.glsl"
}
