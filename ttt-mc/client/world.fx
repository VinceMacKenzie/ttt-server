// ttt_minecraft_b5 - renders every map texture like Source does: texture x baked lightmap (vertex colour),
// with the map's own distance fog. GTA's dynamic lighting is not used, so the map looks the same at any
// time / weather and is never overbright or tinted.
//   gColor : Source "rendercolor" tint (traitor tester lamp etc.)
//   gDecal : pulls the surface towards the camera by this fraction of its distance (ore overlays, rails)
//            so it never z-fights with the block face right behind it

texture gTexture0 < string textureState = "0,Texture"; >;
float4x4 gWorld : WORLD;
float4x4 gViewProjection : VIEWPROJECTION;
float3 gCameraPosition : CAMERAPOSITION;

float4 gColor = float4(1, 1, 1, 1);
float gDecal = 0;
float3 gMapFogColor = float3(0.678, 0.780, 1.0);
float gMapFogStart = 62.5;
float gMapFogEnd = 109.4;
float gMapFogOn = 1;
float gBrightness = 1;

sampler Sampler0 = sampler_state
{
    Texture = (gTexture0);
    MagFilter = Point;      // crisp Minecraft pixels up close
    MinFilter = Linear;     // + mip-mapping in the distance: no shimmering / "jumping" textures
    MipFilter = Linear;
    AddressU = Wrap;
    AddressV = Wrap;
};

struct VSInput
{
    float3 Position : POSITION0;
    float4 Diffuse  : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

struct PSInput
{
    float4 Position : POSITION0;
    float4 Diffuse  : COLOR0;
    float2 TexCoord : TEXCOORD0;
    float  Dist     : TEXCOORD1;
};

PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS = (PSInput)0;
    float4 wp = mul(float4(VS.Position, 1), gWorld);
    float3 d = wp.xyz - gCameraPosition;
    wp.xyz = gCameraPosition + d * (1 - gDecal);
    PS.Position = mul(wp, gViewProjection);
    PS.Diffuse = VS.Diffuse;
    PS.TexCoord = VS.TexCoord;
    PS.Dist = length(d);
    return PS;
}

float4 PixelShaderFunction(PSInput PS) : COLOR0
{
    float4 c = tex2D(Sampler0, PS.TexCoord) * PS.Diffuse;
    c.rgb *= gColor.rgb * gBrightness;
    float f = saturate((PS.Dist - gMapFogStart) / max(gMapFogEnd - gMapFogStart, 0.01)) * gMapFogOn;
    c.rgb = lerp(c.rgb, gMapFogColor, f);
    return c;
}

technique world
{
    pass P0
    {
        FogEnable = false;     // the map's own fog is applied above
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader  = compile ps_2_0 PixelShaderFunction();
    }
}

// shader model 2 not available: GTA renders the model itself (prelit colours, no dynamic lighting)
technique fallback
{
    pass P0 { }
}
