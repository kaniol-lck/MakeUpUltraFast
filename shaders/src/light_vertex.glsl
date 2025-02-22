tint_color = vaColor;

// Luz nativa (lmcoord.x: candela, lmcoord.y: cielo) ----
vec2 illumination = (max(lmcoord, vec2(0.065)) - vec2(0.065)) * 1.06951871657754;

// Visibilidad del cielo
#ifdef WATER_F
  visible_sky = illumination.y;
#else
  float visible_sky = illumination.y;
#endif

// Ajuste de intensidad luminosa bajo el agua
if (isEyeInWater == 1) {
  visible_sky = (visible_sky * .95) + .05;
}

// Intensidad y color de luz de candelas
#if defined THE_END || defined NETHER
  candle_color =
    CANDLE_BASELIGHT * ((illumination.x * illumination.x) + pow(illumination.x + 0.01, 13.0));
#else
  candle_color =
    CANDLE_BASELIGHT * ((illumination.x * illumination.x) + pow(illumination.x + 0.06, 13.0));
#endif

// Atenuación por dirección de luz directa ===================================
#if defined THE_END || defined NETHER
  vec3 sun_vec =
    normalize(gbufferModelView * vec4(0.0, 0.89442719, 0.4472136, 0.0)).xyz;
#else
  vec3 sun_vec = normalize(sunPosition);
#endif

vec3 normal = normalize(normalMatrix * vaNormal);
float sun_light_strenght = dot(normal, sun_vec);

#if defined THE_END || defined NETHER
  direct_light_strenght = sun_light_strenght;
#else
  direct_light_strenght =
    mix(-sun_light_strenght, sun_light_strenght, light_mix);
#endif

#ifndef SHADOW_CASTING
  direct_light_strenght = pow((direct_light_strenght + 1.0) * 0.5, 3.0);
#endif

// Intensidad por dirección
float omni_strenght = (direct_light_strenght * .125) + 1.0;

// Calculamos color de luz directa
direct_light_color = day_blend(
  AMBIENT_MIDDLE_COLOR,
  AMBIENT_DAY_COLOR,
  AMBIENT_NIGHT_COLOR
  );

#ifdef FOLIAGE_V  // Puede haber plantas en este shader
  if (is_foliage > .2) {  // Es "planta" y se atenúa luz por dirección
    #ifdef SHADOW_CASTING
      direct_light_strenght = sqrt(abs(direct_light_strenght));
    #else
      #if defined THE_END || defined NETHER
        float foliage_attenuation_coef = abs((light_mix - .5) * 2.0);
      #else
        float foliage_attenuation_coef = 1.0;
      #endif

      direct_light_strenght =
      mix(clamp(direct_light_strenght, 0.0, 1.0), 1.0, .25 * foliage_attenuation_coef) * .75;
    #endif

    omni_strenght = 1.0;
  }
#endif

direct_light_strenght = clamp(direct_light_strenght, 0.0, 1.0);

#if defined THE_END || defined NETHER
  omni_light = AMBIENT_DAY_COLOR;
#else
  // Calculamos color de luz ambiental

  vec3 hi_sky_color = day_blend(
    HI_MIDDLE_COLOR,
    HI_DAY_COLOR,
    HI_NIGHT_COLOR
    );

  vec3 sky_color = HI_SKY_RAIN_COLOR * luma(hi_sky_color);

  direct_light_color = mix(
    direct_light_color,
    HI_SKY_RAIN_COLOR * luma(direct_light_color),
    rainStrength
  );

  hi_sky_color = mix(
    hi_sky_color,
    sky_color,
    rainStrength
  );

  float omni_minimal;
  if (isEyeInWater == 1) {
    omni_minimal = day_blend_float(0.1, 0.055, 1.0);
  } else {
    omni_minimal = AVOID_DARK_LEVEL;
  }

  float visible_avoid_dark = (pow(visible_sky, 1.5) * (1.0 - omni_minimal)) + omni_minimal;

  omni_light = visible_avoid_dark * omni_strenght *
    mix(hi_sky_color, direct_light_color * 0.75, OMNI_TINT);

#endif

#ifdef CAVEENTITY_V
  // Avoid flat illumination in caves for entities
  float candle_cave_strenght = (direct_light_strenght * .5) + .5;
  candle_cave_strenght =
    mix(candle_cave_strenght, 1.0, visible_sky);
  candle_color *= candle_cave_strenght;
#endif

#if !defined THE_END && !defined NETHER
  #ifndef SHADOW_CASTING
    // Fake shadows
    if (isEyeInWater == 0) {
      direct_light_strenght = mix(0.0, direct_light_strenght, pow(visible_sky, 10.0));
    } else {
      direct_light_strenght = mix(0.0, direct_light_strenght, visible_sky);
    }
  #else
    direct_light_strenght = mix(0.0, direct_light_strenght, visible_sky);
  #endif
#endif

#ifdef EMMISIVE_V
  if (is_fake_emmisor > 0.5) {
    direct_light_strenght = 10.0;
  }
#endif