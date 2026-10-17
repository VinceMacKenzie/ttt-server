// Source-style 2D skybox: the sky cube follows the camera and is projected onto the far plane,
// so it is always behind the map geometry and is never fogged ($nofog / $ignorez).
texture gTexture0 < string textureState = "0,Texture"; >;
float4x4 gWorldViewProjection : WORLDVIEWPROJECTION;

sampler Sampler0 = sampler_state
{
    Texture = (gTexture0);
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

struct VSInput  { float3 Position : POSITION0; float2 TexCoord : TEXCOORD0; };
struct PSInput  { float4 Position : POSITION0; float2 TexCoord : TEXCOORD0; };

PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS = (PSInput)0;
    PS.Position = mul(float4(VS.Position, 1), gWorldViewProjection);
    PS.Position.z = PS.Position.w * 0.99999;
    PS.TexCoord = VS.TexCoord;
    return PS;
}

float4 PixelShaderFunction(PSInput PS) : COLOR0
{
    float4 c = tex2D(Sampler0, PS.TexCoord);
    c.a = 1;
    return c;
}

technique sky
{
    pass P0
    {
        FogEnable = false;
        ZWriteEnable = false;
        CullMode = NONE;
        AlphaBlendEnable = false;
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader  = compile ps_2_0 PixelShaderFunction();
    }
}

technique fallback
{
    pass P0 { }
}
