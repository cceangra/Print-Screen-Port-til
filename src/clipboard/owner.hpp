// Print RC — private native module. GPL-3.0-or-later
#pragma once
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <algorithm>
#include <chrono>
#include <iostream>
#include <vector>
#include <poll.h>
#include <sys/select.h>
#include "../app/runtime.hpp"
#include "../i18n/messages.hpp"
using Clock=std::chrono::steady_clock;
inline constexpr size_t kChunkSize=64*1024;

namespace prc {
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
        std::cerr<<prc_tr("native.004");
        return;
    }
    print_rc_stage('C');
    std::cout<<prc_tr("native.005");
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


}
