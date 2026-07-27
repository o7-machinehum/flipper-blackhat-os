#pragma once

#include <filesystem>
#include <string>
#include <vector>

inline auto rom_directory() -> std::filesystem::path { return "/mnt/roms"; }

auto find_roms(std::filesystem::path const& directory)
    -> std::vector<std::filesystem::path>;
auto make_rom_command(std::filesystem::path const& rom) -> std::string;
auto is_rom_command(std::string const& command) -> bool;

auto play_rom(std::filesystem::path const& rom) -> int;
auto run_mgba_session(std::filesystem::path const& rom) -> int;
