#include "command.h"

#include <array>
#include <cerrno>
#include <csignal>
#include <cstdio>
#include <iostream>
#include <string_view>
#include <system_error>

#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

namespace {

// Output past this is dropped from the front, the end is the part worth reading.
constexpr auto max_output = std::size_t{1024 * 1024};

volatile std::sig_atomic_t interrupted = 0;

void note_interrupt(int) { interrupted = 1; }

/// Records Ctrl+C while a command runs. std::system() ignores it instead, which hides
/// whether it was pressed. The child still gets the default action, exec resets
/// caught signals.
class InterruptGuard {
   public:
    InterruptGuard()
    {
        interrupted = 0;
        struct sigaction action {};
        action.sa_handler = note_interrupt;
        sigemptyset(&action.sa_mask);
        ::sigaction(SIGINT, &action, &old_int_);
        ::sigaction(SIGQUIT, &action, &old_quit_);
    }

    ~InterruptGuard()
    {
        ::sigaction(SIGINT, &old_int_, nullptr);
        ::sigaction(SIGQUIT, &old_quit_, nullptr);
    }

    InterruptGuard(InterruptGuard const&) = delete;
    auto operator=(InterruptGuard const&) -> InterruptGuard& = delete;

   private:
    struct sigaction old_int_ {};
    struct sigaction old_quit_ {};
};

auto decode_status(int status) -> int
{
    if (WIFEXITED(status)) { return WEXITSTATUS(status); }
    if (WIFSIGNALED(status)) { return 128 + WTERMSIG(status); }
    return 1;
}

void write_all(int fd, char const* data, std::size_t size)
{
    while (size > 0) {
        auto const written = ::write(fd, data, size);
        if (written == -1) {
            if (errno == EINTR) { continue; }
            return;
        }
        data += written;
        size -= static_cast<std::size_t>(written);
    }
}

auto screen_rows() -> int
{
    auto size = winsize{};
    if (::ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == -1 || size.ws_row == 0) { return 24; }
    return size.ws_row;
}

enum class ReadResult { Data, Empty, End };

/// Reads what is waiting in \p fd, echoing it to stdout until \p echo_lines is used up.
auto read_available(int fd, std::string& output, int& echo_lines) -> ReadResult
{
    auto buffer = std::array<char, 4096>{};
    auto const count = ::read(fd, buffer.data(), buffer.size());
    if (count == -1) {
        return (errno == EINTR || errno == EAGAIN) ? ReadResult::Empty : ReadResult::End;
    }
    if (count == 0) { return ReadResult::End; }

    auto const size = static_cast<std::size_t>(count);
    auto echo = std::size_t{0};
    while (echo < size && echo_lines > 0) {
        if (buffer[echo++] == '\n') { --echo_lines; }
    }
    write_all(STDOUT_FILENO, buffer.data(), echo);
    output.append(buffer.data(), size);
    if (output.size() > max_output) { output.erase(0, output.size() - max_output); }
    return ReadResult::Data;
}

auto wait_for(pid_t pid) -> int
{
    auto status = 0;
    while (::waitpid(pid, &status, 0) == -1) {
        if (errno != EINTR) { return 127 << 8; }
    }
    return status;
}

}  // namespace

auto run_command(std::string const& command, bool capture) -> CommandResult
{
    auto fds = std::array<int, 2>{-1, -1};
    if (capture && ::pipe2(fds.data(), O_CLOEXEC) == -1) {
        throw std::system_error{errno, std::generic_category(), "pipe"};
    }

    std::cout.flush();
    std::fflush(stdout);
    auto const guard = InterruptGuard{};
    auto const pid = ::fork();
    if (pid == -1) {
        auto const error = errno;
        if (capture) {
            ::close(fds[0]);
            ::close(fds[1]);
        }
        throw std::system_error{error, std::generic_category(), "fork"};
    }
    if (pid == 0) {
        if (capture) {
            ::dup2(fds[1], STDOUT_FILENO);
            ::dup2(fds[1], STDERR_FILENO);
        }
        ::execl("/bin/sh", "sh", "-c", command.c_str(), static_cast<char*>(nullptr));
        _exit(127);
    }

    auto result = CommandResult{};
    auto status = 0;
    if (capture) {
        ::close(fds[1]);
        // Show output as it arrives until the screen is full, the viewer has the rest.
        // Scrolling through thousands of lines on the Linux console (the LCD) is slow.
        auto echo_lines = screen_rows() - 2;
        // Stop when the command exits, not at end of file. Anything it starts in the
        // background can hold the pipe open for much longer.
        auto exited = false;
        while (!exited) {
            auto input = pollfd{fds[0], POLLIN, 0};
            if (::poll(&input, 1, 100) > 0 &&
                read_available(fds[0], result.output, echo_lines) == ReadResult::End) {
                break;
            }
            exited = ::waitpid(pid, &status, WNOHANG) == pid;
        }
        if (exited) {
            ::fcntl(fds[0], F_SETFL, O_NONBLOCK);
            while (read_available(fds[0], result.output, echo_lines) == ReadResult::Data) {}
        }
        else {
            status = wait_for(pid);
        }
        ::close(fds[0]);
    }
    else {
        status = wait_for(pid);
    }

    result.status = decode_status(status);
    result.interrupted = interrupted == 1;
    return result;
}
