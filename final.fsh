#version 120

varying vec2 texcoord;
uniform sampler2D colortex0;
uniform float viewWidth;
uniform float viewHeight;
uniform float sunAngle;
uniform int isEyeInWater;

// ==================== AYARLANABILIR DEGERLER (Video Ayarlari > Shader Secenekleri) ====================
#define SHARPEN_INTENSITY 0.3      // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define DARK_THRESHOLD 0.3         // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define LIGHT_STRENGTH 0.9         // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define SATURATION 1.08            // [0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.05 1.1 1.15 1.2 1.25 1.3 1.35 1.4 1.45 1.5 1.55 1.6 1.65 1.7 1.75 1.8]
#define VIGNETTE_STRENGTH 0.20     // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define CHROMA_STRENGTH 0.04       // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define DAYNIGHT_STRENGTH 0.5      // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]
#define UNDERWATER_CLARITY 0.6     // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

#define PI 3.14159265

void main() {
    vec2 step = 1.0 / vec2(viewWidth, viewHeight);

    // ---------- 1. KESKINLESTIRME ----------
    vec4 center = texture2D(colortex0, texcoord);
    vec4 left   = texture2D(colortex0, texcoord - vec2(step.x, 0.0));
    vec4 right  = texture2D(colortex0, texcoord + vec2(step.x, 0.0));
    vec4 up     = texture2D(colortex0, texcoord - vec2(0.0, step.y));
    vec4 down   = texture2D(colortex0, texcoord + vec2(0.0, step.y));
    vec4 edgeBlur = (left + right + up + down) * 0.25;
    vec4 sharpColor = center + (center - edgeBlur) * SHARPEN_INTENSITY;

    // ---------- 2. KARANLIKTA AYDINLATMA (screen-blend) ----------
    float brightness = dot(sharpColor.rgb, vec3(0.2126, 0.7152, 0.0722));
    float darknessFactor = 1.0 - smoothstep(0.0, DARK_THRESHOLD, brightness);
    vec3 torchColor = vec3(0.45, 0.34, 0.20);
    float lightAmount = darknessFactor * LIGHT_STRENGTH;
    vec3 addedLight = torchColor * lightAmount;
    sharpColor.rgb = sharpColor.rgb + addedLight * (vec3(1.0) - sharpColor.rgb);

    // ---------- 3. KROMATIK ABERASYON ----------
    vec2 caOffset = (texcoord - vec2(0.5)) * CHROMA_STRENGTH * 0.01;
    sharpColor.r = texture2D(colortex0, texcoord + caOffset).r;
    sharpColor.b = texture2D(colortex0, texcoord - caOffset).b;

    // ---------- 4. GUN/GECE TON DEGISIMI ----------
    // sunAngle: 0.0 gun dogumu, 0.25 ogle, 0.5 gun batimi, 0.75 gece yarisi
    float dayAmount = cos((sunAngle - 0.25) * 2.0 * PI);      // +1 oglen, -1 gece yarisi
    float warmFactor = clamp(cos(sunAngle * 4.0 * PI), 0.0, 1.0); // gun dogumu/batiminda tepe yapar
    float nightFactor = clamp(-dayAmount, 0.0, 1.0);           // gece yarisina yakinken artar
    vec3 dayNightTint = vec3(1.0);
    dayNightTint = mix(dayNightTint, vec3(1.18, 0.92, 0.72), warmFactor * DAYNIGHT_STRENGTH);
    dayNightTint = mix(dayNightTint, vec3(0.80, 0.86, 1.08), nightFactor * DAYNIGHT_STRENGTH);
    sharpColor.rgb *= dayNightTint;

    // ---------- 5. SU ALTI NETLIGI ----------
    if (isEyeInWater == 1) {
        float wLuma = dot(sharpColor.rgb, vec3(0.2126, 0.7152, 0.0722));
        // kontrasti artir
        sharpColor.rgb = (sharpColor.rgb - vec3(0.5)) * (1.0 + 0.3 * UNDERWATER_CLARITY) + vec3(0.5);
        // agir mavi-yesil baskiyi hafiflet
        sharpColor.rgb += vec3(0.05, 0.03, 0.0) * UNDERWATER_CLARITY;
        // hafif ek keskinlik (bulaniklik hissini azaltir)
        sharpColor.rgb = mix(sharpColor.rgb, sharpColor.rgb + (sharpColor.rgb - vec3(wLuma)) * 0.15, UNDERWATER_CLARITY);
    }

    // ---------- 6. RENK CANLILIGI (SATURATION) ----------
    float finalLuma = dot(sharpColor.rgb, vec3(0.2126, 0.7152, 0.0722));
    sharpColor.rgb = mix(vec3(finalLuma), sharpColor.rgb, SATURATION);

    // ---------- 7. VINYET ----------
    float vignetteDist = length(texcoord - vec2(0.5));
    float vignette = smoothstep(0.4, 0.9, vignetteDist);
    sharpColor.rgb *= mix(1.0, 1.0 - VIGNETTE_STRENGTH, vignette);

    // ---------- 8. GAMA / GOLGE AYDINLATMA FILTRESI ----------
    sharpColor.rgb = pow(max(sharpColor.rgb, vec3(0.0)), vec3(0.88));

    gl_FragColor = clamp(sharpColor, 0.0, 1.0);
}
