#include "output_view.h"

#include <algorithm>
#include <cstddef>
#include <string_view>
#include <utility>

#include <ox/put.hpp>

#include "text.h"

using namespace ox;

namespace {

/// Decodes the UTF-8 sequence at \p i and moves past it. Invalid bytes become '?'.
auto decode_utf8(std::string_view s, std::size_t& i) -> char32_t
{
    auto const lead = static_cast<unsigned char>(s[i]);
    auto const length = lead < 0x80           ? 1
                        : (lead >> 5) == 0x06 ? 2
                        : (lead >> 4) == 0x0E ? 3
                        : (lead >> 3) == 0x1E ? 4
                                              : 0;
    if (length == 0 || i + length > s.size()) {
        ++i;
        return U'?';
    }

    auto code = static_cast<char32_t>(length == 1 ? lead : lead & (0x7F >> length));
    for (auto k = std::size_t{1}; k < static_cast<std::size_t>(length); ++k) {
        auto const next = static_cast<unsigned char>(s[i + k]);
        if ((next & 0xC0) != 0x80) {
            ++i;
            return U'?';
        }
        code = (code << 6) | (next & 0x3F);
    }
    i += static_cast<std::size_t>(length);
    return code;
}

/// Returns the index just past the escape sequence that starts at \p i.
auto skip_escape(std::string_view s, std::size_t i) -> std::size_t
{
    ++i;
    if (i >= s.size()) { return i; }
    if (s[i] == '[') {  // CSI, ends with a byte from '@' to '~'.
        ++i;
        while (i < s.size() && (s[i] < '@' || s[i] > '~')) { ++i; }
        return std::min(i + 1, s.size());
    }
    if (s[i] == ']') {  // OSC, ends with BEL or ESC '\'.
        while (++i < s.size()) {
            if (s[i] == '\a') { return i + 1; }
            if (s[i] == '\x1b') { return std::min(i + 2, s.size()); }
        }
        return i;
    }
    return i + 1;
}

/// Converts a line of output to what a terminal would show: the text after the last
/// carriage return, without escape sequences and with tabs expanded.
auto clean_line(std::string_view line) -> std::u32string
{
    while (!line.empty() && line.back() == '\r') { line.remove_suffix(1); }
    if (auto const cr = line.rfind('\r'); cr != std::string_view::npos) {
        line.remove_prefix(cr + 1);
    }

    auto out = std::u32string{};
    for (auto i = std::size_t{0}; i < line.size();) {
        auto const c = static_cast<unsigned char>(line[i]);
        if (c == 0x1b) { i = skip_escape(line, i); }
        else if (c == '\t') {
            out.append(8 - out.size() % 8, U' ');
            ++i;
        }
        else if (c < 0x20 || c == 0x7f) { ++i; }
        else { out += decode_utf8(line, i); }
    }
    return out;
}

}  // namespace

OutputView::OutputView(std::string command, std::string const& output, int status)
    : command_{std::move(command)}, status_{status}
{
    auto rest = std::string_view{output};
    while (!rest.empty()) {
        auto const end = rest.find('\n');
        lines_.push_back(clean_line(rest.substr(0, end)));
        if (end == std::string_view::npos) { break; }
        rest.remove_prefix(end + 1);
    }
}

EventResponse OutputView::handle_key_press(Key k)
{
    switch (k) {
        case Key::ArrowDown:
        case Key::j: scroll_by(1); return {};
        case Key::ArrowUp:
        case Key::k: scroll_by(-1); return {};
        case Key::PageDown:
        case Key::Space: scroll_by(page_rows_); return {};
        case Key::PageUp: scroll_by(-page_rows_); return {};
        case Key::Home: top_ = 0; return {};
        case Key::End: top_ = max_top_; return {};
        case Key::Enter:
        case Key::Escape:
        case Key::ArrowLeft:
        case Key::h:
        case Key::q:
        case Key::Backspace:
        case Key::Backspace1:
        case Key::Backspace2: return QuitRequest{0};
        default: return {};
    }
}

EventResponse OutputView::handle_resize(Area)
{
    return {};
}

Terminal::Cursor OutputView::handle_paint(Canvas c)
{
    fill(c, U' ');

    auto const width = c.size.width;
    auto const height = c.size.height;
    if (width < 24 || height < 7) {
        put(c, {0, 0}, "Terminal too small");
        return std::nullopt;
    }

    if (width != wrap_width_) { wrap(width); }
    auto const row_count = static_cast<int>(rows_.size());
    page_rows_ = height - 2;  // Header and footer.
    max_top_ = std::max(0, row_count - page_rows_);
    top_ = std::clamp(top_, 0, max_top_);

    auto const status = " exit " + std::to_string(status_) + " ";
    auto const status_x = width - static_cast<int>(status.size());
    put(c, {0, 0}, fit("$ " + command_, status_x - 1) | Trait::Bold);
    put(c, {status_x, 0}, status | (status_ == 0 ? Trait::Dim : Trait::Standout));

    if (rows_.empty()) { put(c, {0, 1}, std::string_view{"(no output)"} | Trait::Dim); }
    for (auto r = 0; r < page_rows_ && top_ + r < row_count; ++r) {
        put(c, {0, 1 + r}, std::u32string_view{rows_[static_cast<std::size_t>(top_ + r)]});
    }

    put(c, {0, height - 1}, std::string_view{"Up/Down:scroll  Enter/Left:back"} | Trait::Dim);
    if (row_count > 0) {
        auto const last = std::min(top_ + page_rows_, row_count);
        auto const position = std::to_string(top_ + 1) + "-" + std::to_string(last) + "/" +
                              std::to_string(row_count);
        put(c, {width - static_cast<int>(position.size()), height - 1},
            position | Trait::Dim);
    }
    return std::nullopt;
}

void OutputView::scroll_by(int rows)
{
    top_ = std::clamp(std::min(top_, max_top_) + rows, 0, max_top_);
}

void OutputView::wrap(int width)
{
    wrap_width_ = width;
    rows_.clear();
    auto const w = static_cast<std::size_t>(width);
    for (auto const& line : lines_) {
        if (line.empty()) { rows_.emplace_back(); }
        for (auto at = std::size_t{0}; at < line.size(); at += w) {
            rows_.push_back(line.substr(at, w));
        }
    }
}
