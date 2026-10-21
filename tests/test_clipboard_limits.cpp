#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <cassert>
#include <chrono>
#include <cstdio>
#include <unistd.h>
#include <vector>
int main() {
    Display* d=XOpenDisplay(nullptr);assert(d);
    Atom clipboard=XInternAtom(d,"CLIPBOARD",False),png=XInternAtom(d,"image/png",False);
    Atom property=XInternAtom(d,"_PRINT_RC_TEST_INCR",False);
    for(int i=0;i<100 && XGetSelectionOwner(d,clipboard)==None;++i)usleep(10000);
    assert(XGetSelectionOwner(d,clipboard)!=None);
    std::vector<Window> windows;
    auto request=[&](Window window) {
        XConvertSelection(d,clipboard,png,property,window,CurrentTime);XFlush(d);
        auto deadline=std::chrono::steady_clock::now()+std::chrono::seconds(5);
        while(std::chrono::steady_clock::now()<deadline) {
            while(XPending(d)) {
                XEvent e{};XNextEvent(d,&e);
                if(e.type==SelectionNotify && e.xselection.requestor==window)
                    return e.xselection.property!=None;
            }
            usleep(1000);
        }
        assert(false && "clipboard request timeout");return false;
    };
    for(int i=0;i<20;++i) {
        Window window=XCreateSimpleWindow(d,DefaultRootWindow(d),-10,-10,1,1,0,0,0);
        windows.push_back(window);
        const bool accepted=request(window);
        assert(accepted==(i<16));
    }
    // Close abandoned INCR clients; a new paste must be accepted afterwards.
    for(Window window:windows)XDestroyWindow(d,window);
    XSync(d,False);
    Window last=XCreateSimpleWindow(d,DefaultRootWindow(d),-10,-10,1,1,0,0,0);
    assert(request(last));XDestroyWindow(d,last);XSync(d,False);XCloseDisplay(d);
    std::puts("PASS: INCR concurrency bounded to 16; destroyed clients free their slots");
}
