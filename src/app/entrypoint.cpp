// Native public entrypoint. Existing scripts retain setup and shortcut semantics.
#include "../i18n/messages.hpp"
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <limits.h>
#include <string>
#include <sys/stat.h>
#include <unistd.h>
#include <vector>

static bool regular(const std::string& path) {
    struct stat value{};
    return lstat(path.c_str(), &value)==0 && S_ISREG(value.st_mode);
}

static void execute(const std::vector<std::string>& arguments) {
    std::vector<char*> argv;
    for(const auto& value:arguments) argv.push_back(const_cast<char*>(value.c_str()));
    argv.push_back(nullptr);
    execvp(argv[0],argv.data());
}

int main(int argc,char** argv) {
    char executable[PATH_MAX+1]{};
    const auto length=readlink("/proc/self/exe",executable,sizeof(executable)-1);
    if(length<=0 || static_cast<size_t>(length)>=sizeof(executable)-1) return 2;
    std::string base(executable,static_cast<size_t>(length));
    base.resize(base.find_last_of('/'));
    setenv("PRINT_RC_CONFIG",(base+"/config/opcoes.conf").c_str(),1);
    const std::string flag=argc>1?argv[1]:"";
    if(flag=="--help") {std::fputs(prc_tr("native.entry_help"),stdout);return 0;}
    std::string script="iniciar.sh";
    bool terminal=false;
    int first_argument=1;
    if(flag=="--install") {script="instalar.sh";terminal=true;first_argument=2;}
    else if(flag=="--configure") {script="configurar.sh";terminal=true;first_argument=2;}
    else if(flag=="--shortcut") {script="configurar-tecla.sh";terminal=true;first_argument=2;}
    else if(flag=="--uninstall") {script="desinstalar.sh";terminal=true;first_argument=2;}
    else if(argc==1 && !regular(base+"/config/opcoes.conf")) {
        script="instalar.sh";terminal=true;
    }
    else if(argc==1) {
        const char* session=std::getenv("XDG_SESSION_TYPE");
        // Let the existing localized X11 limitation remain visible on Wayland.
        if(session && std::strcmp(session,"x11")!=0) terminal=true;
    }
    const std::string path=base+"/"+script;
    if(!regular(path) || (terminal && !regular(base+"/scripts/terminal-action.sh"))) {
        std::fprintf(stderr,prc_tr("native.entry_missing"),base.c_str());return 2;
    }
    std::vector<std::string> command{"/bin/bash",path};
    for(int i=first_argument;i<argc;++i) command.emplace_back(argv[i]);
    if(!terminal || (isatty(STDIN_FILENO) && isatty(STDOUT_FILENO))) {
        execute(command);
        std::fprintf(stderr,prc_tr("native.entry_exec_failed"),std::strerror(errno));return 126;
    }
    // No shell interpolation: spaces, accents and user arguments remain argv.
    if(std::getenv("DISPLAY") || std::getenv("WAYLAND_DISPLAY")) {
        const std::vector<std::vector<std::string>> terminals={
            {"x-terminal-emulator","-e"},{"konsole","-e"},
            {"xfce4-terminal","-x"},{"xterm","-e"},
            {"gnome-terminal","--wait","--"}
        };
        for(auto terminal_command:terminals) {
            terminal_command.insert(terminal_command.end(),{"/bin/bash",base+"/scripts/terminal-action.sh",path});
            for(int i=first_argument;i<argc;++i) terminal_command.emplace_back(argv[i]);
            execute(terminal_command);
        }
    }
    std::fprintf(stderr,prc_tr("native.entry_terminal_missing"),path.c_str());return 2;
}
