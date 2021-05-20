#version 130
/* MakeUp - gbuffers_water.fsh
Render: Water and translucent blocks

Javier Garduño - GNU Lesser General Public License v3.0
*/

#define THE_END
#define WATER_F

#include "/lib/config.glsl"

// 'Global' constants from system
uniform sampler2D tex;
uniform float pixel_size_x;
uniform float pixel_size_y;
uniform float near;
uniform float far;
uniform sampler2D gaux1;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform float frameTimeCounter;
uniform int isEyeInWater;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;

uniform float nightVision;
uniform float rainStrength;

#ifdef SHADOW_CASTING
uniform sampler2D colortex5;
uniform sampler2DShadow shadowtex1;
#endif

// Varyings (per thread shared variables)
in vec2 texcoord;
in vec2 lmcoord;
in vec4 tint_color;
flat in vec3 current_fog_color;
in float frog_adjust;
flat in vec3 water_normal;
flat in float block_type;
in vec4 worldposition;
in vec4 position2;
in vec3 tangent;
in vec3 binormal;

flat in vec3 direct_light_color;
in vec3 candle_color;
in float direct_light_strenght;
in vec3 omni_light;
in float visible_sky;

#ifdef SHADOW_CASTING
  in vec3 shadow_pos;
  in float shadow_diffuse;
#endif

#include "/lib/projection_utils.glsl"
#include "/lib/basic_utils.glsl"
#include "/lib/dither.glsl"
#include "/lib/water.glsl"

#ifdef SHADOW_CASTING
  #include "/lib/shadow_frag.glsl"
#endif

void main() {
  vec4 block_color;
  vec3 fragposition =
    to_screen_space(
      vec3(gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y), gl_FragCoord.z)
      );

  if (block_type > 2.5) {  // Water
    #if MC_VERSION >= 11300
      #if WATER_TEXTURE == 1
        block_color.rgb = mix(
          vec3(1.0),
          tint_color.rgb,
          WATER_TINT
        ) * texture(tex, texcoord).rgb;
      #else
        block_color.rgb = mix(
          vec3(1.0),
          tint_color.rgb,
          WATER_TINT
        );
      #endif
    #else
      #if WATER_TEXTURE == 1
        block_color.rgb = mix(
          vec3(1.0),
          vec3(0.18, 0.33, 0.81),
          WATER_TINT
        ) * texture(tex, texcoord).a;
      #else
        block_color.rgb = mix(
          vec3(1.0),
          vec3(0.18, 0.33, 0.81),
          WATER_TINT
        );
      #endif
    #endif

    vec3 water_normal_base = normal_waves(worldposition.xzy);

    block_color = vec4(
      refraction(
        fragposition,
        block_color.rgb,
        water_normal_base
      ),
      1.0
    );

    vec3 surface_normal = get_normals(water_normal_base);
    vec3 reflect_water_vec = reflect(fragposition, surface_normal);

    block_color.rgb = water_shader(
      fragposition,
      // get_normals(water_normal_base),
      surface_normal,
      block_color.rgb,
      current_fog_color,
      reflect_water_vec
    );

  } else if (block_type > 1.5) {  // Glass
    // Toma el color puro del bloque
    block_color = texture(tex, texcoord) * tint_color;
    float shadow_c;

    #ifdef SHADOW_CASTING
      if (lmcoord.y > 0.005) {
        shadow_c = get_shadow(shadow_pos);
        shadow_c = mix(shadow_c, 1.0, shadow_diffuse);
      } else {
        shadow_c = 1.0;
      }

    #else
      shadow_c = 1.0;
    #endif

    vec3 real_light =
      omni_light +
      (direct_light_strenght * shadow_c * direct_light_color) * (1.0 - rainStrength * 0.75) +
      candle_color;

    block_color.rgb *= mix(real_light, vec3(1.0), nightVision * .125);

    block_color = cristal_shader(
      fragposition,
      water_normal,
      block_color,
      real_light
    );

  } else if (block_type > .5){  // Portal
    // Toma el color puro del bloque
    block_color = texture(tex, texcoord) * tint_color;
    float shadow_c;

    #ifdef SHADOW_CASTING
      if (lmcoord.y > 0.005) {
        shadow_c = get_shadow(shadow_pos);
        shadow_c = mix(shadow_c, 1.0, shadow_diffuse);
      } else {
        shadow_c = 1.0;
      }

    #else
      shadow_c = 1.0;
    #endif

    vec3 real_light =
      omni_light +
      (direct_light_strenght * shadow_c * direct_light_color) * (1.0 - rainStrength * 0.75) +
      candle_color +
      .2;

    block_color.rgb *= mix(real_light, vec3(1.0), nightVision * .125);
  } else {  // ?
    // Toma el color puro del bloque
    block_color = texture(tex, texcoord) * tint_color;
    float shadow_c;

    #ifdef SHADOW_CASTING
      if (lmcoord.y > 0.005) {
        shadow_c = get_shadow(shadow_pos);
        shadow_c = mix(shadow_c, 1.0, shadow_diffuse);
      } else {
        shadow_c = 1.0;
      }

    #else
      shadow_c = 1.0;
    #endif

    vec3 real_light =
      omni_light +
      (direct_light_strenght * shadow_c * direct_light_color) * (1.0 - rainStrength * 0.75) +
      candle_color +
      .2;

    block_color.rgb *= mix(real_light, vec3(1.0), nightVision * .125);
  }

  #include "/src/finalcolor.glsl"
  #include "/src/writebuffers.glsl"
}
