// Print RC — private native module. GPL-3.0-or-later
#pragma once
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <png.h>
#include <cstdint>
#include <iostream>
#include <vector>
#include "../ui/geometry.hpp"
#include "../i18n/messages.hpp"

namespace prc {
unsigned long darken(unsigned long pixel, unsigned long red, unsigned long green, unsigned long blue) {
    const unsigned long mask = red|green|blue;
    const unsigned long rgb = pixel & mask;
    auto channel = [rgb](unsigned long m)->unsigned long {
        if (!m) return 0;
        unsigned shift = 0; while (((m>>shift)&1UL)==0 && shift < sizeof(unsigned long)*8-1) ++shift;
        const unsigned long x=(rgb&m)>>shift;
        // 62% do brilho original; nao assume RGB888.
        return ((x*62UL)/100UL<<shift)&m;
    };
    return (pixel & ~mask)|channel(red)|channel(green)|channel(blue);
}

std::vector<unsigned char> encode_png(XImage* src, Rect r) {
    if(!src || !src->data || r.x<0 || r.y<0 || r.w<=0 || r.h<=0
       || r.x>src->width-r.w || r.y>src->height-r.h) return {};
    if (static_cast<uint64_t>(r.w)*r.h > 100000000ULL) return {};
    std::vector<unsigned char> pixels(static_cast<size_t>(r.w)*r.h*4);
    auto extract=[](unsigned long p,unsigned long mask)->unsigned char {
        if (!mask) return 0;
        int shift=0; while (((mask>>shift)&1UL)==0 && shift<63) ++shift;
        unsigned long maxval=mask>>shift;
        return static_cast<unsigned char>((((p&mask)>>shift)*255UL+maxval/2)/maxval);
    };
    const bool rgb32=src->bits_per_pixel==32 && src->byte_order==LSBFirst
        && src->red_mask==0x00ff0000UL && src->green_mask==0x0000ff00UL
        && src->blue_mask==0x000000ffUL;
    if(rgb32) {
        // Conversao linear BGRA->RGBA sem XGetPixel por pixel; outras telas mantem fallback.
        for(int y=0;y<r.h;++y) {
            const unsigned char* row=reinterpret_cast<const unsigned char*>(
                src->data + static_cast<size_t>(y+r.y)*src->bytes_per_line);
            for(int x=0;x<r.w;++x) {
                const unsigned char* bgra=row+static_cast<size_t>(x+r.x)*4;
                auto i=(static_cast<size_t>(y)*r.w+x)*4;
                pixels[i]=bgra[2];
                pixels[i+1]=bgra[1];
                pixels[i+2]=bgra[0];
                pixels[i+3]=255;
            }
        }
    } else {
        for (int y=0;y<r.h;++y) for (int x=0;x<r.w;++x) {
            unsigned long p=XGetPixel(src,r.x+x,r.y+y);
            auto i=(static_cast<size_t>(y)*r.w+x)*4;
            pixels[i]=extract(p,src->red_mask);
            pixels[i+1]=extract(p,src->green_mask);
            pixels[i+2]=extract(p,src->blue_mask);
            pixels[i+3]=255;
        }
    }
    png_image image{};
    image.version=PNG_IMAGE_VERSION;
    image.width=static_cast<png_uint_32>(r.w);
    image.height=static_cast<png_uint_32>(r.h);
    image.format=PNG_FORMAT_RGBA;
    png_alloc_size_t size=0;
    if (!png_image_write_to_memory(&image,nullptr,&size,0,pixels.data(),0,nullptr)) {
        std::cerr << prc_tr("native.002") << image.message << "\n";
        png_image_free(&image);
        return {};
    }
    std::vector<unsigned char> result(static_cast<size_t>(size));
    if (!png_image_write_to_memory(&image,result.data(),&size,0,pixels.data(),0,nullptr)) {
        std::cerr << prc_tr("native.003") << image.message << "\n";
        png_image_free(&image);
        return {};
    }
    result.resize(static_cast<size_t>(size));
    png_image_free(&image);
    return result;
}



}
