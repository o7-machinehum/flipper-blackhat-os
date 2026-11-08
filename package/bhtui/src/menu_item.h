#pragma once

#include <string>
#include <vector>

struct MenuItem {
    std::string display;
    std::string print;
    std::vector<MenuItem> children;
    // Runs full screen on the terminal instead of having its output shown in a viewer.
    bool interactive = false;
};
