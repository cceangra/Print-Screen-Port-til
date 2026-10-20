// Testa falha de XGrabKeyboard no X11 virtual; o aplicativo deve encerrar e liberar mouse.
#include <X11/Xlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <cassert>
#include <cstdlib>

int main(int argc,char**argv) {
    if(argc!=2) return 2;
    char pattern[]="/tmp/print-rc-teclado-XXXXXX";
    char* root=mkdtemp(pattern);
    if(!root) return 2;
    std::filesystem::path temp(root);
    std::filesystem::create_directory(temp/"capturas");
    {
        std::ofstream config(temp/"opcoes.conf");
        config<<"save_dir="<<(temp/"capturas").string()<<"\ncopy_clipboard=0\n";
    }
    setenv("PRINT_RC_CONFIG",(temp/"opcoes.conf").c_str(),1);
    Display* display=XOpenDisplay(nullptr);
    if(!display) return 2;
    Window rootWindow=DefaultRootWindow(display);
    int grab=XGrabKeyboard(display,rootWindow,False,GrabModeAsync,GrabModeAsync,CurrentTime);
    if(grab!=GrabSuccess) {
        std::cerr<<"ERRO: o teste nao conseguiu capturar o teclado primeiro.\n";
        return 2;
    }
    XSync(display,False);
    pid_t pid=fork();
    if(pid==0) {
        execl(argv[1],argv[1],(char*)nullptr);
        _exit(127);
    }
    if(pid<0) return 2;
    int status=0;
    waitpid(pid,&status,0);
    bool exit_ok=WIFEXITED(status) && WEXITSTATUS(status)==4;
    // O capturador deve ter LIBERADO o grab de mouse antes de sair.
    int pointer=XGrabPointer(display,rootWindow,False,ButtonPressMask,
                            GrabModeAsync,GrabModeAsync,None,None,CurrentTime);
    bool mouse_free=pointer==GrabSuccess;
    if(mouse_free) XUngrabPointer(display,CurrentTime);
    XUngrabKeyboard(display,CurrentTime);
    XSync(display,False);
    XCloseDisplay(display);
    bool photos_empty=std::filesystem::is_empty(temp/"capturas");
    std::filesystem::remove_all(temp);
    if(!exit_ok || !mouse_free || !photos_empty) {
        std::cerr<<"ERRO: teclado ocupado nao foi tratado com seguranca.\n";
        return 1;
    }
    std::cout<<"OK: captura do teclado falhou; Print RC fechou sem print e liberou mouse.\n";
    return 0;
}
