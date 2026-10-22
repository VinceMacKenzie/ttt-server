// Semi-transparent map surfaces (water, glass, nether portal, clouds): blended without writing depth,
// so they never hide other transparent surfaces behind them depending on the camera angle.
technique blend
{
    pass P0
    {
        AlphaBlendEnable = true;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
        ZWriteEnable = false;
    }
}

technique fallback
{
    pass P0 { }
}
