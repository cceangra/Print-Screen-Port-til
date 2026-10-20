// Test-only: paint noisy pixels on the X11 root to exercise INCR clipboard transfers.
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <cstdint>
#include <cstdlib>
#include <iostream>
int main() {
    Display* d=XOpenDisplay(nullptr);
    if(!d) return 2;
    int screen=DefaultScreen(d);
    Window root=RootWindow(d,screen);
    int w=DisplayWidth(d,screen),h=DisplayHeight(d,screen);
    XImage* image=XCreateImage(d,DefaultVisual(d,screen),DefaultDepth(d,screen),
                               ZPixmap,0,nullptr,w,h,32,0);
    if(!image){XCloseDisplay(d);return 2;}
    image->data=static_cast<char*>(std::malloc(static_cast<size_t>(image->bytes_per_line)*h));
    if(!image->data){image->data=nullptr;XDestroyImage(image);XCloseDisplay(d);return 2;}
    uint32_t seed=0xA731B5C9u;
    for(int y=0;y<h;++y) for(int x=0;x<w;++x) {
        seed^=seed<<13;seed^=seed>>17;seed^=seed<<5;
        XPutPixel(image,x,y,
                  (static_cast<unsigned long>(seed)&(image->red_mask|image->green_mask|image->blue_mask)));
    }
    GC gc=XCreateGC(d,root,0,nullptr);
    XPutImage(d,root,gc,image,0,0,0,0,w,h);
    XSync(d,False);
    XFreeGC(d,gc);
    XDestroyImage(image);
    XCloseDisplay(d);
    std::cout<<"OK: tela de teste preenchida com pixels nao compressiveis.\n";
    return 0;
}
