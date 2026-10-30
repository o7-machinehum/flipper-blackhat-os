#pragma once

#include <string>
#include <vector>

#include <ox/core/core.hpp>

#include "menu_item.h"

class MenuApp {
   public:
    explicit MenuApp(std::vector<MenuItem> menu);

    ox::EventResponse handle_key_press(ox::Key k);
    ox::EventResponse handle_resize(ox::Area);
    ox::Terminal::Cursor handle_paint(ox::Canvas c);

    /// Returns the command chosen by the user and clears it, empty if none.
    auto take_command() -> std::string;

   private:
    std::vector<MenuItem> menu_;
    std::string command_;

    // Indices of the submenus entered, and the highlighted row at each level.
    // Invariant: selections_.size() == path_.size() + 1
    std::vector<std::size_t> path_;
    std::vector<std::size_t> selections_{0};

    // Number of list rows visible on the last paint, used for paging.
    int page_rows_ = 1;

   private:
    auto current_items() const -> std::vector<MenuItem> const&;
    auto current_selection() -> std::size_t&;
    auto current_selection() const -> std::size_t;

    void select_next(int delta);
    void select_at(std::size_t index);
    auto enter_selected(bool run_leaf) -> bool;
    auto go_back() -> bool;

    auto breadcrumb() const -> std::string;
    auto selected_print_path() const -> std::string;

    void draw_column(ox::Canvas c,
                     std::vector<MenuItem> const& items,
                     std::size_t selection,
                     int x,
                     int y,
                     int width,
                     int rows,
                     bool active);
    void draw_menu(ox::Canvas c);
};
