#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <string>
#include <string_view>
#include <vector>

#include <ox/core/core.hpp>

#include "gameboy.h"
#include "menu_app.h"
#include "menu_builder.h"

namespace {

auto build_menu() -> std::vector<MenuItem>
{
    std::filesystem::create_directories(rom_directory());
    auto const roms = find_roms(rom_directory());

    auto builder = menu_();
    builder.menu("Networking", "")
        .item("Network Manager", "nmtui")
        .item("IP Address", "ip a")
        .item("Routes", "ip r")
        .item("DNS (resolvectl)", "resolvectl status")
        .item("Sockets", "ss -tulpen")
        .item("Ping", "ping -c 4 1.1.1.1")
        .item("Firewall (nft)", "nft list ruleset")
        .end()
        .menu("Gameboy Colour", "");
    if (roms.empty()) {
        builder.item("No ROMs found", "");
    }
    else {
        for (auto const& rom : roms) {
            builder.item(rom.filename().string(), make_rom_command(rom));
        }
    }
    builder.end()
        .menu("System", "")
        .item("System Info", "fastfetch")
        .item("Uptime/Load", "uptime")
        .item("Kernel/OS", "uname -a")
        .item("Kernel Logs", "dmesg")
        .item("Top", "timeout 5 htop")
        .item("Memory", "free -h")
        .item("CPU Info", "lscpu")
        .item("USB Info", "lsusb")
        .item("Block Devices", "lsblk")
        .end()
        .menu("Files", "")
        .item("List Files", "ls -lah")
        .item("Disk Usage", "du -sh *")
        .item("Filesystem Usage", "df -h")
        .end()
        .menu("Services", "")
        .item("Service Status", "systemctl --failed")
        .item("All Services", "systemctl list-units --type=service")
        .item("Timers", "systemctl list-timers")
        .item("Startup Time", "systemd-analyze")
        .end()
        .menu("Storage", "")
        .item("fstab", "cat /etc/fstab")
        .item("blkid", "blkid")
        .end()
        .menu("Security", "")
        .item("Who Is Logged In", "who")
        .item("Sudo Version", "sudo -V | head -n 1")
        .item("Open Ports", "ss -lntup")
        .end();
    return builder.build();
}

auto run_menu() -> int
{
    while (true) {
        auto menu = build_menu();
        std::string output;
        int code = 0;
        {
            auto term = ox::Terminal{};
            auto app = MenuApp{std::move(menu), output};
            code = ox::process_events(term, app);
        }
        if (!output.empty()) {
            std::cout << output << '\n';
            auto const result = std::system(output.c_str());
            if (is_rom_command(output)) { continue; }
            return result;
        }
        return code;
    }
}

}  // namespace

int main(int argc, char** argv)
{
    try {
        if (argc == 3 && std::string_view{argv[1]} == "--play-rom") {
            return play_rom(argv[2]);
        }
        if (argc == 3 && std::string_view{argv[1]} == "--mgba-session") {
            return run_mgba_session(argv[2]);
        }
        if (argc != 1) {
            std::cerr << "Usage: bhtui [--play-rom ROM | --mgba-session ROM]\n";
            return 2;
        }
        return run_menu();
    }
    catch (std::exception const& e) {
        std::cerr << "Error: " << e.what() << '\n';
        return 1;
    }
    catch (...) {
        std::cerr << "Unknown error\n";
        return 1;
    }
}
