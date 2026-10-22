// Print RC — private native module. GPL-3.0-or-later
#pragma once
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <png.h>
#include <cstdint>
#include <iostream>
#include <vector>
#include <memory>
#include <cstring>
#include <new>
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

struct PngOutput {
    std::vector<unsigned char> bytes;
    char error[256]{};
};
void png_failure(png_structp writer,png_const_charp message) {
    auto* output=static_cast<PngOutput*>(png_get_error_ptr(writer));
    if(output && message) std::strncpy(output->error,message,sizeof(output->error)-1);
    png_longjmp(writer,1);
}
void png_warning(png_structp,png_const_charp) {}
void png_append(png_structp writer,png_bytep data,png_size_t size) {
    auto* output=static_cast<PngOutput*>(png_get_io_ptr(writer));
    try { output->bytes.insert(output->bytes.end(),data,data+size); }
    catch(const std::bad_alloc&) { png_error(writer,prc_tr("native.png_buffer_allocation")); }
}
std::vector<unsigned char> encode_png(XImage* src,Rect r) {
    if(!src || !src->data || r.x<0 || r.y<0 || r.w<=0 || r.h<=0
       || r.x>src->width-r.w || r.y>src->height-r.h) return {};
    if(static_cast<uint64_t>(r.w)*r.h>100000000ULL) return {};
    // Row conversion avoids a full-screen RGBA staging buffer and a second PNG encode.
    // Heap-owned state is stable across libpng's C error longjmp.
    auto output=std::make_unique<PngOutput>();
    std::vector<unsigned char> row(static_cast<size_t>(r.w)*4);
    png_structp writer=png_create_write_struct(PNG_LIBPNG_VER_STRING,output.get(),png_failure,png_warning);
    if(!writer) return {};
    png_infop info=png_create_info_struct(writer);
    if(!info) {png_destroy_write_struct(&writer,nullptr);return {};}
    if(setjmp(png_jmpbuf(writer))) {
        std::cerr<<prc_tr("native.003")<<output->error<<"\n";
        png_destroy_write_struct(&writer,&info);return {};
    }
    png_set_write_fn(writer,output.get(),png_append,nullptr);
    png_set_IHDR(writer,info,static_cast<png_uint_32>(r.w),static_cast<png_uint_32>(r.h),8,
                 PNG_COLOR_TYPE_RGBA,PNG_INTERLACE_NONE,PNG_COMPRESSION_TYPE_BASE,PNG_FILTER_TYPE_BASE);
    png_set_sRGB(writer,info,PNG_sRGB_INTENT_PERCEPTUAL);
    png_set_compression_level(writer,3);
    png_set_filter(writer,PNG_FILTER_TYPE_BASE,PNG_FILTER_SUB);
    png_write_info(writer,info);
    auto extract=[](unsigned long pixel,unsigned long mask)->unsigned char {
        if(!mask) return 0;
        unsigned shift=0;
        while(shift<sizeof(unsigned long)*8-1 && ((mask>>shift)&1UL)==0) ++shift;
        const unsigned long maximum=mask>>shift;
        return static_cast<unsigned char>((((pixel&mask)>>shift)*255UL+maximum/2)/maximum);
    };
    const bool rgb32=src->bits_per_pixel==32 && src->byte_order==LSBFirst
        && src->red_mask==0x00ff0000UL && src->green_mask==0x0000ff00UL && src->blue_mask==0x000000ffUL;
    for(int y=0;y<r.h;++y) {
        const auto* source=reinterpret_cast<const unsigned char*>(src->data+static_cast<size_t>(y+r.y)*src->bytes_per_line);
        for(int x=0;x<r.w;++x) {
            const auto offset=static_cast<size_t>(x)*4;
            if(rgb32) {
                const auto* bgra=source+static_cast<size_t>(x+r.x)*4;
                row[offset]=bgra[2];row[offset+1]=bgra[1];row[offset+2]=bgra[0];
            } else {
                const auto pixel=XGetPixel(src,x+r.x,y+r.y);
                row[offset]=extract(pixel,src->red_mask);
                row[offset+1]=extract(pixel,src->green_mask);
                row[offset+2]=extract(pixel,src->blue_mask);
            }
            row[offset+3]=255;
        }
        png_write_row(writer,row.data());
    }
    png_write_end(writer,info);
    png_destroy_write_struct(&writer,&info);
    return std::move(output->bytes);
}

}
