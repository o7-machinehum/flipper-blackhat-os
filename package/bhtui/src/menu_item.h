#pragma once

#include <string>
#include <vector>

struct MenuItem {
    std::string display;
    std::string print;
    std::vector<MenuItem> children;
};
