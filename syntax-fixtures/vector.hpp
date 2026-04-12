#pragma once

#include <string>
#include <vector>

namespace reviu {

class Buffer {
public:
  explicit Buffer(std::string name);

  const std::string& name() const;
  void push_line(std::string line);

private:
  std::string name_;
  std::vector<std::string> lines_;
};

} // namespace reviu
