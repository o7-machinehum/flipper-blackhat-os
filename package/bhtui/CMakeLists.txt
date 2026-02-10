cmake_minimum_required(VERSION 3.20)

project(bhtui LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_subdirectory(third-party/TermOx)

add_executable(bhtui
    src/main.cpp
    src/menu_app.cpp
    src/menu_builder.cpp
    src/menu_item.cpp
)

target_link_libraries(bhtui
    PRIVATE
        TermOx
)

if (MSVC)
    target_compile_options(bhtui PRIVATE /W4)
else()
    target_compile_options(bhtui PRIVATE -Wall -Wextra -Wpedantic)
endif()
