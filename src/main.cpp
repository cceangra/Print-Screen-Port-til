// Print RC - capturador leve para X11, sem daemon antes de ser acionado.
// GPL-3.0-or-later
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/cursorfont.h>
#include <X11/keysym.h>
#include <cerrno>
#include <png.h>
#include "settings.hpp"
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

// Detecta apenas uma tecla durante a configuracao solicitada pelo usuario.
// Nao guarda teclas, nao cria processo residente e nao altera atalhos do desktop.
// XGrabKeyboard redireciona eventos para este processo durante no maximo 15 s.
int detect_print_key() {
    const char* displayName=std::getenv("DISPLAY");
    if (!displayName || !*displayName) {
        std::cerr<<"Print RC: DISPLAY indisponivel; nao posso ler Print no X11.\n";
        return 2;
    }
    Display* d=XOpenDisplay(nullptr);
    if (!d) {
        std::cerr<<"Print RC: nao consegui abrir o display X11 para ler a tecla.\n";
        return 2;
    }
    const Window root=DefaultRootWindow(d);
    // A janela de grab deve estar VISIVEL; a root do X11 sempre esta.
    // XSelectInput so registra eventos neste cliente, sem mudar atalhos globais.
    XSelectInput(d,root,KeyPressMask);
    XFlush(d);
    const int grab=XGrabKeyboard(d,root,False,GrabModeAsync,GrabModeAsync,CurrentTime);
    if (grab!=GrabSuccess) {
        std::cerr<<"Print RC: outro aplicativo controla o teclado. Nao pude verificar Print ("
                 <<grab<<").\n";

        XCloseDisplay(d);
        return 3;
    }
    std::cerr<<"Print RC: pressione a tecla PRINT SCREEN agora (Esc cancela).\n"
             <<"A leitura termina automaticamente apos 15 segundos.\n";
    std::cerr.flush();
    int result=4;
    const auto expires=Clock::now()+std::chrono::seconds(15);
    while (Clock::now()<expires) {
        while (XPending(d)) {
            XEvent event{};
            XNextEvent(d,&event);
            if (event.type!=KeyPress) continue;
            const KeySym key=XLookupKeysym(&event.xkey,0);
            if (key==XK_Escape) {
                std::cerr<<"Print RC: identificacao cancelada com Esc.\n";
                result=5;
                goto finished_key_detection;
            }
            if (key==XK_Print || key==XK_Sys_Req) {
                std::cout<<"PRINT_RC_KEY="<<(key==XK_Print?"Print":"Sys_Req")<<"\n";
                std::cout.flush();
                std::cerr<<"Print RC: tecla identificada: "
                         <<(key==XK_Print?"Print":"Sys_Req")
                         <<" (codigo fisico X11 "<<event.xkey.keycode<<").\n";
                result=0;
                goto finished_key_detection;
            }
            const char* name=XKeysymToString(key);
            std::cerr<<"Print RC: tecla lida: "<<(name?name:"desconhecida")
                     <<". Pressione PRINT SCREEN ou Esc.\n";
        }
        const int fd=ConnectionNumber(d);
        if (fd<0 || fd>=FD_SETSIZE) {
            std::cerr<<"Print RC: descritor X11 indisponivel.\n";
            result=3;
            break;
        }
        fd_set fds;
        FD_ZERO(&fds);
        FD_SET(fd,&fds);
        timeval wait{};
        wait.tv_sec=0;
        wait.tv_usec=250000;
        const int ready=select(fd+1,&fds,nullptr,nullptr,&wait);
        if (ready<0 && errno!=EINTR) {
            std::cerr<<"Print RC: falha ao aguardar tecla.\n";
            result=3;
            break;
        }
    }
    if (result==4) std::cerr<<"Print RC: tempo esgotado sem reconhecer PRINT SCREEN.\n";
finished_key_detection:
    XUngrabKeyboard(d,CurrentTime);
    XSync(d,False);
    XCloseDisplay(d);
    return result;
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
        if (arg=="--version") { std::cout<<"Print RC 0.4.7 (X11)\n";return 0; }
        if (arg=="--self-test") return self_test()?0:1;
        if (arg=="--detectar-print") return detect_print_key();
        if (arg=="--show-config") {
            PrintRcSettings options;
            if (!print_rc_load_settings(options)) return 2;
            std::cout << "Pasta das imagens: " << options.save_dir << "\n"
                      << "Copiar para Ctrl+V: " << (options.copy_clipboard ? "SIM" : "NAO") << "\n";
            return 0;
        }
        if (arg=="--help") {
            std::cout<<"Print RC: barra AREA / TELA (1 clique) / LAPIS (desenhar) / DESF / X. Esc cancela.\n"
                     <<"Uso: print-rc [--version|--help|--self-test|--show-config|--detectar-print]\n";
            return 0;
        }
        std::cerr<<"Parametro desconhecido. Use --help.\n";return 2;
    }
    PrintRcSettings options;
    if (!print_rc_load_settings(options)) return 2;
    if (!std::getenv("DISPLAY")) {std::cerr<<"Print RC requer uma sessao X11.\n";return 2;}
    Display* display=XOpenDisplay(nullptr);
    if (!display) {std::cerr<<"Print RC: falha ao abrir o display X11.\n";return 2;}
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
        std::cerr<<"Print RC: ja existe uma captura em andamento. Aguarde ou pressione Esc nela.\n";
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
    XImage* original=XGetImage(display,root,0,0,width,height,AllPlanes,ZPixmap);
    if (!original) {std::cerr<<"Print RC: nao foi possivel fotografar a tela.\n";close_display();return 3;}
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
    const char* buttons[]={"AREA","TELA","LAPIS","DESF","X"};
    XSetWindowAttributes attrs{};
    attrs.override_redirect=True;
    attrs.event_mask=ExposureMask|ButtonPressMask|ButtonReleaseMask|PointerMotionMask|KeyPressMask;
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
        std::cerr<<"Print RC: outro aplicativo capturou o mouse. Tente novamente.\n";
        XDestroyWindow(display,overlay);XFreeGC(display,gc);XFreeCursor(display,cross);
        XFreeCursor(display,pencil);XFreeCursor(display,arrow);
        XDestroyImage(dim);XDestroyImage(original);close_display();return 4;
    }
    int keyboard_grab=XGrabKeyboard(display,overlay,False,GrabModeAsync,GrabModeAsync,CurrentTime);
    if (keyboard_grab!=GrabSuccess) {
        // Sem o teclado exclusivo, Esc nao e confiavel. Nao manter overlay nem mouse capturado.
        std::cerr << "Print RC: nao foi possivel capturar o teclado X11 (codigo "
                  << keyboard_grab << "). Outro aplicativo pode estar usando a tecla.\n";
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
    if (!done) {XDestroyImage(original);close_display();return 0;}
    if(!strokes.empty()) annotate_image(original,strokes);
    std::vector<unsigned char> png=encode_png(original,chosen);
    XDestroyImage(original);
    if (png.empty()) {close_display();return 5;}
    const bool saved=print_rc_save_png(png,options.save_dir);
    if (!saved) {
        std::cerr<<"Print RC: nao foi possivel salvar o PNG na pasta escolhida.\n";
        std::cerr<<"A captura ainda podera ser colada com Ctrl+V, se essa opcao estiver ativa.\n";
    }
    if (!options.copy_clipboard) {
        close_display();
        return saved?0:6;
    }
    // Liberar bloqueio de captura antes de atender o clipboard:
    // novos prints podem ser feitos enquanto o primeiro PNG esta pronto para Ctrl+V.
    release_instance();
    Window owner=XCreateSimpleWindow(display,root,-10,-10,1,1,0,0,0);
    clipboard_loop(display,owner,std::move(png),
                   Clock::now()+std::chrono::seconds(kClipboardSeconds));
    XDestroyWindow(display,owner);
    close_display();
    return saved?0:6;
}
