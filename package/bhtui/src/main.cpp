#include <algorithm>
#include <csignal>
#include <filesystem>
#include <iostream>
#include <string>
#include <string_view>
#include <vector>

#include <sys/ioctl.h>
#include <sys/stat.h>
#include <unistd.h>

#include <ox/core/core.hpp>

#include "command.h"
#include "gameboy.h"
#include "menu_app.h"
#include "menu_builder.h"
#include "output_view.h"

namespace {

/// The escape library takes the terminal width from stdout but the height from stdin.
/// The Flipper app runs `bhtui > /dev/tty1` from the serial console, where stdin is a
/// serial port with no size (0 rows), so the menu would draw nothing. While bhtui runs,
/// give stdin's terminal the size of the one we draw on.
class MatchInputSize {
   public:
    MatchInputSize()
    {
        struct stat in {};
        struct stat out {};
        if (!::isatty(STDIN_FILENO) || !::isatty(STDOUT_FILENO) ||
            ::fstat(STDIN_FILENO, &in) == -1 || ::fstat(STDOUT_FILENO, &out) == -1 ||
            in.st_rdev == out.st_rdev) {
            return;
        }
        auto size = winsize{};
        if (::ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == -1 ||
            ::ioctl(STDIN_FILENO, TIOCGWINSZ, &original_) == -1) {
            return;
        }
        restore_ = ::ioctl(STDIN_FILENO, TIOCSWINSZ, &size) == 0;
    }

    ~MatchInputSize()
    {
        if (restore_) { ::ioctl(STDIN_FILENO, TIOCSWINSZ, &original_); }
    }

    MatchInputSize(MatchInputSize const&) = delete;
    auto operator=(MatchInputSize const&) -> MatchInputSize& = delete;

   private:
    winsize original_{};
    bool restore_ = false;
};

/// The user's payload scripts on the boot partition, the same folder the Flipper app's
/// "Scan for Scripts" lists. Backup and temp copies are skipped.
auto find_scripts(std::filesystem::path const& dir) -> std::vector<std::filesystem::path>
{
    auto scripts = std::vector<std::filesystem::path>{};
    auto ec = std::error_code{};
    for (auto const& entry : std::filesystem::directory_iterator{dir, ec}) {
        if (!entry.is_regular_file(ec)) { continue; }
        auto const name = entry.path().filename().string();
        auto const ext = entry.path().extension().string();
        if (name.empty() || name.front() == '.' || name.back() == '~' || ext == ".bak" ||
            ext == ".orig" || ext == ".tmp" || ext == ".swp" ||
            name.find(".bak") != std::string::npos) {
            continue;
        }
        scripts.push_back(entry.path());
    }
    std::sort(scripts.begin(), scripts.end());
    return scripts;
}

/// Runs a script in the foreground so the Flipper's arrows, OK and Back reach it, then
/// waits for OK so its output stays on the LCD.
auto make_script_command(std::filesystem::path const& script) -> std::string
{
    auto const interpreter = script.extension() == ".py" ? "python3" : "bash";
    return std::string{"cd '"} + script.parent_path().string() + "' && " + interpreter +
           " '" + script.string() + "'; printf '\\n[OK = back to menu]'; read _";
}

auto build_menu() -> std::vector<MenuItem>
{
    std::filesystem::create_directories(rom_directory());
    auto const roms = find_roms(rom_directory());
    auto const scripts = find_scripts("/boot/bh/scripts");

    auto builder = menu_();
    builder.menu("Blackhat", "").interactive("Blackhat Menu", "blackhat-menu");
    for (auto const& script : scripts) {
        if (script.filename() == "blackhat-menu") { continue; }
        builder.interactive(script.filename().string(), make_script_command(script));
    }
    builder.end()
        .menu("Networking", "")
        .interactive("Network Manager", "nmtui")
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
            builder.interactive(rom.filename().string(), make_rom_command(rom));
        }
    }
    builder.end()
        .menu("System", "")
        .item("System Info", "fastfetch")
        .item("Uptime/Load", "uptime")
        .item("Kernel/OS", "uname -a")
        .item("Kernel Logs", "dmesg")
        .interactive("Top", "htop")
        .item("Memory", "free -h")
        .item("CPU Info", "lscpu")
        .item("USB Info", "lsusb")
        .item("Block Devices", "lsblk")
        .end()
        .menu("Files", "")
        .item("List Files", "ls -lah")
        .item("Disk Usage", "du -sh ~/* 2>/dev/null")
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
    auto const match_size = MatchInputSize{};

    // Built once so the menu keeps its position between commands.
    auto app = MenuApp{build_menu()};
    while (true) {
        auto code = 0;
        {
            auto term = ox::Terminal{};
            code = ox::process_events(term, app);
        }

        auto const command = app.take_command();
        if (!command) { return code; }

        // Clear first, the Linux console (the LCD) has no alternate screen, so the menu
        // is still showing.
        std::cout << "\x1b[H\x1b[2J$ " << command->text << std::endl;
        auto const result = run_command(command->text, !command->interactive);

        if (result.interrupted) {
            // The Flipper's Back button sends Ctrl+C and leaves its TUI screen, and going
            // back in types the bhtui start command. Wait for a line so that it lands
            // here instead of being read as menu keys.
            // The menu's SIGINT handler only sets a flag and is re-installed each time
            // the menu opens, so restore the default to let Ctrl+C quit at the prompt.
            std::signal(SIGINT, SIG_DFL);
            std::cout << "\n[exit " << result.status
                      << "] Press Enter to return to the menu..." << std::flush;
            auto line = std::string{};
            if (!std::getline(std::cin, line)) { return result.status; }
            continue;
        }

        // Full screen programs and games leave nothing to read.
        if (command->interactive) { continue; }

        auto view = OutputView{command->text, result.output, result.status};
        auto term = ox::Terminal{};
        if (auto const rc = ox::process_events(term, view); rc != 0) { return rc; }
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
