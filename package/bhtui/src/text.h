#pragma once

#include <algorithm>
#include <cstddef>
#include <string>

/// Pads or truncates \p s to exactly \p width columns, marking truncation with '~'.
inline auto fit(std::string s, int width) -> std::string
{
    auto const w = static_cast<std::size_t>(std::max(0, width));
    if (s.size() > w) {
        s.resize(w);
        if (w > 0) { s.back() = '~'; }
    }
    else {
        s.resize(w, ' ');
    }
    return s;
}
