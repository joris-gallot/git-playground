#include <iostream>
#include <string>
#include <vector>

class Greeter {
public:
  explicit Greeter(std::string name) : name_(std::move(name)) {}

  void greet() const {
    std::cout << "Hello, " << name_ << std::endl;
  }

private:
  std::string name_;
};

int main() {
  Greeter greeter{"Reviu"};
  greeter.greet();
  std::vector<int> values{1, 2, 3};
  return static_cast<int>(values.size());
}
