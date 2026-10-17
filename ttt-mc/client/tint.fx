// Source "rendercolor" on brush entities (e.g. the traitor tester lamp turning red/green)
texture gTexture0 < string textureState = "0,Texture"; >;
float4 gColor = float4(1, 1, 1, 1);

sampler Sampler0 = sampler_state
{
    Texture = (gTexture0);
    MinFilter = Point;
    MagFilter = Point;
    MipFilter = Linear;
};

float4 PixelShaderFunction(float4 Diffuse : COLOR0, float2 TexCoord : TEXCOORD0) : COLOR0
{
    float4 c = tex2D(Sampler0, TexCoord) * Diffuse;
    c.rgb *= gColor.rgb;
    return c;
}

technique tint
{
    pass P0
    {
        PixelShader = compile ps_2_0 PixelShaderFunction();
    }
}

technique fallback
{
    pass P0 { }
}
