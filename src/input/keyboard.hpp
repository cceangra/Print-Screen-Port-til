// Print RC — private native module. GPL-3.0-or-later
#pragma once
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <cerrno>
#include <chrono>
#include <cstring>
#include <iostream>
#include <vector>
#include <sys/select.h>
#include "../i18n/messages.hpp"
using Clock=std::chrono::steady_clock;

namespace prc {
// Detecta apenas uma tecla durante a configuracao solicitada pelo usuario.
// Nao guarda teclas, nao cria processo residente e nao altera atalhos do desktop.
// XGrabKeyboard redireciona eventos somente durante a janela de ate 60 s.
// Variacao de tempo SOMENTE na compilacao do teste de timeout acelerado.
#ifndef PRINT_RC_DETECT_SECONDS
#define PRINT_RC_DETECT_SECONDS 60
#endif
static_assert(PRINT_RC_DETECT_SECONDS > 0 && PRINT_RC_DETECT_SECONDS <= 600,
              "Tempo de deteccao X11 invalido");
// Encontrar uma tecla X11 normal, nao apenas Print. Primeiro tentar o keysym
// base do evento; se estiver ausente, procurar um keysym definido no keycode.
// Nunca modificar o mapa do teclado do usuario.
KeySym selected_keysym_for_event(Display* d, const XKeyEvent& ev) {
    const KeySym first=XLookupKeysym(const_cast<XKeyEvent*>(&ev),0);
    if(first!=NoSymbol) return first;
    int count=0;
    KeySym* syms=XGetKeyboardMapping(d,static_cast<KeyCode>(ev.keycode),1,&count);
    if(!syms) return NoSymbol;
    KeySym found=NoSymbol;
    for(int i=0;i<count;i++) {
        if(syms[i]!=NoSymbol) { found=syms[i]; break; }
    }
    XFree(syms);
    return found;
}
bool standalone_modifier(KeySym sym) {
    switch(sym) {
        case XK_Shift_L: case XK_Shift_R:
        case XK_Control_L: case XK_Control_R:
        case XK_Alt_L: case XK_Alt_R:
        case XK_Meta_L: case XK_Meta_R:
        case XK_Super_L: case XK_Super_R:
        case XK_Hyper_L: case XK_Hyper_R:
        case XK_ISO_Level3_Shift: case XK_Mode_switch:
            return true;
        default: return false;
    }
}
bool safe_shortcut_name(const char* name) {
    if(!name) return false;
    const size_t length=std::strlen(name);
    if(length==0 || length>64) return false;
    for(const unsigned char* p=reinterpret_cast<const unsigned char*>(name);*p;++p) {
        if(!((*p>='A' && *p<='Z') || (*p>='a' && *p<='z') ||
             (*p>='0' && *p<='9') || *p=='_')) return false;
    }
    return true;
}

int detect_print_key() {
    const char* displayName=std::getenv("DISPLAY");
    if (!displayName || !*displayName) {
        std::cerr<<prc_tr("native.007");
        return 2;
    }
    Display* d=XOpenDisplay(nullptr);
    if (!d) {
        std::cerr<<prc_tr("native.008");
        return 2;
    }
    const Window root=DefaultRootWindow(d);
    // A janela de grab deve estar VISIVEL; a root do X11 sempre esta.
    // XSelectInput so registra eventos neste cliente, sem mudar atalhos globais.
    XSelectInput(d,root,KeyPressMask);
    XFlush(d);
    const int grab=XGrabKeyboard(d,root,False,GrabModeAsync,GrabModeAsync,CurrentTime);
    if (grab!=GrabSuccess) {
        std::cerr<<prc_tr("native.009")
                 <<grab<<").\n";

        XCloseDisplay(d);
        return 3;
    }
    std::cerr<<prc_tr("native.010")
             <<prc_tr("native.011")
             <<prc_tr("native.012")<<PRINT_RC_DETECT_SECONDS<<prc_tr("native.013")
             <<prc_tr("native.014");
    std::cerr.flush();
    int result=4;
    const auto expires=Clock::now()+std::chrono::seconds(PRINT_RC_DETECT_SECONDS);
    while (Clock::now()<expires) {
        while (XPending(d)) {
            XEvent event{};
            XNextEvent(d,&event);
            if (event.type!=KeyPress) continue;
            const KeySym key=selected_keysym_for_event(d,event.xkey);
            if(key==XK_Escape) {
                std::cerr<<prc_tr("native.015");
                result=5;
                goto finished_key_detection;
            }
            if(standalone_modifier(key)) {
                std::cerr<<prc_tr("native.016")
                         <<prc_tr("native.017");
                continue;
            }
            const char* name=XKeysymToString(key);
            if(safe_shortcut_name(name)) {
                std::cout<<"PRINT_RC_KEY="<<name<<"\n";
                std::cout.flush();
                std::cerr<<prc_tr("native.018")<<name
                         <<prc_tr("native.019")<<event.xkey.keycode<<").\n";
                result=0;
                goto finished_key_detection;
            }
            std::cerr<<prc_tr("native.020")
                     <<prc_tr("native.021");
        }
        const int fd=ConnectionNumber(d);
        if (fd<0 || fd>=FD_SETSIZE) {
            std::cerr<<prc_tr("native.022");
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
            std::cerr<<prc_tr("native.023");
            result=3;
            break;
        }
    }
    if (result==4) std::cerr<<prc_tr("native.024")<<PRINT_RC_DETECT_SECONDS<<prc_tr("native.025");
finished_key_detection:
    XUngrabKeyboard(d,CurrentTime);
    XSync(d,False);
    XCloseDisplay(d);
    return result;
}

// Sonda curta e nao destrutiva de reservas X11 da tecla Print.
// XUngrabKey libera SOMENTE o grab criado por ESTA conexao.
// Uma reserva ativa de outro cliente nunca e liberada por esta operacao.
bool shortcut_probe_error=false;
int shortcut_probe_handler(Display*, XErrorEvent* e) {
    if (e->error_code==BadAccess) shortcut_probe_error=true;
    else shortcut_probe_error=true;
    return 0;
}
int inspect_print_grabs(const char* name="Print") {
    const KeySym selected=XStringToKeysym(name);
    if(!safe_shortcut_name(name) || selected==NoSymbol || standalone_modifier(selected) || selected==XK_Escape) {
        std::cerr<<prc_tr("native.invalid_key");return 2;
    }
    if (!std::getenv("DISPLAY")) {
        std::cout<<"PRINT_RC_GRAB=indeterminado\n";
        std::cerr<<prc_tr("native.026");
        return 2;
    }
    Display* d=XOpenDisplay(nullptr);
    if (!d) {
        std::cout<<"PRINT_RC_GRAB=indeterminado\n";
        std::cerr<<prc_tr("native.027");
        return 2;
    }
    int first=0,last=0;
    XDisplayKeycodes(d,&first,&last);
    int per_code=0;
    KeySym* symbols=XGetKeyboardMapping(d,first,last-first+1,&per_code);
    std::vector<int> codes;
    if (symbols) {
        for (int code=first;code<=last;code++) {
            for (int i=0;i<per_code;i++) {
                const KeySym symbol=symbols[(code-first)*per_code+i];
                if (symbol==selected || ((selected==XK_Print || selected==XK_Sys_Req) && (symbol==XK_Print || symbol==XK_Sys_Req))) {
                    codes.push_back(code);
                    break;
                }
            }
        }
        XFree(symbols);
    }
    if (codes.empty()) {
        std::cout<<"PRINT_RC_GRAB=indeterminado\n";
        std::cerr<<prc_tr("native.028");
        XCloseDisplay(d);
        return 3;
    }
    // Testar a combinacao Print sem modificadores, com NumLock/CapsLock.
    // Grab e ungrab atomizados dentro da conexao, com XSync para capturar BadAccess.
    constexpr unsigned int modifiers[]={0,LockMask,Mod2Mask,LockMask|Mod2Mask};
    auto* previous=XSetErrorHandler(shortcut_probe_handler);
    bool occupied=false;
    for(int code:codes) {
        bool free_grab=true;
        for (unsigned int mod:modifiers) {
            shortcut_probe_error=false;
            XGrabKey(d,code,mod,DefaultRootWindow(d),False,GrabModeAsync,GrabModeAsync);
            XSync(d,False);
            if (shortcut_probe_error) {
                occupied=true;
                free_grab=false;
            }
            if (!shortcut_probe_error) {
                XUngrabKey(d,code,mod,DefaultRootWindow(d));
                XSync(d,False);
            }
        }
        (void)free_grab;
    }
    XSetErrorHandler(previous);
    XCloseDisplay(d);
    std::cout<<"PRINT_RC_GRAB="<<(occupied?"ocupada":"sem_bloqueio_x11")<<"\n";
    std::cout<<prc_tr("native.029");
    return occupied?6:0;
}


}
