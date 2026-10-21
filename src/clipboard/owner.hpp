// Print RC — private native module. GPL-3.0-or-later
#pragma once
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <algorithm>
#include <chrono>
#include <iostream>
#include <vector>
#include <poll.h>
#include <cerrno>
#include <sys/select.h>
#include "../app/runtime.hpp"
#include "../i18n/messages.hpp"
using Clock=std::chrono::steady_clock;
inline constexpr size_t kChunkSize=64*1024;

namespace prc {
struct Transfer { Window window; Atom property; size_t offset; };
bool clipboard_loop(Display* display, Window owner, std::vector<unsigned char> png,
                    Clock::time_point expires) {
    const Atom clipboard=XInternAtom(display,"CLIPBOARD",False);
    const Atom targets=XInternAtom(display,"TARGETS",False);
    const Atom pngAtom=XInternAtom(display,"image/png",False);
    const Atom incr=XInternAtom(display,"INCR",False);
    XSetSelectionOwner(display,clipboard,owner,CurrentTime);
    XFlush(display);
    if (XGetSelectionOwner(display,clipboard)!=owner) {
        std::cerr<<prc_tr("native.004");
        return false;
    }
    const long request_units=XMaxRequestSize(display);
    if(request_units<=64) {std::cerr<<prc_tr("native.004");return false;}
    const size_t chunk=std::min(kChunkSize,static_cast<size_t>(request_units-64)*4);
    std::vector<Transfer> transfers;transfers.reserve(16);
    print_rc_stage('C');
    std::cout<<prc_tr("native.005");
    while (Clock::now()<expires) {
        while (XPending(display)) {
            XEvent e{};
            XNextEvent(display,&e);
            if (e.type==SelectionClear && e.xselectionclear.selection==clipboard) return true;
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
                    if (png.size()<=chunk) {
                        XChangeProperty(display,request.requestor,property,pngAtom,8,PropModeReplace,
                                        png.data(),static_cast<int>(png.size()));
                    } else if(transfers.size()<16 && std::none_of(transfers.begin(),transfers.end(),[&](const Transfer& t) {
                        return t.window==request.requestor && t.property==property;
                    })) {
                        XSelectInput(display,request.requestor,PropertyChangeMask|StructureNotifyMask);
                        unsigned long count=static_cast<unsigned long>(png.size());
                        XChangeProperty(display,request.requestor,property,incr,32,PropModeReplace,
                                        reinterpret_cast<unsigned char*>(&count),1);
                        transfers.push_back({request.requestor,property,0});
                    } else {
                        property=None;
                    }
                    supported=property!=None;
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
            } else if(e.type==DestroyNotify) {
                transfers.erase(std::remove_if(transfers.begin(),transfers.end(),[&](const Transfer& t) {
                    return t.window==e.xdestroywindow.window;
                }),transfers.end());
            } else if (e.type==PropertyNotify && e.xproperty.state==PropertyDelete) {
                for (auto it=transfers.begin();it!=transfers.end();) {
                    if (it->window!=e.xproperty.window || it->property!=e.xproperty.atom) { ++it;continue; }
                    size_t length=std::min(chunk,png.size()-it->offset);
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
        // Sleep until the next selection/property event or the actual expiry.
        pollfd descriptor{ConnectionNumber(display),POLLIN,0};
        const int ready=poll(&descriptor,1,static_cast<int>(remaining));
        if(ready<0 && errno!=EINTR) return false;

    }
    return true;
}


}
