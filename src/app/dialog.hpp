// Optional error dialogs. No GUI dependency or resident process is added.
#pragma once
#include <cerrno>
#include <cstdlib>
#include <sys/wait.h>
#include <unistd.h>
#include <string>
#include <vector>

inline void prc_error_dialog(const std::string& message) {
    if (isatty(STDERR_FILENO) || (!std::getenv("DISPLAY") && !std::getenv("WAYLAND_DISPLAY"))) return;
    const std::vector<std::vector<std::string>> providers = {
        {"zenity", "--error", "--title=Print RC", "--text="+message},
        {"kdialog", "--title", "Print RC", "--error", message},
        {"/opt/trinity/bin/kdialog", "--title", "Print RC", "--error", message},
        {"xmessage", "-center", "-buttons", "OK:0", message}
    };
    for (const auto& command : providers) {
        const pid_t child=fork();
        if (child<0) return;
        if (!child) {
            std::vector<char*> args;
            for (const auto& value : command) args.push_back(const_cast<char*>(value.c_str()));
            args.push_back(nullptr);
            execvp(args[0],args.data());
            _exit(127);
        }
        int status=0;
        pid_t waited;
        do { waited=waitpid(child,&status,0); } while (waited<0 && errno==EINTR);
        if (waited<0 || (WIFEXITED(status) && WEXITSTATUS(status)==0)) return;
    }
}
