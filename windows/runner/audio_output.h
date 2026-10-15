#ifndef RUNNER_AUDIO_OUTPUT_H_
#define RUNNER_AUDIO_OUTPUT_H_

#include <sapi.h>
#include <wrl/client.h>
#include <string>

// Owns the local SAPI voice. Must live on the caller's initialized COM thread.
class LocalAudioOutput {
 public:
  bool Play(const std::string& cue, const std::string& text, bool sound, bool speech);
  void Stop();
  ~LocalAudioOutput();
 private:
  bool Speak(const std::string& text);
  Microsoft::WRL::ComPtr<ISpVoice> voice_;
};

#endif
