#pragma once

#ifdef UNIT_TEST
using Mutex = int;
#else
#include <mutex>
using Mutex = std::mutex;
#endif

class GatedService {
 public:
  void run();
};
