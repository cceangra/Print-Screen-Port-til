// Print RC — preferencias e escrita segura de imagens.
// GPL-3.0-or-later
#pragma once
#include <cerrno>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>
#include <fcntl.h>
#include <unistd.h>

struct PrintRcSettings {
    std::string save_dir;
    bool copy_clipboard = true;
};

inline bool print_rc_load_settings(PrintRcSettings& settings) {
    const char* path = std::getenv("PRINT_RC_CONFIG");
    if (!path || !*path) {
        std::cerr << "Print RC: configuracao nao informada. Execute iniciar.sh.\n";
        return false;
    }
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        std::cerr << "Print RC: opcoes nao encontradas: " << path << "\n"
                  << "Execute bash configurar.sh na pasta do Print RC.\n";
        return false;
    }
    bool has_dir = false, has_clip = false;
    std::string line;
    while (std::getline(file, line)) {
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (line.rfind("save_dir=",0)==0) {
            if (has_dir) return false;
            settings.save_dir=line.substr(9);
            has_dir=true;
        } else if (line.rfind("copy_clipboard=",0)==0) {
            if (has_clip) return false;
            const auto option=line.substr(15);
            if (option != "0" && option != "1") return false;
            settings.copy_clipboard=option=="1";
            has_clip=true;
        }
    }
    std::error_code ec;
    if (!has_dir || !has_clip || settings.save_dir.empty()
        || settings.save_dir.front()!='/' || !std::filesystem::is_directory(settings.save_dir,ec)) {
        std::cerr << "Print RC: pasta de imagens/configuracao invalida ou indisponivel.\n";
        return false;
    }
    return true;
}

inline bool print_rc_save_png(const std::vector<unsigned char>& png, const std::string& dir) {
    const auto instant=std::chrono::system_clock::now();
    const auto us=std::chrono::duration_cast<std::chrono::microseconds>(
        instant.time_since_epoch()).count() % 1000000;
    std::time_t stamp_time=std::chrono::system_clock::to_time_t(instant);
    std::tm local{};
    localtime_r(&stamp_time,&local);
    char stamp[32]{};
    std::strftime(stamp,sizeof(stamp),"%Y-%m-%d_%H-%M-%S",&local);
    for (unsigned attempt=0;attempt<100;++attempt) {
        char basename[128]{};
        std::snprintf(basename,sizeof(basename),"Print-RC_%s_%06lld_%ld_%u.png",
                      stamp,static_cast<long long>(us),static_cast<long>(getpid()),attempt);
        const std::string path=(std::filesystem::path(dir)/basename).string();
        int fd=open(path.c_str(),O_WRONLY|O_CREAT|O_EXCL|O_CLOEXEC,0600);
        if (fd<0) {
            if (errno==EEXIST) continue;
            std::perror("Print RC: falha ao criar a imagem");
            return false;
        }
        size_t offset=0;
        bool ok=true;
        while(offset<png.size()) {
            ssize_t n=write(fd,png.data()+offset,png.size()-offset);
            if (n<0 && errno==EINTR) continue;
            if (n<=0) { ok=false; break; }
            offset+=static_cast<size_t>(n);
        }
        if (close(fd)!=0) ok=false;
        if (!ok) {
            std::perror("Print RC: erro ao gravar PNG");
            unlink(path.c_str());
            return false;
        }
        std::cout << "Print RC: imagem salva: " << path << "\n";
        return true;
    }
    std::cerr << "Print RC: nao foi possivel criar nome exclusivo de imagem.\n";
    return false;
}
