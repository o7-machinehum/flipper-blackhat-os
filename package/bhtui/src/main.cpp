#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

#include <ox/core/core.hpp>

#include "menu_app.h"
#include "menu_builder.h"

int main()
{
    try {
        auto menu = menu_()
          .menu("Networking", "")
              .item("Network Manager", "nmtui")
              .item("IP Address", "ip a")
              .item("Routes", "ip r")
              .item("DNS (resolvectl)", "resolvectl status")
              .item("Sockets", "ss -tulpen")
              .item("Ping", "ping -c 4 1.1.1.1")
              .item("Firewall (nft)", "nft list ruleset")
          .end()
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
          .end()
          .build();

        std::string output;
        int code = 0;
        {
            auto term = ox::Terminal{};
            auto app = MenuApp{std::move(menu), output};
            code = ox::process_events(term, app);
        }
        if (!output.empty()) {
            std::cout << output << '\n';
            return std::system(output.c_str());
        }
        return code;
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
