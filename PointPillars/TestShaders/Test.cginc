#ifndef _TEST_
#define _TEST_

#define mod(x,y) ((x)-(y)*floor((x)/(y))) // glsl mod

#define sc_uint2 static const uint2

inline bool insideArea(in uint4 area, uint2 px)
{
    if (px.x >= area.x && px.x < (area.x + area.z) &&
        px.y >= area.y && px.y < (area.y + area.w))
    {
        return true;
    }
    return false;
}

#endif