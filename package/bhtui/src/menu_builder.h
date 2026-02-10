#pragma once

#include <string>
#include <vector>

#include "menu_item.h"

class MenuBuilder {
   public:
    MenuBuilder();

    MenuBuilder& menu(std::string display, std::string print);
    MenuBuilder& submenu(std::string display, std::string print);
    MenuBuilder& item(std::string display, std::string print);
    MenuBuilder& end();

    auto build() -> std::vector<MenuItem>;

   private:
    std::vector<MenuItem> root_;
    std::vector<MenuItem>* current_;
    std::vector<std::vector<MenuItem>*> stack_;
};

inline auto menu_() -> MenuBuilder { return MenuBuilder{}; }
