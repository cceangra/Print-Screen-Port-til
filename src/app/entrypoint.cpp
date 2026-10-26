// Native public entrypoint. Existing scripts retain setup and shortcut semantics.
#include "../i18n/messages.hpp"
#include "dialog.hpp"
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

static bool sakura_terminal(const std::string& program) {
    std::vector<std::string> candidates;
    if (program.find('/')!=std::string::npos) candidates.push_back(program);
    else {
        const char* environment=std::getenv("PATH");
        const std::string paths=environment?environment:"/usr/bin:/bin";
        size_t start=0;
        do {
            const size_t end=paths.find(':',start);
            const std::string directory=paths.substr(start,end==std::string::npos?end:end-start);
            candidates.push_back((directory.empty()?".":directory)+"/"+program);
            if (end==std::string::npos) break;
            start=end+1;
        } while (start<=paths.size());
    }
    for (const auto& candidate:candidates) {
        if (access(candidate.c_str(),X_OK)!=0) continue;
        char resolved[PATH_MAX+1]{};
        if (!realpath(candidate.c_str(),resolved)) return false;
        const char* name=std::strrchr(resolved,'/');
        return std::strcmp(name?name+1:resolved,"sakura")==0;
    }
    return false;
}

static std::string quoted_command(const std::vector<std::string>& arguments) {
    // Sakura -x parses one command string with g_shell_parse_argv. Quoting each
    // argument preserves spaces/quotes literally; no shell expansion is used.
    std::string command;
    for (const auto& argument:arguments) {
        if (!command.empty()) command+=' ';
        command+='\'';
        for (char character:argument) command+=character=='\''?"'\\''":std::string(1,character);
        command+='\'';
    }
    return command;
}

static int failure(const std::string& message, int code=2) {
    std::fputs(message.c_str(),stderr);
    prc_error_dialog(message);
    return code;
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
    // Used by iniciar.sh only if it fails before exec'ing the supervisor.
    if(flag=="--startup-error" && argc==3) {
        char* end=nullptr;
        const long code=std::strtol(argv[2],&end,10);
        if (!*argv[2] || !end || *end || code<1 || code>255) return 2;
        char message[1024]{};
        std::snprintf(message,sizeof(message),prc_tr("native.launch_failed"),static_cast<int>(code));
        return failure(message,static_cast<int>(code));
    }
#ifdef PRINT_RC_INSTALLER
    std::string script="instalar.sh";
    bool terminal=true;
#else
    std::string script="iniciar.sh";
    bool terminal=false;
#endif
    int first_argument=1;
    if(flag=="--install") {script="instalar.sh";terminal=true;first_argument=2;}
    else if(flag=="--configure") {script="configurar.sh";terminal=true;first_argument=2;}
    else if(flag=="--shortcut") {script="configurar-tecla.sh";terminal=true;first_argument=2;}
    else if(flag=="--uninstall") {script="desinstalar.sh";terminal=true;first_argument=2;}
    else if(flag=="--diagnose" || flag=="--version" || flag=="--build-info" || flag=="--show-config" || flag=="--self-test") {
        script="iniciar.sh";terminal=false;
    }
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
        char message[PATH_MAX+512]{};
        std::snprintf(message,sizeof(message),prc_tr("native.entry_missing"),base.c_str());
        return failure(message);
    }
    std::vector<std::string> command{"/bin/bash",path};
    for(int i=first_argument;i<argc;++i) command.emplace_back(argv[i]);
    if(!terminal || (isatty(STDIN_FILENO) && isatty(STDOUT_FILENO))) {
        if (!terminal && argc==1 && !isatty(STDERR_FILENO)) setenv("PRINT_RC_GUI_ERRORS","1",1);
        execute(command);
        char message[512]{};
        std::snprintf(message,sizeof(message),prc_tr("native.entry_exec_failed"),std::strerror(errno));
        return failure(message,126);
    }
    // No shell interpolation: spaces, accents and user arguments stay literal.
    if(std::getenv("DISPLAY") || std::getenv("WAYLAND_DISPLAY")) {
        const std::vector<std::vector<std::string>> terminals={
            {"x-terminal-emulator","-e"},{"konsole","-e"},
            {"/opt/trinity/bin/konsole","-e"},{"sakura","-x"},
            {"xfce4-terminal","-x"},{"xterm","-e"},
            {"gnome-terminal","--wait","--"}
        };
        for(auto terminal_command:terminals) {
            std::vector<std::string> action{"/bin/bash",base+"/scripts/terminal-action.sh",path};
            for(int i=first_argument;i<argc;++i) action.emplace_back(argv[i]);
            if (sakura_terminal(terminal_command[0]))
                terminal_command={terminal_command[0],"-x",quoted_command(action)};
            else terminal_command.insert(terminal_command.end(),action.begin(),action.end());
            execute(terminal_command);
        }
    }
    char message[PATH_MAX+512]{};
    std::snprintf(message,sizeof(message),prc_tr("native.entry_terminal_missing"),path.c_str());
    return failure(message);
}
