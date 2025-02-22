/* MakeUp - water.glsl
Water reflection and refraction related functions.
*/

vec3 fast_raymarch(vec3 direction, vec3 hit_coord, inout float infinite, float dither) {
  vec3 hit_pos = vec3(gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y), gl_FragCoord.z);

  vec3 dir_increment;
  vec3 current_march = hit_coord;
  vec3 old_current_march;
  float screen_depth;
  float prev_screen_depth = 0.0;
  float depth_diff = 1.0;
  vec3 march_pos;
  vec3 last_march_pos;
  vec3 last_hidden_pos;
  bool search_flag = false;
  bool hidden_flag = false;
  bool first_hidden = true;
  bool out_flag = false;

  // Ray marching
  for (int i = 0; i < RAYMARCH_STEPS; i++) {
    if (search_flag) {
      dir_increment *= 0.5;
      current_march += dir_increment * sign(depth_diff);
    } else {
      old_current_march = current_march;
      current_march = hit_coord + ((direction * exp2(i + dither)) - direction);
      dir_increment = current_march - old_current_march;
    }

    last_march_pos = march_pos;
    march_pos = camera_to_screen(current_march);

    if ( // Is outside screen space
      march_pos.x < 0.0 ||
      march_pos.x > 1.0 ||
      march_pos.y < 0.0 ||
      march_pos.y > 1.0
      ) {
        out_flag = true;
      }

    screen_depth = texture(depthtex1, march_pos.xy).x;
    depth_diff = screen_depth - march_pos.z;

    if (depth_diff < 0.0 && abs(screen_depth - prev_screen_depth) > abs(march_pos.z - last_march_pos.z)) {
      hidden_flag = true;
      if (first_hidden) {
        last_hidden_pos = last_march_pos;
        first_hidden = false;
      }
    } else if (hidden_flag && depth_diff > 0.0) {
      hidden_flag = false;
    }

    if (search_flag == false && depth_diff < 0.0 && hidden_flag == false) {
      search_flag = true;
    }

    prev_screen_depth = screen_depth;
  }

  infinite = float(screen_depth > 0.9999);

  if (out_flag) {
    infinite = 1.0;
    return march_pos;
  } else if (hidden_flag) {
    return last_hidden_pos;
  } else {
    return camera_to_screen(current_march);
  }
}

#if SUN_REFLECTION == 1
  #if !defined NETHER && !defined THE_END

    float sun_reflection(vec3 fragpos) {
      vec3 astro_pos = worldTime > 12900 ? moonPosition : sunPosition;
      float astro_vector =
        max(dot(normalize(fragpos), normalize(astro_pos)), 0.0);

      return clamp(
          smoothstep(
            0.997, 1.0, astro_vector) *
            clamp(4.0 * lmcoord.y - 3.0, 0.0, 1.0) *
            (1.0 - rainStrength),
          0.0,
          1.0
        );
    }

  #endif
#endif

vec3 normal_waves(vec3 pos) {
  vec2 wave_1 =
     texture(noisetex, (pos.xy * 0.125) + (frameTimeCounter * -.025)).rg;
     wave_1 = wave_1 - .5;
  vec2 wave_2 =
     texture(noisetex, (pos.xy * 0.03125) - (frameTimeCounter * .025)).rg;
  wave_2 = wave_2 - .5;
  wave_2 *= 2.0;

  vec2 partial_wave = wave_1 + wave_2;

  vec3 final_wave =
    vec3(partial_wave, 1.0 - (partial_wave.x * partial_wave.x + partial_wave.y * partial_wave.y));

  final_wave.b *= WATER_TURBULENCE;

  return normalize(final_wave);
}

vec3 refraction(vec3 fragpos, vec3 color, vec3 refraction) {
  vec2 pos = gl_FragCoord.xy * vec2(pixel_size_x, pixel_size_y);

  #if REFRACTION == 1
    float refraction_strength = 0.13;
    refraction_strength /= 1.0 + length(fragpos) * 0.4;
    pos = pos + refraction.xy * refraction_strength;
  #endif

  float water_absortion;
  if (isEyeInWater == 0) {
    float water_distance =
      2.0 * near * far / (far + near - (2.0 * gl_FragCoord.z - 1.0) * (far - near));

    float earth_distance = texture(depthtex1, pos.xy).r;
    earth_distance =
      2.0 * near * far / (far + near - (2.0 * earth_distance - 1.0) * (far - near));

    water_absortion = earth_distance - water_distance;
    water_absortion *= water_absortion;
    water_absortion = (1.0 / -((water_absortion * WATER_ABSORPTION) + 1.125)) + 1.0;
  } else {
    water_absortion = 0.0;
  }

  return mix(texture(gaux1, pos.xy).rgb, color, water_absortion);
}

vec3 get_normals(vec3 bump) {
  float NdotE = abs(dot(water_normal, normalize(position2.xyz)));

  bump *= vec3(NdotE) + vec3(0.0, 0.0, 1.0 - NdotE);

  mat3 tbn_matrix = mat3(
    tangent.x, binormal.x, water_normal.x,
    tangent.y, binormal.y, water_normal.y,
    tangent.z, binormal.z, water_normal.z
    );

  return normalize(bump * tbn_matrix);
}

vec4 reflection_calc(vec3 fragpos, vec3 normal, vec3 reflected, inout float infinite, float dither) {
  #if SSR_TYPE == 0  // Flipped image
    vec3 pos = camera_to_screen(fragpos + reflected * 50.0);
  #else  // Raymarch
    vec3 pos = fast_raymarch(reflected, fragpos, infinite, dither);
  #endif

  float border =
    clamp((1.0 - (max(0.0, abs(pos.y - 0.5)) * 2.0)) * 50.0, 0.0, 1.0);

  border = clamp(border - pow(pos.y, 10.0), 0.0, 1.0);

  pos.x = abs(pos.x);
  if (pos.x > 1.0) {
    pos.x = 1.0 - (pos.x - 1.0);
  }

  return vec4(texture(gaux1, pos.xy).rgb, border);
}

vec3 water_shader(
  vec3 fragpos,
  vec3 normal,
  vec3 color,
  vec3 sky_reflect,
  vec3 reflected,
  float fresnel,
  float visible_sky,
  float dither) {
  vec4 reflection = vec4(0.0);
  float infinite = 1.0;

  #if REFLECTION == 1
    reflection = reflection_calc(fragpos, normal, reflected, infinite, dither);
  #endif

  reflection.rgb = mix(
    sky_reflect * pow(visible_sky, 10.0),
    reflection.rgb,
    reflection.a
  );

  #ifdef VANILLA_WATER
    fresnel *= 0.8;
  #endif

  #if SUN_REFLECTION == 1
    #ifndef NETHER
      #ifndef THE_END
        return mix(color, reflection.rgb, fresnel * .6) +
          vec3(sun_reflection(reflect(normalize(fragpos), normal))) * infinite;          
      #else
        return mix(color, reflection.rgb, fresnel * .6);
      #endif
    #else
      return mix(color, reflection.rgb, fresnel * .6);
    #endif
  #else
     return mix(color, reflection.rgb, fresnel * .6);
  #endif
}

//  GLASS

vec4 cristal_reflection_calc(vec3 fragpos, vec3 normal, inout float infinite, float dither) {
  #if SSR_TYPE == 0
    vec3 reflected_vector = reflect(normalize(fragpos), normal) * 50.0;
    vec3 pos = camera_to_screen(fragpos + reflected_vector);
  #else
    vec3 reflected_vector = reflect(normalize(fragpos), normal);
    vec3 pos = fast_raymarch(reflected_vector, fragpos, infinite, dither);

    if (pos.x > 99.0) { // Fallback
      pos = camera_to_screen(fragpos + reflected_vector * 50.0);
    }
  #endif

  float border_x = max(-fourth_pow(abs(2.0 * pos.x - 1.0)) + 1.0, 0.0);
  float border_y = max(-fourth_pow(abs(2.0 * pos.y - 1.0)) + 1.0, 0.0);
  float border = min(border_x, border_y);

  return vec4(texture(gaux1, pos.xy, 0.0).rgb, border);
}

vec4 cristal_shader(
  vec3 fragpos,
  vec3 normal,
  vec4 color,
  vec3 sky_reflection,
  float fresnel,
  float dither)
{
  vec4 reflection = vec4(0.0);
  float infinite = 0.0;

  #if REFLECTION == 1
    reflection = cristal_reflection_calc(fragpos, normal, infinite, dither);
  #endif

  reflection.rgb = mix(sky_reflection * lmcoord.y * lmcoord.y, reflection.rgb, reflection.a);

  color.rgb = mix(color.rgb, sky_reflection, fresnel);
  color.rgb = mix(color.rgb, reflection.rgb, fresnel);

  color.a = mix(color.a, 1.0, fresnel * .9);

  #if SUN_REFLECTION == 1
    #ifndef NETHER
      #ifndef THE_END
        return color +
          vec4(
            mix(
              vec3(sun_reflection(reflect(normalize(fragpos), normal)) * 0.75 * infinite),
              vec3(0.0),
              reflection.a
            ),
            0.0
          );
      #else
        return color;
      #endif
    #else
      return color;
    #endif
  #else
    return color;
  #endif
}
