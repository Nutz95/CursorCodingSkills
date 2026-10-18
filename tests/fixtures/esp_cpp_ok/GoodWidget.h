#pragma once

/// Hosts a tiny pure helper for guardrail self-tests.
class GoodWidget {
 public:
  /// Returns a deterministic sample value.
  int sample() const;

 private:
  int value_ = 1;
};
