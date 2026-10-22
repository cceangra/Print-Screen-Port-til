// Explicit test/benchmark driver. Never called by read-only diagnostics.
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/keysym.h>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <unistd.h>

Window overlay(Display* d,bool painted) {
    Window root=DefaultRootWindow(d),returned=0,parent=0,*children=nullptr;
    unsigned count=0;Window result=None;
    XWindowAttributes screen{};XGetWindowAttributes(d,root,&screen);
    if(!XQueryTree(d,root,&returned,&parent,&children,&count)) return None;
    for(unsigned i=0;i<count;++i) {
        XWindowAttributes attrs{};
        if(!XGetWindowAttributes(d,children[i],&attrs) || attrs.map_state!=IsViewable
           || !attrs.override_redirect || attrs.width!=screen.width || attrs.height!=screen.height) continue;
        if(painted) {
            Atom type=0;int format=0;unsigned long length=0,left=0;unsigned char* data=nullptr;
            XGetWindowProperty(d,children[i],XInternAtom(d,"_PRINT_RC_READY",False),0,64,False,XA_STRING,
                               &type,&format,&length,&left,&data);
            const bool ready=type==XA_STRING && length>0;
            if(data)XFree(data);
            if(ready) {result=children[i];break;}
            XImage* pixel=XGetImage(d,children[i],10,100,1,1,AllPlanes,ZPixmap);
            if(!pixel)continue;
            auto value=XGetPixel(pixel,0,0);XDestroyImage(pixel);
            if(value==0 || value==WhitePixel(d,DefaultScreen(d)))continue;
        }
        result=children[i];break;
    }
    if(children)XFree(children);
    return result;
}
int main(int argc,char** argv) {
    if(argc!=2)return 2;
    Display* d=XOpenDisplay(nullptr);if(!d)return 2;
    auto root=DefaultRootWindow(d);
    if(!std::strcmp(argv[1],"paint")) {
        const int screen=DefaultScreen(d);
        Pixmap background=XCreatePixmap(d,root,DisplayWidth(d,screen),DisplayHeight(d,screen),DefaultDepth(d,screen));
        GC gc=XCreateGC(d,background,0,nullptr);
        XSetForeground(d,gc,WhitePixel(d,screen));
        XFillRectangle(d,background,gc,0,0,DisplayWidth(d,screen),DisplayHeight(d,screen));
        XSetWindowBackgroundPixmap(d,root,background);XClearWindow(d,root);
        XSetCloseDownMode(d,RetainPermanent);XFreeGC(d,gc);XSync(d,False);
    } else if(!std::strcmp(argv[1],"dimensions")) {
        std::printf("%d %d\n",DisplayWidth(d,DefaultScreen(d)),DisplayHeight(d,DefaultScreen(d)));
    } else {
        Window window=None;
        auto deadline=std::chrono::steady_clock::now()+std::chrono::seconds(10);
        while(window==None && std::chrono::steady_clock::now()<deadline) {
            window=overlay(d,true);if(window==None)usleep(1000);
        }
        if(window==None){XCloseDisplay(d);return 3;}
        if(!std::strcmp(argv[1],"full")) {
            XEvent e{};e.xbutton.type=ButtonPress;e.xbutton.display=d;e.xbutton.window=window;
            e.xbutton.button=Button1;e.xbutton.x=(DisplayWidth(d,DefaultScreen(d))-280)/2+86;e.xbutton.y=35;
            XSendEvent(d,window,False,ButtonPressMask,&e);XSync(d,False);
        } else if(!std::strcmp(argv[1],"cancel")) {
            XEvent e{};e.xkey.type=KeyPress;e.xkey.display=d;e.xkey.window=window;
            e.xkey.keycode=XKeysymToKeycode(d,XK_Escape);
            XSendEvent(d,window,False,KeyPressMask,&e);XSync(d,False);
        } else std::printf("%lu\n",window);
    }
    XCloseDisplay(d);return 0;
}
