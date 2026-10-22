// Draws nothing: used to hide the map zones the camera cannot see (Source PVS emulation).
// The object keeps its collision.
technique hide
{
    pass P0
    {
        ColorWriteEnable = 0;
        ZWriteEnable = false;
        AlphaBlendEnable = true;
        SrcBlend = Zero;
        DestBlend = One;
    }
}
