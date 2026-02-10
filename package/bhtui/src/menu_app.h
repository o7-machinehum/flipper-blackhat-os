#pragma once

#include <string>
#include <vector>

#include <ox/core/core.hpp>

#include "menu_item.h"

class MenuApp {
   public:
    MenuApp(std::vector<MenuItem> menu, std::string& output);

    ox::EventResponse handle_key_press(ox::Key k);
    ox::EventResponse handle_resize(ox::Area);
    ox::Terminal::Cursor handle_paint(ox::Canvas c);

   private:
    std::vector<MenuItem> menu_;
    std::string& output_;

    std::vector<std::size_t> path_;
    std::vector<std::size_t> selections_{0};

   private:
    auto current_items() -> std::vector<MenuItem>&;
    auto current_items() const -> std::vector<MenuItem> const&;

    auto current_selection() -> std::size_t&;
    auto current_selection() const -> std::size_t;

    void select_next(int delta);
    auto enter_selected() -> bool;
    void go_back();

    auto breadcrumb() const -> std::string;
    auto selected_print_path() const -> std::string;

    static auto clamp_selection(std::size_t selection, std::size_t size) -> std::size_t;

    auto items_at_path(std::vector<std::size_t> const& path) -> std::vector<MenuItem>*;
    auto items_at_path(std::vector<std::size_t> const& path) const
        -> std::vector<MenuItem> const*;

    void draw_column(ox::Canvas c,
                     std::vector<MenuItem> const& items,
                     std::size_t selection,
                     int x,
                     int y,
                     int width,
                     bool active);
    void draw_menu(ox::Canvas c);
};
