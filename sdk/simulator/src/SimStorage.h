#pragma once

#include <string>

namespace sim {

class SimStorage {
 public:
  explicit SimStorage(const std::string& appDir);

  bool readFile(const std::string& relPath, std::string& outContent);
  bool writeFile(const std::string& relPath, const std::string& data);
  bool exists(const std::string& relPath);
  bool remove(const std::string& relPath);

  std::string resolvePath(const std::string& relPath) const;

 private:
  std::string appDir_;
  std::string storageDir_;
};

}  // namespace sim
