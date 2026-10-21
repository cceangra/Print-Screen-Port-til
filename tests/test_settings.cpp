// Teste de configuracao e armazenamento seguro, sem sessao X11.
// GPL-3.0-or-later
#include "../src/settings.hpp"
#include <cassert>
#include <iterator>

int main() {
    char tmp[]="/tmp/print-rc-teste-XXXXXX";
    char* created=mkdtemp(tmp);
    assert(created);
    const std::filesystem::path dir(created);
    const std::filesystem::path cfg=dir/"opcoes.conf";
    {
        std::ofstream out(cfg);
        out << "save_dir=" << dir.string() << "\ncopy_clipboard=0\n";
    }
    assert(setenv("PRINT_RC_CONFIG",cfg.c_str(),1)==0);
    PrintRcSettings options;
    assert(print_rc_load_settings(options));
    assert(options.save_dir==dir.string());
    assert(!options.copy_clipboard);

    // O gravador recebe um vetor de bytes PNG e nao sobrescreve arquivos.
    // O teste foca integridade e exclusividade da escrita; encode de PNG e testado pelo self-test.
    const std::vector<unsigned char> fake_png={0x89,'P','N','G',13,10,26,10,1,2,3,4,5};
    assert(print_rc_save_png(fake_png,options.save_dir));
    assert(print_rc_save_png(fake_png,options.save_dir));
    size_t count=0;
    for(const auto& entry:std::filesystem::directory_iterator(dir)) {
        if(entry.path().extension()!=".png") continue;
        std::ifstream in(entry.path(),std::ios::binary);
        std::vector<unsigned char> actual(
            (std::istreambuf_iterator<char>(in)),std::istreambuf_iterator<char>());
        assert(actual==fake_png);
        ++count;
    }
    assert(count==2);
    // Internal destinations survive relocation; traversal is rejected.
    std::filesystem::create_directories(dir/"old/config");
    std::filesystem::create_directories(dir/"old/capturas");
    {
        std::ofstream out(dir/"old/config/opcoes.conf");
        out<<"save_dir="<<(dir/"old/capturas").string()<<"\ncopy_clipboard=0\nsave_dir_relative=capturas\n";
    }
    std::filesystem::rename(dir/"old",dir/"moved (ç)");
    auto moved=dir/"moved (ç)";
    setenv("PRINT_RC_CONFIG",(moved/"config/opcoes.conf").c_str(),1);
    PrintRcSettings relocated;
    assert(print_rc_load_settings(relocated));
    assert(relocated.save_dir==(moved/"capturas").string());
    {
        std::ofstream out(moved/"config/opcoes.conf");
        out<<"save_dir=/tmp\ncopy_clipboard=0\nsave_dir_relative=../outside\n";
    }
    PrintRcSettings invalid;
    assert(!print_rc_load_settings(invalid));
    std::filesystem::remove_all(dir);
    std::cout << "OK: config lida e duas imagens gravadas sem sobrescrever.\n";
}
