// Opt-in readiness channel. No files, logging daemon or signal handler.
#pragma once
#include <cstdlib>
#include <cerrno>
#include <climits>
#include <unistd.h>

inline void print_rc_stage(char stage) {
    const char* value = std::getenv("PRINT_RC_STATUS_FD");
    if (!value || !*value) return;
    char* end = nullptr;
    errno = 0;
    long fd = std::strtol(value, &end, 10);
    if (errno || !end || *end || fd < 3 || fd > INT_MAX) return;
    ssize_t result;
    do { result = write(static_cast<int>(fd), &stage, 1); } while (result < 0 && errno == EINTR);
}
