//-----------------------------------------------------------------------------
// TTT FEGYVER SKIN SHADER
//
// 1) MINTA: a fegyver eredeti textúráját egy csempézhető mintával festi át.
//    A minta a modell SAJÁT térében, "triplanar" vetítéssel kerül fel, így nem
//    kell ismerni a (custom) fegyvermodellek UV-elrendezését.
// 2) LIVERY (megrajzolt skin): a fegyver két OLDALÁRA vetít egy megrajzolt képet,
//    a modell befoglaló dobozához (gBox) igazítva:
//      - háttér sáv (gLivBG): vízszintesen ismétlődik a fegyver hosszában,
//        a magassága = a fegyver magassága
//      - matricák (gLivFG): a fegyver közepére kerül (felirat, figurák)
//    A másik oldalon tükrözve olvas, így a felirat mindkét oldalról jó irányú.
//    A teteje/alja/eleje az 1) mintát kapja.
// Az eredeti textúra részleteit (élek, kopások) megtartja, a cső belsejét és a
// lyukakat érintetlenül hagyja. Opcionális animált világítás (emissive).
// gUseOverride = 1: kézzel festett, a modell UV-jához illő textúra (teljes csere).
//-----------------------------------------------------------------------------

texture gPattern;                 // csempézhető minta (RGB)
texture gEmissive;                // világító maszk: rgb = fény színe, a = villogás fázisa
texture gOverride;                // teljes csere textúra (modell UV-ja szerint)
texture gLivBG;                   // livery háttér sáv (RGBA, vízszintesen csempézhető)
texture gLivBGE;                  // livery háttér világító maszk
texture gLivFG;                   // livery matricák (RGBA, átlátszó)
texture gLivFGE;                  // livery matricák világító maszk

float  gScale      = 5.0;         // minta ismétlés / méter (modelltérben)
float  gStrength   = 1.0;         // 0..1 mennyire fedje a minta az eredetit
float  gDetail     = 0.75;        // 0..1 mennyit tartson meg az eredeti textúra részleteiből
float  gKeepDark   = 0.6;         // 0..1 a környezetüknél sokkal sötétebb részeket (cső, lyukak) érintetlenül hagyja
float  gGlow       = 0.0;         // világítás erőssége (0 = nincs)
float  gGlowSpeed  = 2.0;         // villogás sebessége
float  gGlowMin    = 0.35;        // villogás minimuma (0..1)
float  gGloss      = 0.25;        // csillanás (specular) erőssége
float  gUseOverride = 0.0;        // 1 = gOverride textúra UV szerint, minta helyett
float3 gTint       = float3(1, 1, 1);

float  gUseLivery  = 0.0;         // 1 = livery bekapcsolva
float4 gBox        = float4(-0.3, 0.8, -0.15, 0.2); // a modell doboza: minX, maxX, minZ, maxZ (hossz tengely = X)
float  gSwapXY     = 0.0;         // 1 = a modell hossz tengelye Y (nem X)
float  gFlipX      = 0.0;         // 1 = a cső -X felé néz
float  gBGAspect   = 4.0;         // háttér sáv képaránya (szélesség / magasság)
float  gFGAspect   = 2.5;         // matrica kép képaránya
float  gFGScale    = 0.45;        // matrica magassága a fegyver magasságához képest
float2 gFGCenter   = float2(0.42, 0.3); // matrica közepe: hossz mentén (0 = tus/hátsó vég, 1 = cső vége), magasság (0 = teteje, 1 = alja)
float  gLivGlow    = 1.0;         // livery világítás erőssége

//--- MTA által automatikusan kitöltött változók --------------------------------
float4x4 gWorld               : WORLD;
float4x4 gView                : VIEW;
float4x4 gProjection          : PROJECTION;
float4x4 gWorldViewProjection : WORLDVIEWPROJECTION;
float4x4 gViewInverse         : VIEWINVERSE;
float    gTime                : TIME;

texture gTexture0             < string textureState = "0,Texture"; >;

float4 gGlobalAmbient         < string renderState = "AMBIENT"; >;
int    gLighting              < string renderState = "LIGHTING"; >;
int    gAmbientMaterialSource < string renderState = "AMBIENTMATERIALSOURCE"; >;
int    gDiffuseMaterialSource < string renderState = "DIFFUSEMATERIALSOURCE"; >;
int    gEmissiveMaterialSource< string renderState = "EMISSIVEMATERIALSOURCE"; >;
float4 gMaterialAmbient       < string materialState = "Ambient"; >;
float4 gMaterialDiffuse       < string materialState = "Diffuse"; >;
float4 gMaterialEmissive      < string materialState = "Emissive"; >;
float4 gLightDiffuse          < string lightState = "0,Diffuse"; >;
float4 gLightAmbient          < string lightState = "0,Ambient"; >;
float3 gLightDirection        < string lightState = "0,Direction"; >;

//--- Samplerek -----------------------------------------------------------------
sampler Sampler0 = sampler_state
{
    Texture = (gTexture0);
    MinFilter = Linear; MagFilter = Linear; MipFilter = Linear;
};
sampler PatternSampler = sampler_state
{
    Texture = (gPattern);
    AddressU = Wrap; AddressV = Wrap;
    MinFilter = Anisotropic; MagFilter = Linear; MipFilter = Linear;
    MaxAnisotropy = 4;
};
sampler EmissiveSampler = sampler_state
{
    Texture = (gEmissive);
    AddressU = Wrap; AddressV = Wrap;
    MinFilter = Linear; MagFilter = Linear; MipFilter = Linear;
};
sampler OverrideSampler = sampler_state
{
    Texture = (gOverride);
    MinFilter = Linear; MagFilter = Linear; MipFilter = Linear;
};
sampler LivBGSampler = sampler_state
{
    Texture = (gLivBG);
    AddressU = Wrap; AddressV = Clamp;
    MinFilter = Anisotropic; MagFilter = Linear; MipFilter = Linear;
    MaxAnisotropy = 8;
};
sampler LivBGESampler = sampler_state
{
    Texture = (gLivBGE);
    AddressU = Wrap; AddressV = Clamp;
    MinFilter = Linear; MagFilter = Linear; MipFilter = Linear;
};
sampler LivFGSampler = sampler_state
{
    Texture = (gLivFG);
    AddressU = Clamp; AddressV = Clamp;
    MinFilter = Anisotropic; MagFilter = Linear; MipFilter = Linear;
    MaxAnisotropy = 8;
};
sampler LivFGESampler = sampler_state
{
    Texture = (gLivFGE);
    AddressU = Clamp; AddressV = Clamp;
    MinFilter = Linear; MagFilter = Linear; MipFilter = Linear;
};

//--- Struktúrák ----------------------------------------------------------------
struct VSInput
{
    float3 Position : POSITION0;
    float3 Normal   : NORMAL0;
    float4 Diffuse  : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

struct PSInput
{
    float4 Position   : POSITION0;
    float4 Diffuse    : COLOR0;
    float2 TexCoord   : TEXCOORD0;
    float3 ModelPos   : TEXCOORD1;
    float3 ModelNorm  : TEXCOORD2;
    float3 WorldNorm  : TEXCOORD3;
    float3 WorldPos   : TEXCOORD4;
};

static const float3 LUM = float3(0.299, 0.587, 0.114);

// Ugyanaz, amit a D3D fix pipeline csinál (MTA mta-helper.fx alapján)
float4 CalcGTADiffuse(float3 worldNormal, float4 inDiffuse)
{
    float4 ambient  = (gAmbientMaterialSource  == 0) ? gMaterialAmbient  : inDiffuse;
    float4 diffuse  = (gDiffuseMaterialSource  == 0) ? gMaterialDiffuse  : inDiffuse;
    float4 emissive = (gEmissiveMaterialSource == 0) ? gMaterialEmissive : inDiffuse;

    float4 totalAmbient = ambient * (gGlobalAmbient + gLightAmbient);
    float  dirFactor    = max(0, dot(worldNormal, -gLightDirection));
    float4 totalDiffuse = diffuse * gLightDiffuse * dirFactor;

    float4 outDiffuse = saturate(totalDiffuse + totalAmbient + emissive);
    outDiffuse.a *= diffuse.a;
    return outDiffuse;
}

//--- Vertex shader -------------------------------------------------------------
PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS = (PSInput)0;
    PS.Position = mul(float4(VS.Position, 1), gWorldViewProjection);
    PS.TexCoord = VS.TexCoord;
    PS.ModelPos = VS.Position;
    PS.ModelNorm = VS.Normal;

    float3 worldNormal = mul(VS.Normal, (float3x3)gWorld);
    float  len = length(worldNormal);
    worldNormal = (len > 0.0001) ? worldNormal / len : float3(0, 0, 1);
    PS.WorldNorm = worldNormal;
    PS.WorldPos = mul(float4(VS.Position, 1), gWorld).xyz;

    PS.Diffuse = (gLighting != 0) ? CalcGTADiffuse(worldNormal, VS.Diffuse) : VS.Diffuse;
    return PS;
}

float Pulse(float phase)
{
    return gGlowMin + (1.0 - gGlowMin) * (0.5 + 0.5 * sin(gTime * gGlowSpeed + phase * 6.2832));
}

//--- Pixel shader (triplanar minta + livery, modelltér) -----------------------
float4 PixelShaderTriplanar(PSInput PS) : COLOR0
{
    float4 orig = tex2D(Sampler0, PS.TexCoord);
    // a textúra átlagos világossága (a legkisebb mipmap) -> sötét fegyvereken is jó arányok
    float avg = max(dot(tex2Dlod(Sampler0, float4(PS.TexCoord, 0, 12)).rgb, LUM), 0.04);
    float lum = dot(orig.rgb, LUM);
    float rel = lum / avg;

    float3 n = PS.ModelNorm;
    float nl = length(n);
    n = (nl > 0.0001) ? n / nl : float3(0, 0, 1);

    //--- 1) triplanar minta
    float3 w = pow(abs(n), 4.0);
    w /= (w.x + w.y + w.z);
    float3 p = PS.ModelPos * gScale;
    float4 pattern = tex2D(PatternSampler, p.yz) * w.x
                   + tex2D(PatternSampler, p.xz) * w.y
                   + tex2D(PatternSampler, p.xy) * w.z;
    float4 emiss   = tex2D(EmissiveSampler, p.yz) * w.x
                   + tex2D(EmissiveSampler, p.xz) * w.y
                   + tex2D(EmissiveSampler, p.xy) * w.z;

    // kézzel festett csere textúra (a mintavétel elágazáson kívül)
    float4 over = tex2D(OverrideSampler, PS.TexCoord);
    float useOver = step(0.5, gUseOverride);
    pattern = lerp(pattern, over, useOver);
    emiss *= (1.0 - useOver);

    // eredeti részletek (az átlaghoz mérve), sötét lyukak megtartása
    float detail = lerp(1.0, clamp(rel, 0.35, 1.6), gDetail);
    float darkMask = lerp(1.0, smoothstep(0.12, 0.4, rel), gKeepDark);
    float amount = saturate(gStrength * darkMask);

    float3 color = lerp(orig.rgb, pattern.rgb * gTint * detail, amount);
    float3 glow = emiss.rgb * gGlow * Pulse(emiss.a) * amount;

    //--- 2) livery a két oldalra
    float3 mp = PS.ModelPos;
    float3 mn = n;
    mp.xy = lerp(mp.xy, mp.yx, gSwapXY);
    mn.xy = lerp(mn.xy, mn.yx, gSwapXY);
    mp.x = lerp(mp.x, -mp.x, gFlipX);
    mn.x = lerp(mn.x, -mn.x, gFlipX);
    float hand = (1.0 - 2.0 * gFlipX) * (1.0 - 2.0 * gSwapXY);
    float side = ((mn.y < 0) ? 1.0 : -1.0) * hand;

    float zs = max(gBox.w - gBox.z, 0.01);
    float cx = lerp(gBox.x, gBox.y, gFGCenter.x);
    float cz = lerp(gBox.w, gBox.z, gFGCenter.y);
    float sideW = smoothstep(0.3, 0.65, abs(mn.y)) * gUseLivery * darkMask;

    float2 uvB = float2((mp.x - gBox.x) / (zs * gBGAspect) * side, (gBox.w - mp.z) / zs);
    float4 lb  = tex2D(LivBGSampler, uvB);
    float4 lbe = tex2D(LivBGESampler, uvB);
    float fh = zs * gFGScale;
    float2 uvF = float2(0.5 + (mp.x - cx) / (fh * gFGAspect) * side, 0.5 + (cz - mp.z) / fh);
    float4 lf  = tex2D(LivFGSampler, uvF);
    float4 lfe = tex2D(LivFGESampler, uvF);

    float aB = lb.a * sideW;
    float aF = lf.a * sideW;
    color = lerp(color, lb.rgb * lerp(1.0, detail, 0.5), aB);
    color = lerp(color, lf.rgb * lerp(1.0, detail, 0.35), aF);
    glow = glow * (1.0 - max(aB, aF))
         + lbe.rgb * gLivGlow * Pulse(lbe.a) * aB * (1.0 - aF)
         + lfe.rgb * gLivGlow * Pulse(lfe.a) * aF;

    //--- fény
    float3 result = color * PS.Diffuse.rgb;
    float3 worldNorm = normalize(PS.WorldNorm);
    float3 viewDir = normalize(gViewInverse[3].xyz - PS.WorldPos);
    float3 halfV = normalize(viewDir - gLightDirection);
    float spec = pow(saturate(dot(worldNorm, halfV)), 24.0) * gGloss * max(amount, max(aB, aF));
    result += spec * gLightDiffuse.rgb;
    result += glow;

    return float4(result, orig.a * PS.Diffuse.a);
}

//--- Tartalék pixel shader (UV-térben, régi videókártyákra, livery nélkül) ----
float4 PixelShaderUV(PSInput PS) : COLOR0
{
    float4 orig = tex2D(Sampler0, PS.TexCoord);
    float2 uv = PS.TexCoord * (gScale * 0.35);
    float4 pattern = lerp(tex2D(PatternSampler, uv), tex2D(OverrideSampler, PS.TexCoord), step(0.5, gUseOverride));
    float lum = dot(orig.rgb, LUM);
    float amount = saturate(gStrength * lerp(1.0, smoothstep(0.02, 0.07, lum), gKeepDark));
    float3 color = lerp(orig.rgb, pattern.rgb * gTint * lerp(1.0, clamp(0.35 + lum * 1.5, 0.0, 1.35), gDetail), amount);
    return float4(color * PS.Diffuse.rgb, orig.a * PS.Diffuse.a);
}

technique weaponskin_sm3
{
    pass P0
    {
        VertexShader = compile vs_3_0 VertexShaderFunction();
        PixelShader  = compile ps_3_0 PixelShaderTriplanar();
    }
}

technique weaponskin_sm2
{
    pass P0
    {
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader  = compile ps_2_0 PixelShaderUV();
    }
}

// Ha semmi sem fordul le, az eredeti marad
technique fallback
{
    pass P0 { }
}
