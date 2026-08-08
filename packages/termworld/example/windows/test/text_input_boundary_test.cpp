#include <cassert>
#include <string>
#include <utility>
#include <vector>

int main() {
  const std::vector<std::pair<std::wstring, bool>> updates = {
      {L"ㅎ", true}, {L"한글", true}, {L"韓國", true}, {L"韓國", false}};
  std::vector<std::wstring> commits;
  for (const auto& update : updates) {
    if (!update.second) commits.push_back(update.first);
  }
  assert(commits.size() == 1);
  assert(commits.front() == L"韓國");
  assert(std::wstring(L"👩🏽‍💻").size() >= 4);
  return 0;
}
