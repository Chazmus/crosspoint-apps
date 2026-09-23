#include "SimStorage.h"

#include <sys/stat.h>
#include <unistd.h>

#include <cstdio>
#include <fstream>
#include <iostream>

namespace sim {

SimStorage::SimStorage(const std::string& appDir) : appDir_(appDir) {
  storageDir_ = appDir_ + "/.storage";
  mkdir(storageDir_.c_str(), 0755);
}

std::string SimStorage::resolvePath(const std::string& relPath) const {
  if (relPath.empty()) return storageDir_;
  if (relPath[0] == '/') return relPath;  // absolute path
  return storageDir_ + "/" + relPath;
}

bool SimStorage::readFile(const std::string& relPath, std::string& outContent) {
  // First check if the file exists in the app source directory itself (e.g. daily.json)
  std::string fullPath = appDir_ + "/" + relPath;
  std::ifstream file(fullPath, std::ios::binary);
  if (!file) {
    // If not in app root, check in .storage/
    fullPath = resolvePath(relPath);
    file.open(fullPath, std::ios::binary);
  }

  if (!file) return false;

  file.seekg(0, std::ios::end);
  const size_t sz = file.tellg();
  file.seekg(0, std::ios::beg);

  outContent.resize(sz);
  if (sz > 0) {
    file.read(&outContent[0], sz);
  }
  return true;
}

bool SimStorage::writeFile(const std::string& relPath, const std::string& data) {
  const std::string fullPath = resolvePath(relPath);
  std::ofstream file(fullPath, std::ios::binary | std::ios::trunc);
  if (!file) {
    std::cerr << "[SimStorage] Failed to open for write: " << fullPath << std::endl;
    return false;
  }
  file.write(data.data(), data.size());
  return file.good();
}

bool SimStorage::exists(const std::string& relPath) {
  const std::string fullPath = resolvePath(relPath);
  if (access(fullPath.c_str(), F_OK) == 0) return true;
  const std::string rootPath = appDir_ + "/" + relPath;
  return (access(rootPath.c_str(), F_OK) == 0);
}

bool SimStorage::remove(const std::string& relPath) {
  const std::string fullPath = resolvePath(relPath);
  return (::remove(fullPath.c_str()) == 0);
}

}  // namespace sim
