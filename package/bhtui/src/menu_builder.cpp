#include "menu_builder.h"

#include <utility>

MenuBuilder::MenuBuilder() : current_{&root_} {}

MenuBuilder& MenuBuilder::menu(std::string display, std::string print)
{
    current_ = &root_;
    stack_.clear();
    root_.push_back(MenuItem{std::move(display), std::move(print), {}});
    stack_.push_back(&root_);
    current_ = &root_.back().children;
    return *this;
}

MenuBuilder& MenuBuilder::submenu(std::string display, std::string print)
{
    if (current_ == nullptr) { current_ = &root_; }
    current_->push_back(MenuItem{std::move(display), std::move(print), {}});
    stack_.push_back(current_);
    current_ = &current_->back().children;
    return *this;
}

MenuBuilder& MenuBuilder::item(std::string display, std::string print)
{
    if (current_ == nullptr) { current_ = &root_; }
    current_->push_back(MenuItem{std::move(display), std::move(print), {}});
    return *this;
}

MenuBuilder& MenuBuilder::end()
{
    if (stack_.empty()) {
        current_ = &root_;
        return *this;
    }
    current_ = stack_.back();
    stack_.pop_back();
    return *this;
}

auto MenuBuilder::build() -> std::vector<MenuItem>
{
    return std::move(root_);
}
