#pragma once

#include <string>

struct CommandResult {
    int status = 0;
    bool interrupted = false;  // Ctrl+C was pressed while the command ran.
    std::string output;        // Combined stdout and stderr, only when captured.
};

/// Runs \p command with /bin/sh on the current terminal. With \p capture, its output
/// is shown as it arrives and also kept in the result.
auto run_command(std::string const& command, bool capture) -> CommandResult;
