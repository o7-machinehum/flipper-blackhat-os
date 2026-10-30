#include "menu_app.h"

#include <algorithm>
#include <limits>
#include <string_view>
#include <utility>

#include <ox/put.hpp>

#include "text.h"

using namespace ox;

namespace {

constexpr auto no_selection = std::numeric_limits<std::size_t>::max();

}  // namespace

MenuApp::MenuApp(std::vector<MenuItem> menu) : menu_{std::move(menu)} {}

auto MenuApp::take_command() -> std::optional<MenuCommand>
{
    return std::exchange(command_, std::nullopt);
}

EventResponse MenuApp::handle_key_press(Key k)
{
    switch (k) {
        case Key::ArrowDown:
        case Key::j: select_next(1); return {};
        case Key::ArrowUp:
        case Key::k: select_next(-1); return {};
        case Key::PageDown: select_next(page_rows_); return {};
        case Key::PageUp: select_next(-page_rows_); return {};
        case Key::Home: select_at(0); return {};
        case Key::End: select_at(no_selection); return {};
        case Key::ArrowLeft:
        case Key::h:
        case Key::Backspace:
        case Key::Backspace1:
        case Key::Backspace2: go_back(); return {};
        case Key::ArrowRight:
        case Key::l: enter_selected(false); return {};
        case Key::Enter:
            if (enter_selected(true)) { return QuitRequest{0}; }
            return {};
        case Key::Escape:
            if (!go_back()) { return QuitRequest{0}; }
            return {};
        case Key::q: return QuitRequest{0};
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

    if (c.size.width < 24 || c.size.height < 7) {
        put(c, {0, 0}, "Terminal too small");
        return std::nullopt;
    }

    draw_menu(c);
    return std::nullopt;
}

auto MenuApp::current_items() const -> std::vector<MenuItem> const&
{
    auto const* items = &menu_;
    for (auto index : path_) {
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
    auto const size = static_cast<int>(current_items().size());
    if (size == 0) {
        current_selection() = 0;
        return;
    }

    auto index = static_cast<int>(current_selection());
    if (delta == 1 || delta == -1) {
        // Single steps wrap around, paging stops at the ends.
        index = (index + delta + size) % size;
    }
    else {
        index = std::clamp(index + delta, 0, size - 1);
    }
    current_selection() = static_cast<std::size_t>(index);
}

void MenuApp::select_at(std::size_t index)
{
    auto const size = current_items().size();
    current_selection() = size == 0 ? 0 : std::min(index, size - 1);
}

auto MenuApp::enter_selected(bool run_leaf) -> bool
{
    auto const& items = current_items();
    if (items.empty()) { return false; }

    auto const& item = items[current_selection()];
    if (item.children.empty()) {
        if (!run_leaf || item.print.empty()) { return false; }
        command_ = MenuCommand{selected_print_path(), item.interactive};
        return true;
    }

    path_.push_back(current_selection());
    selections_.push_back(0);
    return false;
}

auto MenuApp::go_back() -> bool
{
    if (path_.empty()) { return false; }
    path_.pop_back();
    selections_.pop_back();
    return true;
}

auto MenuApp::breadcrumb() const -> std::string
{
    auto text = std::string{"Menu"};
    auto const* items = &menu_;
    for (auto index : path_) {
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
    auto const append = [&out](std::string const& part) {
        if (part.empty()) { return; }
        if (!out.empty()) { out += ' '; }
        out += part;
    };

    auto const* walk = &menu_;
    for (auto index : path_) {
        append((*walk)[index].print);
        walk = &(*walk)[index].children;
    }
    append(items[current_selection()].print);
    return out;
}

void MenuApp::draw_column(Canvas c,
                          std::vector<MenuItem> const& items,
                          std::size_t selection,
                          int x,
                          int y,
                          int width,
                          int rows,
                          bool active)
{
    if (width < 2 || rows < 1) { return; }

    auto const size = items.size();
    auto const visible = static_cast<std::size_t>(rows);

    // Scroll so the selection is always on screen.
    auto const offset =
        (selection != no_selection && selection >= visible) ? selection - visible + 1 : 0;

    for (auto r = std::size_t{0}; r < visible && offset + r < size; ++r) {
        auto const i = offset + r;
        auto const& item = items[i];
        auto const selected = (i == selection);

        auto label = std::string{selected ? "> " : "  "} + item.display;
        if (!item.children.empty()) { label += '/'; }
        // Last column is reserved for the scroll indicators.
        label = fit(std::move(label), width - 1);

        auto const row = y + static_cast<int>(r);
        if (selected) {
            put(c, {x, row}, label | (active ? Trait::Standout : Trait::Bold));
        }
        else if (active) {
            put(c, {x, row}, label);
        }
        else {
            put(c, {x, row}, label | Trait::Dim);
        }
    }

    if (offset > 0) { put(c, {x + width - 1, y}, "^"); }
    if (offset + visible < size) { put(c, {x + width - 1, y + rows - 1}, "v"); }
}

void MenuApp::draw_menu(Canvas c)
{
    auto const width = c.size.width;
    auto const height = c.size.height;

    auto const title = std::string_view{"Blackhat TUI Menu"};
    auto const title_x = std::max(0, (width - static_cast<int>(title.size())) / 2);
    put(c, {title_x, 0}, title | Trait::Bold);

    // Keep the tail of the breadcrumb, it is the part that tells you where you are.
    auto crumb = breadcrumb();
    auto const crumb_max = static_cast<std::size_t>(width - 2);
    if (crumb.size() > crumb_max) {
        crumb = "..." + crumb.substr(crumb.size() - (crumb_max - 3));
    }
    put(c, {1, 1}, crumb | Trait::Dim);

    auto const start_y = 3;
    auto const rows = height - start_y - 2;  // Blank line and hint line at the bottom.
    page_rows_ = std::max(1, rows);

    auto const margin = 1;
    auto const gap = 2;
    auto const column_width = (width - margin * 2 - gap) / 2;
    auto const preview_x = margin + column_width + gap;

    auto const& items = current_items();
    auto const selection = current_selection();
    draw_column(c, items, selection, margin, start_y, column_width, rows, true);

    if (!items.empty()) {
        auto const& hovered = items[selection];
        if (!hovered.children.empty()) {
            draw_column(c, hovered.children, no_selection, preview_x, start_y,
                        column_width, rows, false);
        }
        else if (!hovered.print.empty()) {
            put(c, {preview_x, start_y},
                fit("$ " + selected_print_path(), column_width) | Trait::Dim);
        }
    }

    auto const hint = std::string_view{"Enter:run  Left:back  q:quit"};
    put(c, {1, height - 1}, hint | Trait::Dim);
}
