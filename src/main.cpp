#include "ui/geometry.hpp"
#include "images/png.hpp"
#include "ui/drawing.hpp"
#include "clipboard/owner.hpp"
#include "input/keyboard.hpp"
#include "i18n/messages.hpp"
// Print RC - capturador leve para X11, sem daemon antes de ser acionado.
// GPL-3.0-or-later
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/cursorfont.h>
#include <X11/keysym.h>
#include <cerrno>
#if defined(__GLIBC__)
#include <malloc.h>
#endif
#include <png.h>
#include "settings.hpp"
#include "app/runtime.hpp"
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


#ifndef PRINT_RC_VERSION
#define PRINT_RC_VERSION "0.6.0-dev"
#endif

using namespace prc;

namespace {
using Clock = std::chrono::steady_clock;
constexpr int kClipboardSeconds = 1800;


unsigned long x_error_count=0;
int xerror(Display*, XErrorEvent* event) {
    ++x_error_count;
    // Uma janela de destino pode desaparecer durante uma transferencia INCR.
    if (event->error_code != BadWindow && event->error_code != BadMatch) {
        std::fprintf(stderr, prc_tr("native.001"), event->error_code, event->request_code);
    }
    return 0;
}

bool self_test() {
    png_image image{};
    image.version=PNG_IMAGE_VERSION;
    image.width=1;image.height=1;image.format=PNG_FORMAT_RGBA;
    unsigned char pixel[]={20,160,250,255};
    png_alloc_size_t size=0;
    bool ok=png_image_write_to_memory(&image,nullptr,&size,0,pixel,0,nullptr)!=0;
    png_image_free(&image);
    std::cout << (ok ? prc_tr("native.030"):prc_tr("native.031"));
    return ok;
}
}

int run_capture_app(int argc,char** argv) {
    bool probe_overlay=false;
    std::string readiness_nonce=std::to_string(getpid());
    if (argc>1) {
        std::string arg=argv[1];
        if (arg=="--probe-overlay") {
            probe_overlay=true;
            if(argc>2) readiness_nonce=argv[2];
            if(argc>3 || readiness_nonce.empty() || readiness_nonce.size()>128
               || readiness_nonce.find_first_not_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")!=std::string::npos) return 2;
        } else if (arg=="--version") { std::cout<<"Print RC " PRINT_RC_VERSION " (X11)\n";return 0; }
        if (arg=="--build-info") { std::cout<<"Print RC " PRINT_RC_VERSION "\n"<<prc_tr("native.build_info");return 0; }
        if (arg=="--self-test") return self_test()?0:1;
        if (arg=="--detectar-print") return detect_print_key();
        if (arg=="--verificar-tecla") {
            if(argc>3) {std::cerr<<prc_tr("native.invalid_key");return 2;}
            return inspect_print_grabs(argc==3?argv[2]:"Print");
        }
        if (arg=="--show-config") {
            PrintRcSettings options;
            if (!print_rc_load_settings(options)) return 2;
            std::cout << prc_tr("native.032") << options.save_dir << "\n"
                      << prc_tr("native.033") << (options.copy_clipboard ? prc_tr("common.yes") : prc_tr("common.no")) << "\n";
            return 0;
        }
        if (arg=="--help") {
            std::cout<<prc_tr("native.034")
                     <<prc_tr("native.035");
            return 0;
        }
        if (!probe_overlay) { std::cerr<<prc_tr("native.036");return 2; }
    }
    PrintRcSettings options;
    if (!print_rc_load_settings(options)) return 2;
    if (!std::getenv("DISPLAY")) {std::cerr<<prc_tr("native.037");return 2;}
    Display* display=XOpenDisplay(nullptr);
    if (!display) {std::cerr<<prc_tr("native.038");return 2;}
    if(ConnectionNumber(display)<0 || ConnectionNumber(display)>=FD_SETSIZE) {
        std::cerr<<prc_tr("native.022");XCloseDisplay(display);return 2;
    }
    print_rc_stage('X');
    XSetErrorHandler(xerror);
    // Um unico capturador pode controlar o mouse/teclado por vez.
    // Selecao proprietaria X11: atomica sob XGrabServer, liberada pelo servidor
    // mesmo em encerramento abrupto. NAO cria arquivos ou servicos externos.
    const Window root_lock=DefaultRootWindow(display);
    const Atom instance_atom=XInternAtom(display,"_PRINT_RC_CAPTURING_INSTANCE",False);
    Window instance_window=XCreateSimpleWindow(display,root_lock,-10,-10,1,1,0,0,0);
    XGrabServer(display);
    const bool already_running=XGetSelectionOwner(display,instance_atom)!=None;
    if (!already_running) XSetSelectionOwner(display,instance_atom,instance_window,CurrentTime);
    XUngrabServer(display);
    XSync(display,False);
    if (already_running || XGetSelectionOwner(display,instance_atom)!=instance_window) {
        std::cerr<<prc_tr("native.039");
        XDestroyWindow(display,instance_window);
        XCloseDisplay(display);
        return 7;
    }
    auto release_instance=[&]() {
        if(instance_window!=None) {
            if(XGetSelectionOwner(display,instance_atom)==instance_window)
                XSetSelectionOwner(display,instance_atom,None,CurrentTime);
            XDestroyWindow(display,instance_window);
            instance_window=None;
        }
    };
    auto close_display=[&]() {
        release_instance();
        XCloseDisplay(display);
    };
    int screen=DefaultScreen(display);
    Window root=RootWindow(display,screen);
    const int width=DisplayWidth(display,screen), height=DisplayHeight(display,screen);
    if(width<=0 || height<=0 || width>32767 || height>32767
       || static_cast<uint64_t>(width)*height>100000000ULL) {
        std::cerr<<prc_tr("native.040");
        close_display();return 3;
    }
    XImage* original=XGetImage(display,root,0,0,width,height,AllPlanes,ZPixmap);
    if (!original) {std::cerr<<prc_tr("native.041");close_display();return 3;}
    if(!original->data || original->width!=width || original->height!=height
       || original->bytes_per_line<=0 || (original->bits_per_pixel!=16 && original->bits_per_pixel!=24 && original->bits_per_pixel!=32)
       || !original->red_mask || !original->green_mask || !original->blue_mask
       || (original->red_mask&original->green_mask) || (original->red_mask&original->blue_mask)
       || (original->green_mask&original->blue_mask)
       || static_cast<uint64_t>(original->bytes_per_line)*8 < static_cast<uint64_t>(width)*original->bits_per_pixel
       || static_cast<uint64_t>(original->bytes_per_line)*height>std::numeric_limits<size_t>::max()) {
        std::cerr<<prc_tr("native.042");
        XDestroyImage(original);close_display();return 3;
    }
    const auto bytes=static_cast<size_t>(original->bytes_per_line)*height;
    char* data=static_cast<char*>(std::malloc(bytes));
    if (!data) {XDestroyImage(original);close_display();return 3;}
    std::memcpy(data,original->data,bytes);
    XImage* dim=XCreateImage(display,DefaultVisual(display,screen),DefaultDepth(display,screen),
                             ZPixmap,0,data,width,height,32,original->bytes_per_line);
    if (!dim) {std::free(data);XDestroyImage(original);close_display();return 3;}
    // Caminho rapido para o formato comum X11 BGRA (32bpp, little-endian).
    // Evita dois acessos XGetPixel/XPutPixel por pixel em CPUs antigas.
    const bool fast_pixels = original->bits_per_pixel==32 && dim->bits_per_pixel==32
        && original->byte_order==LSBFirst && dim->byte_order==LSBFirst
        && original->red_mask==0x00ff0000UL
        && original->green_mask==0x0000ff00UL && original->blue_mask==0x000000ffUL;
    if(fast_pixels) {
        for(int y=0;y<height;++y) {
            auto* row=reinterpret_cast<unsigned char*>(dim->data+
                            static_cast<size_t>(y)*dim->bytes_per_line);
            for(int x=0;x<width;++x) {
                unsigned char* pixel=row+static_cast<size_t>(x)*4;
                pixel[0]=static_cast<unsigned char>((static_cast<unsigned>(pixel[0])*62)/100);
                pixel[1]=static_cast<unsigned char>((static_cast<unsigned>(pixel[1])*62)/100);
                pixel[2]=static_cast<unsigned char>((static_cast<unsigned>(pixel[2])*62)/100);
            }
        }
    } else {
        for (int y=0;y<height;++y) for(int x=0;x<width;++x) {
            unsigned long p=XGetPixel(original,x,y);
            XPutPixel(dim,x,y,darken(p,original->red_mask,original->green_mask,original->blue_mask));
        }
    }
    // Barra de ferramentas curta: Area | Tela | Lapis | Desfazer | Fechar.
    // Nao exige Qt/GTK, icones externos, servicos de fundo ou arquivos extras.
    constexpr int barH=44,btnGap=6,barPad=8;
    const int barW=std::min(280,std::max(1,width-8));
    const int barY=height>60?12:0;
    const int btnW=std::max(1,(barW-2*barPad-4*btnGap)/5);
    const int barX=std::max(0,(width-barW)/2);
    const std::string button_text[]={prc_x11_label("overlay.area"),prc_x11_label("overlay.screen"),
        prc_x11_label("overlay.pen"),prc_x11_label("overlay.undo"),prc_x11_label("overlay.close")};
    const char* buttons[]={button_text[0].c_str(),button_text[1].c_str(),button_text[2].c_str(),button_text[3].c_str(),button_text[4].c_str()};
    XSetWindowAttributes attrs{};
    attrs.override_redirect=True;
    attrs.event_mask=ExposureMask|ButtonPressMask|ButtonReleaseMask|PointerMotionMask|KeyPressMask;
    const auto startup_errors=x_error_count;
    Window overlay=XCreateWindow(display,root,0,0,width,height,0,CopyFromParent,InputOutput,
                                 CopyFromParent,CWOverrideRedirect|CWEventMask,&attrs);
    GC gc=XCreateGC(display,overlay,0,nullptr);
    XColor color{},unused{};
    const Colormap cmap=DefaultColormap(display,screen);
    auto colorNamed=[&](const char* name,unsigned long fallback) {
        if(XAllocNamedColor(display,cmap,name,&color,&unused)) return color.pixel;
        return fallback;
    };
    const unsigned long border=colorNamed("#37B4FF",WhitePixel(display,screen));
    const unsigned long panel=colorNamed("#141925",BlackPixel(display,screen));
    const unsigned long active=colorNamed("#245686",border);
    const unsigned long muted=colorNamed("#303949",panel);
    const unsigned long white=WhitePixel(display,screen);
    Cursor cross=XCreateFontCursor(display,XC_crosshair);
    Cursor pencil=XCreateFontCursor(display,XC_pencil);
    Cursor arrow=XCreateFontCursor(display,XC_left_ptr);
    XDefineCursor(display,overlay,cross);
    XMapRaised(display,overlay);
    XFlush(display);
    int pointer_grab=XGrabPointer(display,overlay,False,ButtonPressMask|ButtonReleaseMask|PointerMotionMask,
                                  GrabModeAsync,GrabModeAsync,None,cross,CurrentTime);
    if (pointer_grab!=GrabSuccess) {
        std::cerr<<prc_tr("native.043");
        XDestroyWindow(display,overlay);XFreeGC(display,gc);XFreeCursor(display,cross);
        XFreeCursor(display,pencil);XFreeCursor(display,arrow);
        XDestroyImage(dim);XDestroyImage(original);close_display();return 4;
    }
    int keyboard_grab=XGrabKeyboard(display,overlay,False,GrabModeAsync,GrabModeAsync,CurrentTime);
    if (keyboard_grab!=GrabSuccess) {
        // Sem o teclado exclusivo, Esc nao e confiavel. Nao manter overlay nem mouse capturado.
        std::cerr << prc_tr("native.044")
                  << keyboard_grab << prc_tr("native.045");
        XUngrabPointer(display,CurrentTime);
        XUnmapWindow(display,overlay);
        XDestroyWindow(display,overlay);
        XFreeGC(display,gc);
        XFreeCursor(display,cross); XFreeCursor(display,pencil); XFreeCursor(display,arrow);
        XDestroyImage(dim);
        XDestroyImage(original);
        XSync(display,False);
        close_display();
        return 4;
    }
    enum class Tool { Area, Pencil };
    Tool tool=Tool::Area;
    InkDrawing strokes;
    bool drawing=false,selecting=false,done=false,cancel=false;
    int begin_x=0,begin_y=0;
    Rect previous{},chosen{};
    const auto selectionDeadline=Clock::now()+std::chrono::seconds(120);
    auto in_bar=[&](int x,int y) {
        return x>=barX && x<barX+barW && y>=barY && y<barY+barH;
    };
    auto bar_button=[&](int x,int y) {
        if(!in_bar(x,y)) return -1;
        for(int i=0;i<5;++i) {
            int left=barX+barPad+i*(btnW+btnGap);
            if(x>=left && x<left+btnW) return i;
        }
        return -1;
    };
    auto paint_toolbar=[&]() {
        // Cantos arredondados nativos Xlib, sem dependencia de PNG/SVG ou Qt.
        const int r=10;
        XSetForeground(display,gc,panel);
        XFillRectangle(display,overlay,gc,barX+r,barY,barW-2*r,barH);
        XFillRectangle(display,overlay,gc,barX,barY+r,barW,barH-2*r);
        XFillArc(display,overlay,gc,barX,barY,2*r,2*r,90*64,90*64);
        XFillArc(display,overlay,gc,barX+barW-2*r,barY,2*r,2*r,0,90*64);
        XFillArc(display,overlay,gc,barX,barY+barH-2*r,2*r,2*r,180*64,90*64);
        XFillArc(display,overlay,gc,barX+barW-2*r,barY+barH-2*r,2*r,2*r,270*64,90*64);
        XSetForeground(display,gc,border);
        XDrawLine(display,overlay,gc,barX+r,barY,barX+barW-r,barY);
        XDrawLine(display,overlay,gc,barX+r,barY+barH-1,barX+barW-r,barY+barH-1);
        XDrawLine(display,overlay,gc,barX,barY+r,barX,barY+barH-r);
        XDrawLine(display,overlay,gc,barX+barW-1,barY+r,barX+barW-1,barY+barH-r);
        for(int i=0;i<5;++i) {
            const int bx=barX+barPad+i*(btnW+btnGap);
            const bool selected=(i==0&&tool==Tool::Area)||(i==2&&tool==Tool::Pencil);
            XSetForeground(display,gc,selected?active:muted);
            XFillRectangle(display,overlay,gc,bx,barY+5,btnW,34);
            XSetForeground(display,gc,white);
            const int cx=bx+btnW/2, cy=barY+16;
            switch(i) {
                case 0: { // Retangulo tracejado
                    XSetLineAttributes(display,gc,1,LineOnOffDash,CapButt,JoinMiter);
                    XDrawRectangle(display,overlay,gc,cx-9,cy-6,18,12);
                    XSetLineAttributes(display,gc,1,LineSolid,CapButt,JoinMiter);
                    break;
                }
                case 1: { // Monitor/tela completa
                    XDrawRectangle(display,overlay,gc,cx-10,cy-7,20,13);
                    XDrawLine(display,overlay,gc,cx,cy+6,cx,cy+9);
                    XDrawLine(display,overlay,gc,cx-6,cy+9,cx+6,cy+9);
                    break;
                }
                case 2: { // Lapis diagonal
                    XSetLineAttributes(display,gc,3,LineSolid,CapRound,JoinRound);
                    XDrawLine(display,overlay,gc,cx-7,cy+6,cx+7,cy-7);
                    XSetLineAttributes(display,gc,1,LineSolid,CapButt,JoinMiter);
                    XDrawLine(display,overlay,gc,cx-10,cy+7,cx-6,cy+6);
                    break;
                }
                case 3: { // Desfazer
                    XDrawArc(display,overlay,gc,cx-8,cy-7,16,13,20*64,260*64);
                    XDrawLine(display,overlay,gc,cx-8,cy-4,cx-11,cy+1);
                    XDrawLine(display,overlay,gc,cx-8,cy-4,cx-3,cy-2);
                    break;
                }
                case 4:
                    XDrawLine(display,overlay,gc,cx-6,cy-6,cx+6,cy+6);
                    XDrawLine(display,overlay,gc,cx+6,cy-6,cx-6,cy+6);
                    break;
            }
            const int len=static_cast<int>(std::strlen(buttons[i]));
            XDrawString(display,overlay,gc,bx+std::max(1,(btnW-len*6)/2),
                        barY+35,buttons[i],len);
        }
    };
    auto paint_strokes=[&](Rect dirty) {
        XSetForeground(display,gc,border);
        XSetLineAttributes(display,gc,3,LineSolid,CapRound,JoinRound);
        const Rect visible=expand(dirty,3,width,height);
        auto intersects=[&](InkPoint a,InkPoint b) {
            return std::max(a.x,b.x)>=visible.x && std::min(a.x,b.x)<visible.x+visible.w
                && std::max(a.y,b.y)>=visible.y && std::min(a.y,b.y)<visible.y+visible.h;
        };
        for(const auto& line:strokes) {
            if(line.empty()) continue;
            if(line.size()==1) {
                if(intersects(line[0],line[0]))
                    XFillArc(display,overlay,gc,line[0].x-2,line[0].y-2,4,4,0,360*64);
            } else for(size_t i=1;i<line.size();++i) {
                if(intersects(line[i-1],line[i]))
                    XDrawLine(display,overlay,gc,line[i-1].x,line[i-1].y,line[i].x,line[i].y);
            }
        }
        XSetLineAttributes(display,gc,1,LineSolid,CapButt,JoinMiter);
    };
    auto redraw=[&](Rect dirty,Rect selection) {
        if(dirty.w<=0||dirty.h<=0) return;
        XPutImage(display,overlay,gc,dim,dirty.x,dirty.y,dirty.x,dirty.y,dirty.w,dirty.h);
        if(selection.w>0&&selection.h>0) {
            XPutImage(display,overlay,gc,original,selection.x,selection.y,
                      selection.x,selection.y,selection.w,selection.h);
            XSetForeground(display,gc,border);
            XSetLineAttributes(display,gc,2,LineSolid,CapButt,JoinMiter);
            XDrawRectangle(display,overlay,gc,selection.x,selection.y,
                           static_cast<unsigned>(selection.w-1),static_cast<unsigned>(selection.h-1));
            char sizeText[48]{};
            std::snprintf(sizeText,sizeof(sizeText),"%d x %d",selection.w,selection.h);
            int textX=clampi(selection.x+selection.w-75,0,std::max(0,width-78));
            int textY=clampi(selection.y+selection.h+18,18,height-4);
            XDrawString(display,overlay,gc,textX,textY,sizeText,std::strlen(sizeText));
        }
        paint_strokes(dirty);
        paint_toolbar();
        XFlush(display);
    };
    redraw({0,0,width,height},{});
    XSync(display,False);
    XWindowAttributes mapped{};
    const bool overlay_ready=XGetWindowAttributes(display,overlay,&mapped)
        && mapped.map_state==IsViewable && x_error_count==startup_errors;
    if(overlay_ready) {
        const Atom ready_atom=XInternAtom(display,"_PRINT_RC_READY",False);
        XChangeProperty(display,overlay,ready_atom,XA_STRING,8,PropModeReplace,
                        reinterpret_cast<const unsigned char*>(readiness_nonce.data()),
                        static_cast<int>(readiness_nonce.size()));
        const char* locale=prc_portuguese()?"pt-BR":"en-US";
        XChangeProperty(display,overlay,XInternAtom(display,"_PRINT_RC_LANGUAGE",False),XA_STRING,8,PropModeReplace,
                        reinterpret_cast<const unsigned char*>(locale),5);
        XSync(display,False);
        if(x_error_count==startup_errors) {
            print_rc_stage('R');
            if(probe_overlay) std::cout<<"PRINT_RC_OVERLAY_READY="<<readiness_nonce<<"\n"<<std::flush;
        }
    }
    const bool startup_failed=!overlay_ready || x_error_count!=startup_errors;
    if(startup_failed) std::cerr<<prc_tr("native.046");
    if(probe_overlay || startup_failed) cancel=true;
    auto set_cursor=[&](int x,int y) {
        Cursor desired=in_bar(x,y)?arrow:(tool==Tool::Pencil?pencil:cross);
        XChangeActivePointerGrab(display,ButtonPressMask|ButtonReleaseMask|PointerMotionMask,
                                 desired,CurrentTime);
    };
    while(!done && !cancel && Clock::now()<selectionDeadline) {
        // XNextEvent sozinho pode bloquear para sempre: esperar no FD com limite.
        if(!XPending(display)) {
            fd_set fds;
            FD_ZERO(&fds);
            const int fd=ConnectionNumber(display);
            FD_SET(fd,&fds);
            auto remaining=std::chrono::duration_cast<std::chrono::milliseconds>(
                selectionDeadline-Clock::now()).count();
            if(remaining<=0) break;
            timeval tv{};
            long ms=static_cast<long>(std::min<int64_t>(remaining,1000));
            tv.tv_sec=ms/1000; tv.tv_usec=(ms%1000)*1000;
            int ready=select(fd+1,&fds,nullptr,nullptr,&tv);
            if(ready<=0) continue;
        }
        XEvent event{};
        XNextEvent(display,&event);
        if (event.type==Expose && event.xexpose.count==0) {
            redraw({0,0,width,height},previous);
        } else if(event.type==ButtonPress) {
            if(event.xbutton.button==Button3) {cancel=true;break;}
            if(event.xbutton.button!=Button1) continue;
            int hit=bar_button(event.xbutton.x,event.xbutton.y);
            if(hit>=0) {
                drawing=false;selecting=false;
                previous={};
                switch(hit) {
                    case 0: tool=Tool::Area; break;
                    case 1: chosen={0,0,width,height};done=true;break;
                    case 2: tool=Tool::Pencil;break;
                    case 3: if(!strokes.empty()) strokes.pop_back();break;
                    case 4: cancel=true;break;
                }
                if(!done&&!cancel) redraw({0,0,width,height},{});
                continue;
            }
            if(tool==Tool::Pencil) {
                drawing=true;
                strokes.emplace_back();
                strokes.back().push_back({clampi(event.xbutton.x,0,width-1),
                                          clampi(event.xbutton.y,0,height-1)});
                XSetForeground(display,gc,border);
                XFillArc(display,overlay,gc,event.xbutton.x-2,event.xbutton.y-2,4,4,0,360*64);
                XFlush(display);
            } else {
                selecting=true;
                begin_x=event.xbutton.x;
                begin_y=event.xbutton.y;
                previous={};
            }
        } else if(event.type==MotionNotify) {
            while(XCheckTypedWindowEvent(display,overlay,MotionNotify,&event)) {}
            set_cursor(event.xmotion.x,event.xmotion.y);
            if(drawing && tool==Tool::Pencil && !strokes.empty()) {
                InkPoint next{clampi(event.xmotion.x,0,width-1),
                              clampi(event.xmotion.y,0,height-1)};
                auto& line=strokes.back();
                InkPoint previousPoint=line.back();
                if(next.x!=previousPoint.x || next.y!=previousPoint.y) {
                    line.push_back(next);
                    XSetForeground(display,gc,border);
                    XSetLineAttributes(display,gc,3,LineSolid,CapRound,JoinRound);
                    XDrawLine(display,overlay,gc,previousPoint.x,previousPoint.y,next.x,next.y);
                    XFlush(display);
                }
            } else if(selecting && tool==Tool::Area) {
                Rect next=rect_between(begin_x,begin_y,event.xmotion.x,event.xmotion.y,width,height);
                redraw(unite(previous,next,width,height),next);
                previous=next;
            }
        } else if(event.type==ButtonRelease && event.xbutton.button==Button1) {
            if(drawing) {
                drawing=false;
            } else if(selecting) {
                chosen=rect_between(begin_x,begin_y,event.xbutton.x,event.xbutton.y,width,height);
                selecting=false;
                if(chosen.w>=3 && chosen.h>=3) done=true;
                else {redraw(expand(previous,4,width,height),{});previous={};}
            }
        } else if(event.type==KeyPress) {
            KeySym key=XLookupKeysym(&event.xkey,0);
            if(key==XK_Escape) cancel=true;
        }
    }
    XUngrabPointer(display,CurrentTime);
    XUngrabKeyboard(display,CurrentTime);
    XUnmapWindow(display,overlay);
    XDestroyWindow(display,overlay);
    XFreeGC(display,gc);XFreeCursor(display,cross);
    XFreeCursor(display,pencil);XFreeCursor(display,arrow);
    XDestroyImage(dim);
    if (!done) {XDestroyImage(original);close_display();return startup_failed?4:0;}
    if(!strokes.empty()) annotate_image(original,strokes);
    std::vector<unsigned char> png=encode_png(original,chosen);
    XDestroyImage(original);
    if (png.empty()) {close_display();return 5;}
    const bool saved=print_rc_save_png(png,options.save_dir);
    if (!saved) {
        print_rc_stage('S');
        std::cerr<<prc_tr("native.047");
        std::cerr<<prc_tr("native.048");
    }
    if (!options.copy_clipboard) {
        close_display();
        return saved?0:6;
    }
    // XPutImage may retain a screen-sized Xlib transport scratch buffer until
    // XCloseDisplay. Start clipboard ownership with a fresh, small connection
    // instead of keeping the capture connection's caches resident for 30 min.
    close_display();
    decltype(strokes)().swap(strokes);
#if defined(__GLIBC__)
    // Freed capture/transport buffers can remain in glibc's arena. Return free
    // pages once before a long clipboard wait; do not change allocator tunables.
    malloc_trim(0);
#endif
    display=XOpenDisplay(nullptr);
    if(!display) {std::cerr<<prc_tr("native.004");return saved?8:6;}
    const Window clipboard_root=DefaultRootWindow(display);
    Window owner=XCreateSimpleWindow(display,clipboard_root,-10,-10,1,1,0,0,0);
    const bool copied=clipboard_loop(display,owner,std::move(png),
                   Clock::now()+std::chrono::seconds(kClipboardSeconds));
    XDestroyWindow(display,owner);
    XCloseDisplay(display);
    return saved?(copied?0:8):6;
}

int main(int argc,char** argv) {
    try {return run_capture_app(argc,argv);}
    catch(const std::bad_alloc&) {std::cerr<<prc_tr("native.allocation_failed");return 70;}
    catch(const std::exception& error) {std::cerr<<prc_tr("native.operation_failed")<<error.what()<<"\n";return 70;}
}
