// Small native parent: diagnose fatal startup signals outside the crashing app.
// Exit after clipboard ownership, leaving only the native clipboard owner resident.
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <poll.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>

static volatile sig_atomic_t child_pid = -1;
static void forward_signal(int signal) {
    if (child_pid > 0) kill(child_pid, signal);
}

int main(int argc, char** argv) {
    if (argc < 2) return 2;
    int channel[2];
    if (pipe(channel) < 0) { std::perror("Print RC: pipe"); return 2; }
    const pid_t pid = fork();
    if (pid < 0) { std::perror("Print RC: fork"); return 2; }
    if (!pid) {
        close(channel[0]);
        char fd[24];
        std::snprintf(fd, sizeof(fd), "%d", channel[1]);
        setenv("PRINT_RC_STATUS_FD", fd, 1);
        execv(argv[1], argv + 1);
        const int error = errno;
        std::perror("Print RC: EARLY_PROCESS_TERMINATION");
        _exit(error == ENOENT ? 127 : 126);
    }
    child_pid = pid;
    close(channel[1]);
    struct sigaction action{};
    action.sa_handler = forward_signal;
    sigemptyset(&action.sa_mask);
    sigaction(SIGINT, &action, nullptr);
    sigaction(SIGTERM, &action, nullptr);
    sigaction(SIGHUP, &action, nullptr);
    bool ready = false;
    bool save_failed = false;
    for (;;) {
        pollfd descriptor{channel[0], POLLIN, 0};
        const int result = poll(&descriptor, 1, -1);
        if (result < 0) { if (errno == EINTR) continue; break; }
        char stage = 0;
        const ssize_t count = read(channel[0], &stage, 1);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) break;
        if (stage == 'R') ready = true;
        if (stage == 'S') save_failed = true;
        if (stage == 'C') { close(channel[0]); return save_failed ? 6 : 0; }
    }
    close(channel[0]);
    int status = 0;
    while (waitpid(pid, &status, 0) < 0) { if (errno != EINTR) return 2; }
    child_pid = -1;
    if (WIFSIGNALED(status)) {
        const int signal = WTERMSIG(status);
        std::fprintf(stderr, "Print RC: FATAL_SIGNAL=%d (%s); OVERLAY_READY=%s\n",
                     signal, strsignal(signal), ready ? "yes" : "no");
        return 128 + signal;
    }
    const int code = WIFEXITED(status) ? WEXITSTATUS(status) : 2;
    if (code && !ready)
        std::fprintf(stderr, "Print RC: EARLY_PROCESS_TERMINATION=%d; OVERLAY_READY=no\n", code);
    return code;
}
