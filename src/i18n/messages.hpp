#pragma once
#include "generated.hpp"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

inline bool prc_portuguese() {
    static const bool portuguese=[] {
        std::string value;
        const char* override=std::getenv("PRINT_RC_LANG");
        if(override && *override) value=override;
        if(value.empty()) {
            const char* config=std::getenv("PRINT_RC_CONFIG");
            if(config && *config) {
                std::string path=config;
                const auto slash=path.find_last_of('/');
                if(slash!=std::string::npos) {
                    path.resize(slash+1);path+="language";
                    FILE* file=std::fopen(path.c_str(),"r");
                    if(file) {char buffer[64]{};if(std::fgets(buffer,sizeof(buffer),file)) value=buffer;std::fclose(file);}
                }
            }
        }
        if(value.empty()) for(const char* name:{"LC_ALL","LC_MESSAGES","LANG"}) {
            const char* env=std::getenv(name);
            if(env && *env) {value=env;break;}
        }
        return value.size()>=2 && (value[0]=='p'||value[0]=='P') && (value[1]=='t'||value[1]=='T')
            && (value.size()==2 || value[2]=='_' || value[2]=='-' || value[2]=='.' || value[2]=='\n');
    }();
    return portuguese;
}
inline const char* prc_tr(const char* id) {
    for(const auto& message:kPrcMessages)
        if(std::strcmp(id,message.id)==0) return prc_portuguese()?message.pt:message.en;
    return id; // CI rejects unknown IDs in source.
}
// Core X11 fixed fonts use Latin-1. Convert catalog UTF-8 labels explicitly;
// terminal/diagnostic output remains UTF-8. No font or GUI framework is loaded.
inline std::string prc_x11_label(const char* id) {
    const auto* text=reinterpret_cast<const unsigned char*>(prc_tr(id));
    std::string result;
    while(*text) {
        if(*text<128) {result+=static_cast<char>(*text++);continue;}
        if((*text==0xc2 || *text==0xc3) && text[1]>=0x80 && text[1]<=0xbf) {
            result+=static_cast<char>((text[0]&3)*64+(text[1]&63));text+=2;
        } else {result+='?';++text;}
    }
    return result;
}
