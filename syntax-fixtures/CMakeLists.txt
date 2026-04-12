cmake_minimum_required(VERSION 3.28)
project(ReviuFixture LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_executable(reviu_fixture
  main.cpp
)

target_compile_definitions(reviu_fixture PRIVATE REVIU_FIXTURE=1)
