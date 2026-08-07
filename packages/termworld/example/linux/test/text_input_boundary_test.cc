#include <cassert>
#include <string>
#include <vector>

int main() {
  const std::vector<std::pair<std::string, bool>> updates = {
      {u8"ㅎ", true}, {u8"한글", true}, {u8"韓國", true}, {u8"韓國", false}};
  std::vector<std::string> commits;
  for (const auto& update : updates) {
    if (!update.second) commits.push_back(update.first);
  }
  assert(commits.size() == 1);
  assert(commits.front() == u8"韓國");
  assert(std::string(u8"👩🏽‍💻").size() == 15);
  return 0;
}
