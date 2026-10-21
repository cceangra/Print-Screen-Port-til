// Print RC — private native module. GPL-3.0-or-later
#pragma once
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <algorithm>
#include <vector>

namespace prc {
struct InkPoint {int x=0,y=0;};
using InkStroke=std::vector<InkPoint>;
using InkDrawing=std::vector<InkStroke>;

unsigned long rgb_on_visual(unsigned char red,unsigned char green,unsigned char blue,const XImage* img) {
    auto component=[](unsigned char value,unsigned long mask) {
        if (!mask) return 0UL;
        unsigned shift=0;
        while (shift<sizeof(unsigned long)*8-1 && ((mask>>shift)&1UL)==0) ++shift;
        unsigned long maximum=mask>>shift;
        return (((static_cast<unsigned long>(value)*maximum+127)/255)<<shift)&mask;
    };
    return component(red,img->red_mask)|component(green,img->green_mask)|component(blue,img->blue_mask);
}

void annotate_image(XImage* image,const InkDrawing& strokes) {
    // Desenho leve em memoria: a imagem do overlay nunca entra no PNG final.
    const unsigned long ink=rgb_on_visual(55,180,255,image);
    auto point=[&](int x,int y) {
        for(int dy=-1;dy<=1;++dy) for(int dx=-1;dx<=1;++dx) {
            if(x+dx>=0 && y+dy>=0 && x+dx<image->width && y+dy<image->height)
                XPutPixel(image,x+dx,y+dy,ink);
        }
    };
    for(const auto& stroke:strokes) {
        if(stroke.empty()) continue;
        point(stroke.front().x,stroke.front().y);
        for(size_t i=1;i<stroke.size();++i) {
            auto a=stroke[i-1],b=stroke[i];
            int dx=std::abs(b.x-a.x),dy=std::abs(b.y-a.y);
            // Interpolacao limitada pelas dimensoes da tela.
            int steps=std::max(dx,dy);
            if(steps<=0) {point(b.x,b.y);continue;}
            for(int s=0;s<=steps;++s)
                point(a.x+(b.x-a.x)*s/steps,a.y+(b.y-a.y)*s/steps);
        }
    }
}


}
