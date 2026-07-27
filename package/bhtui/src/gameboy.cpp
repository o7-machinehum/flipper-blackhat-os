#include "gameboy.h"

#include <algorithm>
#include <array>
#include <cerrno>
#include <chrono>
#include <cctype>
#include <cstdint>
#include <cstring>
#include <dlfcn.h>
#include <stdexcept>
#include <string>
#include <string_view>
#include <system_error>
#include <thread>

#include <fcntl.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include <poll.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

namespace {

constexpr auto BhtuiPath = "/usr/local/bin/bhtui";
constexpr auto RomCommandPrefix = std::string_view{"/usr/local/bin/bhtui --play-rom "};

// Single-byte UART protocol shared with blackhat_scene_tui.c.
constexpr std::uint8_t ButtonUpPressed = 0x80;
constexpr std::uint8_t ButtonUpReleased = 0x81;
constexpr std::uint8_t ButtonDownPressed = 0x82;
constexpr std::uint8_t ButtonDownReleased = 0x83;
constexpr std::uint8_t ButtonLeftPressed = 0x84;
constexpr std::uint8_t ButtonLeftReleased = 0x85;
constexpr std::uint8_t ButtonRightPressed = 0x86;
constexpr std::uint8_t ButtonRightReleased = 0x87;
constexpr std::uint8_t ButtonAPressed = 0x88;
constexpr std::uint8_t ButtonAReleased = 0x89;
constexpr std::uint8_t ButtonBPressed = 0x8a;
constexpr std::uint8_t ButtonBReleased = 0x8b;
constexpr std::uint8_t ButtonSelectPressed = 0x8c;
constexpr std::uint8_t ButtonSelectReleased = 0x8d;
constexpr std::uint8_t ButtonStartPressed = 0x8e;
constexpr std::uint8_t ButtonStartReleased = 0x8f;
constexpr std::uint8_t QuitGame = 0x90;
constexpr std::uint8_t GameModeStarted = 0x91;
constexpr std::uint8_t GameModeStopped = 0x92;

auto lower_extension(std::filesystem::path const& path) -> std::string
{
    auto extension = path.extension().string();
    std::transform(
        extension.begin(),
        extension.end(),
        extension.begin(),
        [](unsigned char c) { return static_cast<char>(std::tolower(c)); }
    );
    return extension;
}

auto is_rom(std::filesystem::path const& path) -> bool
{
    auto const extension = lower_extension(path);
    return extension == ".gb" || extension == ".gbc";
}

auto shell_quote(std::string const& text) -> std::string
{
    auto quoted = std::string{"'"};
    for (auto const c : text) {
        if (c == '\'') {
            quoted += "'\\''";
        }
        else {
            quoted += c;
        }
    }
    quoted += '\'';
    return quoted;
}

class RawTerminal {
   public:
    RawTerminal()
    {
        if (::tcgetattr(STDIN_FILENO, &original_) == -1) { return; }

        auto raw = original_;
        ::cfmakeraw(&raw);
        if (::tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0) { active_ = true; }
    }

    ~RawTerminal()
    {
        if (active_) { ::tcsetattr(STDIN_FILENO, TCSANOW, &original_); }
    }

    RawTerminal(RawTerminal const&) = delete;
    RawTerminal& operator=(RawTerminal const&) = delete;

   private:
    termios original_{};
    bool active_{false};
};

class VirtualKeyboard {
   public:
    VirtualKeyboard()
    {
        fd_ = ::open("/dev/uinput", O_WRONLY | O_NONBLOCK);
        if (fd_ == -1) {
            throw std::system_error(errno, std::generic_category(), "open /dev/uinput");
        }

        if (::ioctl(fd_, UI_SET_EVBIT, EV_KEY) == -1) { fail("enable key events"); }
        for (auto const key : Keys) {
            if (::ioctl(fd_, UI_SET_KEYBIT, key) == -1) { fail("enable key"); }
        }

        auto setup = uinput_setup{};
        setup.id.bustype = BUS_VIRTUAL;
        std::strncpy(setup.name, "Flipper Blackhat Controls", UINPUT_MAX_NAME_SIZE - 1);

        if (::ioctl(fd_, UI_DEV_SETUP, &setup) == -1) { fail("configure uinput"); }
        if (::ioctl(fd_, UI_DEV_CREATE) == -1) { fail("create uinput device"); }
        created_ = true;
        std::this_thread::sleep_for(std::chrono::milliseconds{100});
    }

    ~VirtualKeyboard()
    {
        for (auto const key : Keys) { emit_key(key, false); }
        if (created_) { ::ioctl(fd_, UI_DEV_DESTROY); }
        if (fd_ != -1) { ::close(fd_); }
    }

    VirtualKeyboard(VirtualKeyboard const&) = delete;
    VirtualKeyboard& operator=(VirtualKeyboard const&) = delete;

    void emit_key(unsigned short key, bool pressed)
    {
        if (fd_ == -1) { return; }

        auto event = input_event{};
        event.type = EV_KEY;
        event.code = key;
        event.value = pressed ? 1 : 0;
        ::write(fd_, &event, sizeof(event));

        event = {};
        event.type = EV_SYN;
        event.code = SYN_REPORT;
        ::write(fd_, &event, sizeof(event));
    }

   private:
    static constexpr auto Keys =
        std::array<unsigned short, 8>{
            KEY_UP,
            KEY_DOWN,
            KEY_LEFT,
            KEY_RIGHT,
            KEY_X,
            KEY_Z,
            KEY_BACKSPACE,
            KEY_ENTER,
        };

    [[noreturn]] void fail(char const* operation)
    {
        auto const error = errno;
        ::close(fd_);
        fd_ = -1;
        throw std::system_error(error, std::generic_category(), operation);
    }

   private:
    int fd_{-1};
    bool created_{false};
};

void send_game_mode(std::uint8_t mode)
{
    auto const fd = ::open("/dev/ttyS0", O_WRONLY | O_NOCTTY);
    if (fd == -1) { return; }
    ::write(fd, &mode, 1);
    ::close(fd);
}

void handle_button(VirtualKeyboard& keyboard, std::uint8_t button)
{
    switch (button) {
        case ButtonUpPressed: keyboard.emit_key(KEY_UP, true); break;
        case ButtonUpReleased: keyboard.emit_key(KEY_UP, false); break;
        case ButtonDownPressed: keyboard.emit_key(KEY_DOWN, true); break;
        case ButtonDownReleased: keyboard.emit_key(KEY_DOWN, false); break;
        case ButtonLeftPressed: keyboard.emit_key(KEY_LEFT, true); break;
        case ButtonLeftReleased: keyboard.emit_key(KEY_LEFT, false); break;
        case ButtonRightPressed: keyboard.emit_key(KEY_RIGHT, true); break;
        case ButtonRightReleased: keyboard.emit_key(KEY_RIGHT, false); break;
        case ButtonAPressed: keyboard.emit_key(KEY_X, true); break;
        case ButtonAReleased:
            std::this_thread::sleep_for(std::chrono::milliseconds{50});
            keyboard.emit_key(KEY_X, false);
            break;
        case ButtonBPressed: keyboard.emit_key(KEY_Z, true); break;
        case ButtonBReleased: keyboard.emit_key(KEY_Z, false); break;
        case ButtonSelectPressed: keyboard.emit_key(KEY_BACKSPACE, true); break;
        case ButtonSelectReleased: keyboard.emit_key(KEY_BACKSPACE, false); break;
        case ButtonStartPressed: keyboard.emit_key(KEY_ENTER, true); break;
        case ButtonStartReleased: keyboard.emit_key(KEY_ENTER, false); break;
        default: break;
    }
}

auto spawn_mgba(std::filesystem::path const& rom) -> pid_t
{
    auto const pid = ::fork();
    if (pid != 0) {
        if (pid > 0) { ::setpgid(pid, pid); }
        return pid;
    }

    ::setpgid(0, 0);

    auto const null_fd = ::open("/dev/null", O_RDONLY);
    if (null_fd != -1) {
        ::dup2(null_fd, STDIN_FILENO);
        ::close(null_fd);
    }

    auto const tty_fd = ::open("/dev/tty1", O_WRONLY | O_NOCTTY);
    if (tty_fd != -1) {
        ::dup2(tty_fd, STDOUT_FILENO);
        ::dup2(tty_fd, STDERR_FILENO);
        ::close(tty_fd);
    }

    ::execl(
        "/usr/bin/xinit",
        "xinit",
        BhtuiPath,
        "--mgba-session",
        rom.c_str(),
        "--",
        ":0",
        "vt2",
        "-nolisten",
        "tcp",
        static_cast<char*>(nullptr)
    );
    _exit(127);
}

auto stop_child(pid_t pid) -> int
{
    ::kill(-pid, SIGTERM);

    auto status = 0;
    for (auto attempts = 0; attempts < 30; ++attempts) {
        auto const result = ::waitpid(pid, &status, WNOHANG);
        if (result == pid) {
            if (WIFEXITED(status)) { return WEXITSTATUS(status); }
            if (WIFSIGNALED(status) && WTERMSIG(status) == SIGTERM) { return 0; }
            return 1;
        }
        if (result == -1) { return 1; }
        std::this_thread::sleep_for(std::chrono::milliseconds{100});
    }

    ::kill(-pid, SIGKILL);
    ::waitpid(pid, &status, 0);
    return 0;
}

auto run_and_wait(char const* program,
                  char const* argument1,
                  char const* argument2,
                  char const* argument3,
                  char const* argument4) -> int
{
    auto const pid = ::fork();
    if (pid == -1) { return 1; }
    if (pid == 0) {
        ::execl(
            program,
            program,
            argument1,
            argument2,
            argument3,
            argument4,
            static_cast<char*>(nullptr)
        );
        _exit(127);
    }

    auto status = 0;
    if (::waitpid(pid, &status, 0) == -1) { return 1; }
    return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
}

auto has_blackpants_hub() -> bool
{
    return run_and_wait("/usr/bin/lsusb", "-d", "0424:2514", nullptr, nullptr) ==
           0;
}

template <typename Function>
auto load_x11_function(void* library, char const* name) -> Function
{
    return reinterpret_cast<Function>(::dlsym(library, name));
}

void center_mgba_window()
{
    using Display = void;
    using Window = unsigned long;
    using OpenDisplay = Display* (*)(char const*);
    using DefaultScreen = int (*)(Display*);
    using RootWindow = Window (*)(Display*, int);
    using QueryTree =
        int (*)(Display*, Window, Window*, Window*, Window**, unsigned int*);
    using GetGeometry = int (*)(Display*,
                                Window,
                                Window*,
                                int*,
                                int*,
                                unsigned int*,
                                unsigned int*,
                                unsigned int*,
                                unsigned int*);
    using MoveWindow = int (*)(Display*, Window, int, int);
    using Flush = int (*)(Display*);
    using Free = int (*)(void*);
    using CloseDisplay = int (*)(Display*);

    auto* library = ::dlopen("libX11.so.6", RTLD_NOW | RTLD_LOCAL);
    if (library == nullptr) { return; }

    auto const open_display = load_x11_function<OpenDisplay>(library, "XOpenDisplay");
    auto const default_screen =
        load_x11_function<DefaultScreen>(library, "XDefaultScreen");
    auto const root_window = load_x11_function<RootWindow>(library, "XRootWindow");
    auto const query_tree = load_x11_function<QueryTree>(library, "XQueryTree");
    auto const get_geometry = load_x11_function<GetGeometry>(library, "XGetGeometry");
    auto const move_window = load_x11_function<MoveWindow>(library, "XMoveWindow");
    auto const flush = load_x11_function<Flush>(library, "XFlush");
    auto const free_memory = load_x11_function<Free>(library, "XFree");
    auto const close_display =
        load_x11_function<CloseDisplay>(library, "XCloseDisplay");
    if (open_display == nullptr || default_screen == nullptr ||
        root_window == nullptr || query_tree == nullptr ||
        get_geometry == nullptr || move_window == nullptr || flush == nullptr ||
        free_memory == nullptr || close_display == nullptr) {
        ::dlclose(library);
        return;
    }

    auto* display = open_display(nullptr);
    if (display == nullptr) {
        ::dlclose(library);
        return;
    }

    auto const root = root_window(display, default_screen(display));
    for (auto attempts = 0; attempts < 100; ++attempts) {
        auto returned_root = Window{};
        auto parent = Window{};
        auto* children = static_cast<Window*>(nullptr);
        auto child_count = 0U;
        if (query_tree(
                display,
                root,
                &returned_root,
                &parent,
                &children,
                &child_count
            ) &&
            child_count > 0) {
            auto geometry_root = Window{};
            auto root_x = 0;
            auto root_y = 0;
            auto root_width = 0U;
            auto root_height = 0U;
            auto root_border = 0U;
            auto root_depth = 0U;
            auto window_x = 0;
            auto window_y = 0;
            auto window_width = 0U;
            auto window_height = 0U;
            auto window_border = 0U;
            auto window_depth = 0U;

            auto const have_root_geometry = get_geometry(
                display,
                root,
                &geometry_root,
                &root_x,
                &root_y,
                &root_width,
                &root_height,
                &root_border,
                &root_depth
            );
            auto const have_window_geometry = get_geometry(
                display,
                children[0],
                &geometry_root,
                &window_x,
                &window_y,
                &window_width,
                &window_height,
                &window_border,
                &window_depth
            );
            if (have_root_geometry && have_window_geometry) {
                auto const x =
                    std::max(0, (static_cast<int>(root_width) -
                                 static_cast<int>(window_width)) /
                                    2);
                auto const y =
                    std::max(0, (static_cast<int>(root_height) -
                                 static_cast<int>(window_height)) /
                                    2);
                move_window(display, children[0], x, y);
                flush(display);
            }
        }
        if (children != nullptr) { free_memory(children); }
        std::this_thread::sleep_for(std::chrono::milliseconds{50});
    }

    close_display(display);
    ::dlclose(library);
}

}  // namespace

auto find_roms(std::filesystem::path const& directory)
    -> std::vector<std::filesystem::path>
{
    auto roms = std::vector<std::filesystem::path>{};
    for (auto const& entry : std::filesystem::directory_iterator{directory}) {
        if (entry.is_regular_file() && is_rom(entry.path())) {
            roms.push_back(entry.path());
        }
    }

    std::sort(roms.begin(), roms.end(), [](auto const& left, auto const& right) {
        return left.filename().string() < right.filename().string();
    });
    return roms;
}

auto make_rom_command(std::filesystem::path const& rom) -> std::string
{
    return std::string{RomCommandPrefix} + shell_quote(rom.string());
}

auto is_rom_command(std::string const& command) -> bool
{
    return command.starts_with(RomCommandPrefix);
}

auto play_rom(std::filesystem::path const& rom) -> int
{
    auto const expected_parent = std::filesystem::canonical(rom_directory());
    auto const selected_rom = std::filesystem::canonical(rom);
    if (selected_rom.parent_path() != expected_parent || !is_rom(selected_rom)) {
        throw std::runtime_error{"ROM must be a .gb or .gbc file in /mnt/roms"};
    }

    auto keyboard = VirtualKeyboard{};
    auto terminal = RawTerminal{};
    auto const child = spawn_mgba(selected_rom);
    if (child == -1) {
        throw std::system_error(errno, std::generic_category(), "start mGBA");
    }

    send_game_mode(GameModeStarted);
    auto stop_requested = false;
    auto status = 0;
    while (!stop_requested) {
        auto child_status = 0;
        auto const child_result = ::waitpid(child, &child_status, WNOHANG);
        if (child_result == child) {
            status = WIFEXITED(child_status) ? WEXITSTATUS(child_status) : 1;
            break;
        }
        if (child_result == -1) {
            status = 1;
            break;
        }

        auto input = pollfd{STDIN_FILENO, POLLIN, 0};
        auto const poll_result = ::poll(&input, 1, 100);
        if (poll_result <= 0 || !(input.revents & POLLIN)) { continue; }

        auto buttons = std::array<std::uint8_t, 32>{};
        auto const count = ::read(STDIN_FILENO, buttons.data(), buttons.size());
        for (auto i = ssize_t{0}; i < count; ++i) {
            auto const button = buttons[static_cast<std::size_t>(i)];
            if (button == QuitGame || button == 0x03) {
                stop_requested = true;
                break;
            }
            handle_button(keyboard, button);
        }
    }

    if (stop_requested) { status = stop_child(child); }
    send_game_mode(GameModeStopped);
    return status;
}

auto run_mgba_session(std::filesystem::path const& rom) -> int
{
    auto const rotation = has_blackpants_hub() ? "inverted" : "right";
    run_and_wait("/usr/bin/xrandr", "--output", "DSI-1", "--rotate", rotation);

    auto const pid = ::fork();
    if (pid == -1) { return 1; }
    if (pid == 0) {
        ::execl(
            "/usr/games/mgba",
            "mgba",
            "-3",
            rom.c_str(),
            static_cast<char*>(nullptr)
        );
        _exit(127);
    }

    center_mgba_window();

    auto status = 0;
    if (::waitpid(pid, &status, 0) == -1) { return 1; }
    return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
}
