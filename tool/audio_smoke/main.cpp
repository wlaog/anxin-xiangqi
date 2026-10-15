#include "../../windows/runner/audio_output.h"
#include <windows.h>
#include <iostream>

// Exercises the production output, independently of Flutter's channel mocks.
// API acceptance cannot establish that the user heard the sound.
int main() {
  const HRESULT com = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(com)) return 2;
  bool all_tones = true;
  {
    LocalAudioOutput audio;
    for (const auto* cue : {"move", "capture", "check"}) {
      const bool ok = audio.Play(cue, "", true, false);
      std::cout << cue << "=" << ok << std::endl;
      all_tones = all_tones && ok;
      Sleep(250);
    }
    const bool speech = audio.Play("move", "\xe7\xba\xa2\xe6\x96\xb9\xe8\xb5\xb0\xe6\xa3\x8b", false, true);
    std::cout << "mandarin_speech=" << speech << std::endl;
    Sleep(750);
    audio.Stop();
    const bool rejected = !audio.Play("unknown", "", true, false);
    std::cout << "invalid_rejected=" << rejected << std::endl;
    all_tones = all_tones && rejected;
  }
  CoUninitialize();
  return all_tones ? 0 : 1;
}
