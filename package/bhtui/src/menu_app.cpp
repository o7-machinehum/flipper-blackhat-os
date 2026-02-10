#include "menu_app.h"

#include <algorithm>
#include <string_view>
#include <utility>

#include <ox/put.hpp>

using namespace ox;

MenuApp::MenuApp(std::vector<MenuItem> menu, std::string& output)
    : menu_{std::move(menu)}, output_{output}
{
}

EventResponse MenuApp::handle_key_press(Key k)
{
    switch (k) {
        case Key::ArrowDown: select_next(1); return {};
        case Key::ArrowUp: select_next(-1); return {};
        case Key::ArrowLeft: go_back(); return {};
        case Key::ArrowRight:
        case Key::Enter:
            if (enter_selected()) { return QuitRequest{0}; }
            return {};
        default: return {};
    }
}

EventResponse MenuApp::handle_resize(Area)
{
    return {};
}

Terminal::Cursor MenuApp::handle_paint(Canvas c)
{
    fill(c, U' ');

    if (c.size.width < 32 || c.size.height < 8) {
        put(c, {0, 0}, "Terminal too small");
        return std::nullopt;
    }

    draw_menu(c);
    return std::nullopt;
}

auto MenuApp::current_items() -> std::vector<MenuItem>&
{
    auto* items = &menu_;
    for (auto index : path_) {
        if (index >= items->size()) { return *items; }
        items = &(*items)[index].children;
    }
    return *items;
}

auto MenuApp::current_items() const -> std::vector<MenuItem> const&
{
    auto const* items = &menu_;
    for (auto index : path_) {
        if (index >= items->size()) { return *items; }
        items = &(*items)[index].children;
    }
    return *items;
}

auto MenuApp::current_selection() -> std::size_t&
{
    return selections_.back();
}

auto MenuApp::current_selection() const -> std::size_t
{
    return selections_.back();
}

void MenuApp::select_next(int delta)
{
    auto const& items = current_items();
    if (items.empty()) {
        current_selection() = 0;
        return;
    }

    auto const size = static_cast<int>(items.size());
    auto index = static_cast<int>(current_selection());
    index = (index + delta + size) % size;
    current_selection() = static_cast<std::size_t>(index);
}

auto MenuApp::enter_selected() -> bool
{
    auto& items = current_items();
    if (items.empty()) { return false; }

    auto const selection = clamp_selection(current_selection(), items.size());
    auto& item = items[selection];
    if (item.children.empty()) {
        output_ = selected_print_path();
        return true;
    }

    path_.push_back(current_selection());
    selections_.push_back(0);
    return false;
}

void MenuApp::go_back()
{
    if (path_.empty()) { return; }
    path_.pop_back();
    selections_.pop_back();
}

auto MenuApp::breadcrumb() const -> std::string
{
    auto text = std::string{"Menu"};
    auto const* items = &menu_;
    for (auto index : path_) {
        if (index >= items->size()) { break; }
        text += " > " + (*items)[index].display;
        items = &(*items)[index].children;
    }
    return text;
}

auto MenuApp::selected_print_path() const -> std::string
{
    auto const& items = current_items();
    if (items.empty()) { return ""; }

    auto out = std::string{};
    auto const* walk = &menu_;
    for (auto index : path_) {
        if (index >= walk->size()) { break; }
        if (!out.empty()) { out += ' '; }
        out += (*walk)[index].print;
        walk = &(*walk)[index].children;
    }

    auto const selection = clamp_selection(current_selection(), items.size());
    if (!out.empty()) { out += ' '; }
    out += items[selection].print;
    return out;
}

auto MenuApp::clamp_selection(std::size_t selection, std::size_t size) -> std::size_t
{
    if (size == 0) { return 0; }
    return selection >= size ? size - 1 : selection;
}

auto MenuApp::items_at_path(std::vector<std::size_t> const& path) -> std::vector<MenuItem>*
{
    auto* items = &menu_;
    for (auto index : path) {
        if (index >= items->size()) { return nullptr; }
        items = &(*items)[index].children;
    }
    return items;
}

auto MenuApp::items_at_path(std::vector<std::size_t> const& path) const
    -> std::vector<MenuItem> const*
{
    auto const* items = &menu_;
    for (auto index : path) {
        if (index >= items->size()) { return nullptr; }
        items = &(*items)[index].children;
    }
    return items;
}

void MenuApp::draw_column(Canvas c,
                          std::vector<MenuItem> const& items,
                          std::size_t selection,
                          int x,
                          int y,
                          int width,
                          bool active)
{
    auto const max_y = c.size.height - 2;
    for (std::size_t i = 0; i < items.size(); ++i) {
        auto const row = y + static_cast<int>(i);
        if (row >= max_y) { break; }

        auto line = items[i].display;
        auto const selected = (i == selection);
        if (static_cast<int>(line.size()) > width - 1) {
            line.resize(static_cast<std::size_t>(std::max(0, width - 1)));
        }

        if (selected) {
            put(c, {x, row}, line | (active ? Trait::Standout : Trait::Dim));
        }
        else if (active) {
            put(c, {x, row}, line);
        }
        else {
            put(c, {x, row}, line | Trait::Dim);
        }
    }
}

void MenuApp::draw_menu(Canvas c)
{
    auto const title = std::string_view{"Blackhat TUI Menu"};
    auto const title_x = std::max(0, (c.size.width - (int)title.size()) / 2);
    put(c, {title_x, 0}, title | Trait::Bold);

    auto const crumb = breadcrumb();
    put(c, {2, 2}, crumb | Trait::Dim);

    auto const start_y = 4;
    auto const left_margin = 2;
    auto const gap = 1;
    auto const available = c.size.width - left_margin * 2 - gap * 2;
    auto const column_width = std::max(1, available / 4);

    auto const* level0 = items_at_path(path_);
    if (level0 == nullptr) { return; }
    auto const sel0 = clamp_selection(current_selection(), level0->size());

    auto path1 = path_;
    path1.push_back(sel0);
    auto const* level1 = items_at_path(path1);
    auto const sel1 =
        (level1 && selections_.size() > path_.size() + 1)
            ? clamp_selection(selections_[path_.size() + 1], level1->size())
            : 0U;

    auto path2 = path1;
    if (level1 && !level1->empty()) { path2.push_back(sel1); }
    auto const* level2 = (level1 && !level1->empty()) ? items_at_path(path2) : nullptr;
    auto const sel2 =
        (level2 && selections_.size() > path_.size() + 2)
            ? clamp_selection(selections_[path_.size() + 2], level2->size())
            : 0U;

    draw_column(c, *level0, sel0, left_margin, start_y, column_width, true);

    if (level1 && !level1->empty()) {
        auto const x1 = left_margin + column_width + gap;
        draw_column(c, *level1, sel1, x1, start_y, column_width, false);
    }

    if (level2 && !level2->empty()) {
        auto const x2 = left_margin + (column_width + gap) * 2;
        draw_column(c, *level2, sel2, x2, start_y, column_width, false);
    }

    auto const hint = std::string_view{"Up/Down, Left to go back, Right/Enter to run"};
    put(c, {2, c.size.height - 2}, hint | Trait::Dim);
}
