#ifndef RUNNER_AUDIO_FEEDBACK_H_
#define RUNNER_AUDIO_FEEDBACK_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>
#include "audio_output.h"

class AudioFeedback {
 public:
  explicit AudioFeedback(flutter::BinaryMessenger* messenger);
  ~AudioFeedback();

 private:
  LocalAudioOutput output_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif
