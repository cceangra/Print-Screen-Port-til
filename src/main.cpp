// Print RC - capturador leve para X11, sem daemon antes de ser acionado.
// GPL-3.0-or-later
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/cursorfont.h>
#include <png.h>
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <limits>
#include <string>
#include <vector>
#include <sys/select.h>
#include <unistd.h>

namespace {
using Clock = std::chrono::steady_clock;
constexpr int kClipboardSeconds = 1800;
constexpr size_t kChunkSize = 64 * 1024;

int xerror(Display*, XErrorEvent* event) {
    // Uma janela de destino pode desaparecer durante uma transferencia INCR.
    if (event->error_code != BadWindow && event->error_code != BadMatch) {
        std::fprintf(stderr, "Print RC: erro X11: %u (pedido %u)\n", event->error_code, event->request_code);
    }
    return 0;
}

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
    if (r.w<=0||r.h<=0) return {};
    if (static_cast<uint64_t>(r.w)*r.h > 100000000ULL) return {};
    std::vector<unsigned char> pixels(static_cast<size_t>(r.w)*r.h*4);
    auto extract=[](unsigned long p,unsigned long mask)->unsigned char {
        if (!mask) return 0;
        int shift=0; while (((mask>>shift)&1UL)==0 && shift<63) ++shift;
        unsigned long maxval=mask>>shift;
        return static_cast<unsigned char>((((p&mask)>>shift)*255UL+maxval/2)/maxval);
    };
    for (int y=0;y<r.h;++y) {
        for (int x=0;x<r.w;++x) {
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
        std::cerr << "Print RC: erro ao comprimir PNG: " << image.message << "\n";
        png_image_free(&image);
        return {};
    }
    std::vector<unsigned char> result(static_cast<size_t>(size));
    if (!png_image_write_to_memory(&image,result.data(),&size,0,pixels.data(),0,nullptr)) {
        std::cerr << "Print RC: erro ao gerar PNG: " << image.message << "\n";
        png_image_free(&image);
        return {};
    }
    result.resize(static_cast<size_t>(size));
    png_image_free(&image);
    return result;
}

struct Transfer { Window window; Atom property; size_t offset; };
void clipboard_loop(Display* display, Window owner, std::vector<unsigned char> png,
                    Clock::time_point expires) {
    const Atom clipboard=XInternAtom(display,"CLIPBOARD",False);
    const Atom targets=XInternAtom(display,"TARGETS",False);
    const Atom pngAtom=XInternAtom(display,"image/png",False);
    const Atom incr=XInternAtom(display,"INCR",False);
    XSetSelectionOwner(display,clipboard,owner,CurrentTime);
    XFlush(display);
    if (XGetSelectionOwner(display,clipboard)!=owner) {
        std::cerr<<"Print RC: nao foi possivel copiar para o clipboard.\n";
        return;
    }
    std::cout<<"Print RC: imagem copiada. Ctrl+V disponivel por ate 30 minutos.\n";
    std::vector<Transfer> transfers;
    while (Clock::now()<expires) {
        while (XPending(display)) {
            XEvent e{};
            XNextEvent(display,&e);
            if (e.type==SelectionClear && e.xselectionclear.selection==clipboard) return;
            if (e.type==SelectionRequest && e.xselectionrequest.selection==clipboard) {
                const auto& request=e.xselectionrequest;
                Atom property=request.property==None ? request.target : request.property;
                bool supported=false;
                if (request.target==targets) {
                    Atom list[2]={targets,pngAtom};
                    XChangeProperty(display,request.requestor,property,XA_ATOM,32,PropModeReplace,
                                    reinterpret_cast<unsigned char*>(list),2);
                    supported=true;
                } else if (request.target==pngAtom) {
                    if (png.size()<=kChunkSize) {
                        XChangeProperty(display,request.requestor,property,pngAtom,8,PropModeReplace,
                                        png.data(),static_cast<int>(png.size()));
                    } else {
                        XSelectInput(display,request.requestor,PropertyChangeMask);
                        unsigned long count=static_cast<unsigned long>(png.size());
                        XChangeProperty(display,request.requestor,property,incr,32,PropModeReplace,
                                        reinterpret_cast<unsigned char*>(&count),1);
                        transfers.push_back({request.requestor,property,0});
                    }
                    supported=true;
                }
                XEvent reply{};
                reply.xselection.type=SelectionNotify;
                reply.xselection.display=display;
                reply.xselection.requestor=request.requestor;
                reply.xselection.selection=clipboard;
                reply.xselection.target=request.target;
                reply.xselection.property=supported ? property : None;
                reply.xselection.time=request.time;
                XSendEvent(display,request.requestor,False,0,&reply);
                XFlush(display);
            } else if (e.type==PropertyNotify && e.xproperty.state==PropertyDelete) {
                for (auto it=transfers.begin();it!=transfers.end();) {
                    if (it->window!=e.xproperty.window || it->property!=e.xproperty.atom) { ++it;continue; }
                    size_t length=std::min(kChunkSize,png.size()-it->offset);
                    XChangeProperty(display,it->window,it->property,pngAtom,8,PropModeReplace,
                                    length ? png.data()+it->offset : nullptr,static_cast<int>(length));
                    it->offset+=length;
                    if (!length) it=transfers.erase(it);
                    else ++it;
                    XFlush(display);
                    break;
                }
            }
        }
        auto remaining=std::chrono::duration_cast<std::chrono::milliseconds>(expires-Clock::now()).count();
        if (remaining<=0) break;
        // Sono bloqueante sem polling constante de CPU.
        fd_set readfds;
        FD_ZERO(&readfds);
        int fd=ConnectionNumber(display);
        FD_SET(fd,&readfds);
        timeval timeout{};
        long wait_ms=static_cast<long>(std::min<int64_t>(remaining,1000));
        timeout.tv_sec=wait_ms/1000;
        timeout.tv_usec=(wait_ms%1000)*1000;
        select(fd+1,&readfds,nullptr,nullptr,&timeout);
    }
}

bool self_test() {
    png_image image{};
    image.version=PNG_IMAGE_VERSION;
    image.width=1;image.height=1;image.format=PNG_FORMAT_RGBA;
    unsigned char pixel[]={20,160,250,255};
    png_alloc_size_t size=0;
    bool ok=png_image_write_to_memory(&image,nullptr,&size,0,pixel,0,nullptr)!=0;
    png_image_free(&image);
    std::cout << (ok ? "OK: libpng funcionando\n":"ERRO: libpng\n");
    return ok;
}
}

int main(int argc,char** argv) {
    if (argc>1) {
        std::string arg=argv[1];
        if (arg=="--version") { std::cout<<"Print RC 0.1.0 (X11)\n";return 0; }
        if (arg=="--self-test") return self_test()?0:1;
        if (arg=="--help") {
            std::cout<<"Print RC: selecione com mouse; Esc cancela; Ctrl+V cola PNG.\n"
                     <<"Uso: print-rc [--version|--help|--self-test]\n";
            return 0;
        }
        std::cerr<<"Parametro desconhecido. Use --help.\n";return 2;
    }
    const auto expires=Clock::now()+std::chrono::seconds(kClipboardSeconds);
    if (!std::getenv("DISPLAY")) {std::cerr<<"Print RC requer uma sessao X11.\n";return 2;}
    Display* display=XOpenDisplay(nullptr);
    if (!display) {std::cerr<<"Print RC: falha ao abrir o display X11.\n";return 2;}
    XSetErrorHandler(xerror);
    int screen=DefaultScreen(display);
    Window root=RootWindow(display,screen);
    const int width=DisplayWidth(display,screen), height=DisplayHeight(display,screen);
    XImage* original=XGetImage(display,root,0,0,width,height,AllPlanes,ZPixmap);
    if (!original) {std::cerr<<"Print RC: nao foi possivel fotografar a tela.\n";XCloseDisplay(display);return 3;}
    const auto bytes=static_cast<size_t>(original->bytes_per_line)*height;
    char* data=static_cast<char*>(std::malloc(bytes));
    if (!data) {XDestroyImage(original);XCloseDisplay(display);return 3;}
    std::memcpy(data,original->data,bytes);
    XImage* dim=XCreateImage(display,DefaultVisual(display,screen),DefaultDepth(display,screen),
                             ZPixmap,0,data,width,height,32,original->bytes_per_line);
    if (!dim) {std::free(data);XDestroyImage(original);XCloseDisplay(display);return 3;}
    for (int y=0;y<height;++y) for(int x=0;x<width;++x) {
        unsigned long p=XGetPixel(original,x,y);
        XPutPixel(dim,x,y,darken(p,original->red_mask,original->green_mask,original->blue_mask));
    }
    XSetWindowAttributes attrs{};
    attrs.override_redirect=True;
    attrs.event_mask=ExposureMask|ButtonPressMask|ButtonReleaseMask|PointerMotionMask|KeyPressMask;
    Window overlay=XCreateWindow(display,root,0,0,width,height,0,CopyFromParent,InputOutput,
                                 CopyFromParent,CWOverrideRedirect|CWEventMask,&attrs);
    GC gc=XCreateGC(display,overlay,0,nullptr);
    XColor color{},unused{};
    unsigned long border=WhitePixel(display,screen);
    if (XAllocNamedColor(display,DefaultColormap(display,screen),"#37B4FF",&color,&unused)) border=color.pixel;
    Cursor cross=XCreateFontCursor(display,XC_crosshair);
    XDefineCursor(display,overlay,cross);
    XMapRaised(display,overlay);
    XFlush(display);
    int pointer_grab=XGrabPointer(display,overlay,False,ButtonPressMask|ButtonReleaseMask|PointerMotionMask,
                                  GrabModeAsync,GrabModeAsync,None,cross,CurrentTime);
    if (pointer_grab!=GrabSuccess) {
        std::cerr<<"Print RC: outro aplicativo capturou o mouse. Tente novamente.\n";
        XDestroyWindow(display,overlay);XFreeGC(display,gc);XFreeCursor(display,cross);
        XDestroyImage(dim);XDestroyImage(original);XCloseDisplay(display);return 4;
    }
    int keyboard_grab=XGrabKeyboard(display,overlay,False,GrabModeAsync,GrabModeAsync,CurrentTime);
    auto redraw=[&](Rect dirty,Rect selection) {
        if (dirty.w>0&&dirty.h>0) {
            XPutImage(display,overlay,gc,dim,dirty.x,dirty.y,dirty.x,dirty.y,dirty.w,dirty.h);
            if(selection.w>0&&selection.h>0) {
                XPutImage(display,overlay,gc,original,selection.x,selection.y,
                          selection.x,selection.y,selection.w,selection.h);
                XSetForeground(display,gc,border);
                XSetLineAttributes(display,gc,2,LineSolid,CapButt,JoinMiter);
                XDrawRectangle(display,overlay,gc,selection.x,selection.y,
                               static_cast<unsigned>(selection.w-1),static_cast<unsigned>(selection.h-1));
            }
            XFlush(display);
        }
    };
    redraw({0,0,width,height},{});
    bool selecting=false,done=false,cancel=false;
    int begin_x=0,begin_y=0,mouse_x=0,mouse_y=0;
    Rect previous{},chosen{};
    while(!done && !cancel && Clock::now()<expires) {
        XEvent event{};
        XNextEvent(display,&event);
        if (event.type==Expose && event.xexpose.count==0) {
            redraw({0,0,width,height},previous);
        } else if(event.type==ButtonPress) {
            if(event.xbutton.button==Button3) {cancel=true;break;}
            if(event.xbutton.button==Button1) {
                selecting=true;begin_x=mouse_x=event.xbutton.x;begin_y=mouse_y=event.xbutton.y;
                previous={};
            }
        } else if(event.type==MotionNotify && selecting) {
            // Descartar movimentos obsoletos para desenhar apenas a posicao mais nova.
            while(XCheckTypedWindowEvent(display,overlay,MotionNotify,&event)) {}
            mouse_x=event.xmotion.x;mouse_y=event.xmotion.y;
            Rect next=rect_between(begin_x,begin_y,mouse_x,mouse_y,width,height);
            redraw(unite(previous,next,width,height),next);
            previous=next;
        } else if(event.type==ButtonRelease && selecting && event.xbutton.button==Button1) {
            chosen=rect_between(begin_x,begin_y,event.xbutton.x,event.xbutton.y,width,height);
            if(chosen.w>=3 && chosen.h>=3) done=true;
            else { selecting=false;redraw(expand(previous,4,width,height),{}); previous={}; }
        } else if(event.type==KeyPress) {
            KeySym key=XLookupKeysym(&event.xkey,0);
            if(key==XK_Escape) cancel=true;
        }
    }
    XUngrabPointer(display,CurrentTime);
    if (keyboard_grab==GrabSuccess) XUngrabKeyboard(display,CurrentTime);
    XUnmapWindow(display,overlay);
    XDestroyWindow(display,overlay);
    XFreeGC(display,gc);XFreeCursor(display,cross);
    XDestroyImage(dim);
    if (!done) {XDestroyImage(original);XCloseDisplay(display);return 0;}
    std::vector<unsigned char> png=encode_png(original,chosen);
    XDestroyImage(original);
    if (png.empty()) {XCloseDisplay(display);return 5;}
    Window owner=XCreateSimpleWindow(display,root,-10,-10,1,1,0,0,0);
    clipboard_loop(display,owner,std::move(png),expires);
    XDestroyWindow(display,owner);
    XCloseDisplay(display);
    return 0;
}
