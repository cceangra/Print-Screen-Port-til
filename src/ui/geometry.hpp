// Print RC — private native module. GPL-3.0-or-later
#pragma once
#include <algorithm>

namespace prc {
struct Rect { int x=0,y=0,w=0,h=0; };
int clampi(int v, int lo, int hi) { return std::max(lo,std::min(v,hi)); }
Rect rect_between(int a,int b,int c,int d,int width,int height) {
    int x1=clampi(std::min(a,c),0,width), y1=clampi(std::min(b,d),0,height);
    int x2=clampi(std::max(a,c),0,width), y2=clampi(std::max(b,d),0,height);
    return {x1,y1,x2-x1,y2-y1};
}
Rect expand(Rect r, int margin, int width, int height) {
    return rect_between(r.x-margin,r.y-margin,r.x+r.w+margin,r.y+r.h+margin,width,height);
}
Rect unite(Rect a,Rect b,int width,int height) {
    if (a.w<=0||a.h<=0) return expand(b,4,width,height);
    if (b.w<=0||b.h<=0) return expand(a,4,width,height);
    return expand(rect_between(std::min(a.x,b.x),std::min(a.y,b.y),
        std::max(a.x+a.w,b.x+b.w),std::max(a.y+a.h,b.y+b.h),width,height),4,width,height);
}


}
