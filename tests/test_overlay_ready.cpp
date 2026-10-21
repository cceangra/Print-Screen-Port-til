// Run only in an isolated X11 test server. Assert pixels AND readiness, not a PID.
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <cassert>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <sys/wait.h>
#include <unistd.h>

int main(int argc,char** argv) {
    assert(argc==2);
    Display* d=XOpenDisplay(nullptr); assert(d);
    Window root=DefaultRootWindow(d);
    XSetWindowBackground(d,root,WhitePixel(d,DefaultScreen(d)));
    XClearWindow(d,root); XSync(d,False);
    const pid_t pid=fork(); assert(pid>=0);
    if(!pid) { execl(argv[1],argv[1],nullptr); _exit(127); }
    const Atom atom=XInternAtom(d,"_PRINT_RC_READY",False);
    Window overlay=None;
    auto deadline=std::chrono::steady_clock::now()+std::chrono::seconds(10);
    while(overlay==None && std::chrono::steady_clock::now()<deadline) {
        Window returned_root=0,parent=0,*children=nullptr;
        unsigned int count=0;
        assert(XQueryTree(d,root,&returned_root,&parent,&children,&count));
        for(unsigned int i=0;i<count;++i) {
            Atom type=0; int format=0; unsigned long length=0,remaining=0;
            unsigned char* value=nullptr;
            XGetWindowProperty(d,children[i],atom,0,64,False,XA_STRING,
                               &type,&format,&length,&remaining,&value);
            if(type==XA_STRING && format==8 && length>0) overlay=children[i];
            if(value) XFree(value);
        }
        if(children) XFree(children);
        if(overlay==None) usleep(10000);
    }
    if(overlay==None) { kill(pid,SIGTERM); waitpid(pid,nullptr,0); }
    assert(overlay!=None);
    Atom language_type=0;int language_format=0;unsigned long length=0,remaining=0;
    unsigned char* language=nullptr;
    XGetWindowProperty(d,overlay,XInternAtom(d,"_PRINT_RC_LANGUAGE",False),0,8,False,XA_STRING,
                       &language_type,&language_format,&length,&remaining,&language);
    assert(language_type==XA_STRING && language_format==8 && length==5);
    const char* requested=std::getenv("PRINT_RC_LANG");
    if(requested) assert(std::memcmp(language,requested,5)==0);
    XFree(language);
    XWindowAttributes attrs{};
    assert(XGetWindowAttributes(d,overlay,&attrs));
    assert(attrs.map_state==IsViewable);
    XImage* image=XGetImage(d,overlay,10,100,1,1,AllPlanes,ZPixmap); assert(image);
    auto pixel=XGetPixel(image,0,0);
    // White root must be visibly darker. Works for RGB565 and RGB888.
    const auto white=WhitePixel(d,DefaultScreen(d));
    assert(pixel!=white && (pixel&(image->red_mask|image->green_mask|image->blue_mask))!=0);
    XDestroyImage(image);
    assert(XGrabPointer(d,root,False,0,GrabModeAsync,GrabModeAsync,None,None,CurrentTime)==AlreadyGrabbed);
    assert(XGrabKeyboard(d,root,False,GrabModeAsync,GrabModeAsync,CurrentTime)==AlreadyGrabbed);
    XEvent escape{};
    escape.xkey.type=KeyPress;escape.xkey.display=d;escape.xkey.window=overlay;
    escape.xkey.keycode=XKeysymToKeycode(d,XK_Escape);
    XSendEvent(d,overlay,False,KeyPressMask,&escape);XSync(d,False);
    int status=0;
    bool exited=false;
    deadline=std::chrono::steady_clock::now()+std::chrono::seconds(5);
    while(std::chrono::steady_clock::now()<deadline) {
        if(waitpid(pid,&status,WNOHANG)==pid) {exited=true;break;}
        usleep(10000);
    }
    if(!exited) {kill(pid,SIGTERM);waitpid(pid,&status,0);}
    assert(exited && WIFEXITED(status) && WEXITSTATUS(status)==0);
    assert(XGetSelectionOwner(d,XInternAtom(d,"_PRINT_RC_CAPTURING_INSTANCE",False))==None);
    assert(XGrabKeyboard(d,root,False,GrabModeAsync,GrabModeAsync,CurrentTime)==GrabSuccess);
    XUngrabKeyboard(d,CurrentTime);
    assert(XGrabPointer(d,root,False,0,GrabModeAsync,GrabModeAsync,None,None,CurrentTime)==GrabSuccess);
    XUngrabPointer(d,CurrentTime);XCloseDisplay(d);
    std::puts("PASS: mapped overlay, dimmed pixels, both grabs, Escape and cleanup");
}
