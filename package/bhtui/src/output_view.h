#pragma once

#include <limits>
#include <string>
#include <vector>

#include <ox/core/core.hpp>

/// Scrollable view of a command's output, opened on its last page.
class OutputView {
   public:
    OutputView(std::string command, std::string const& output, int status);

    ox::EventResponse handle_key_press(ox::Key k);
    ox::EventResponse handle_resize(ox::Area);
    ox::Terminal::Cursor handle_paint(ox::Canvas c);

   private:
    std::string command_;
    int status_;
    std::vector<std::u32string> lines_;

    // lines_ wrapped to the width of the last paint.
    std::vector<std::u32string> rows_;
    int wrap_width_ = 0;

    // First visible row, clamped on paint. Starts past the end to open on the last page.
    int top_ = std::numeric_limits<int>::max();
    int max_top_ = 0;
    int page_rows_ = 1;

   private:
    void scroll_by(int rows);
    void wrap(int width);
};
