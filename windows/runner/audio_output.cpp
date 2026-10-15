#include "audio_output.h"
#include <mmsystem.h>
#include <cmath>
#include <cstdint>
#include <vector>

namespace {
// Original short sine cues, with fades. Static storage outlives async playback.
std::vector<uint8_t> MakeTone(double frequency, int samples) {
  std::vector<uint8_t> wave(44 + samples * 2, 0);
  const auto put = [&](int offset, uint32_t value, int bytes) {
    for (int i = 0; i < bytes; ++i) wave[offset + i] = static_cast<uint8_t>(value >> (8 * i));
  };
  const auto tag = [&](int offset, const char* value) {
    for (int i = 0; i < 4; ++i) wave[offset + i] = value[i];
  };
  tag(0, "RIFF"); put(4, 36 + samples * 2, 4); tag(8, "WAVE");
  tag(12, "fmt "); put(16, 16, 4); put(20, 1, 2); put(22, 1, 2);
  put(24, 22050, 4); put(28, 44100, 4); put(32, 2, 2); put(34, 16, 2);
  tag(36, "data"); put(40, samples * 2, 4);
  for (int i = 0; i < samples; ++i) {
    const double envelope = std::sin(3.141592653589793 * i / samples);
    const int16_t sample = static_cast<int16_t>(7000 * envelope * std::sin(6.283185307179586 * frequency * i / 22050));
    put(44 + i * 2, static_cast<uint16_t>(sample), 2);
  }
  return wave;
}
bool Tone(const std::string& cue) {
  static const auto move = MakeTone(440, 2205);
  static const auto capture = MakeTone(660, 3307);
  static const auto check = MakeTone(880, 4410);
  const auto& wave = cue == "check" ? check : cue == "capture" ? capture : move;
  return PlaySoundW(reinterpret_cast<LPCWSTR>(wave.data()), nullptr,
                    SND_MEMORY | SND_ASYNC | SND_NODEFAULT) != FALSE;
}
}  // namespace

bool LocalAudioOutput::Speak(const std::string& text) {
  if (!voice_) {
    if (FAILED(CoCreateInstance(CLSID_SpVoice, nullptr, CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(voice_.GetAddressOf())))) return false;
    // Select an installed Mandarin SAPI voice. No voice downloads or services.
    Microsoft::WRL::ComPtr<ISpObjectTokenCategory> category;
    Microsoft::WRL::ComPtr<IEnumSpObjectTokens> tokens;
    Microsoft::WRL::ComPtr<ISpObjectToken> token;
    if (FAILED(CoCreateInstance(CLSID_SpObjectTokenCategory, nullptr, CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(category.GetAddressOf()))) ||
        FAILED(category->SetId(SPCAT_VOICES, FALSE)) ||
        FAILED(category->EnumTokens(L"Language=804", nullptr, tokens.GetAddressOf())) ||
        tokens->Next(1, token.GetAddressOf(), nullptr) != S_OK ||
        FAILED(voice_->SetVoice(token.Get()))) {
      voice_.Reset();
      return false;
    }
    voice_->SetRate(-1);
  }
  const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(),
                                        static_cast<int>(text.size()), nullptr, 0);
  if (length <= 0) return false;
  std::wstring wide(length, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(),
                      static_cast<int>(text.size()), wide.data(), length);
  return SUCCEEDED(voice_->Speak(wide.c_str(), SPF_ASYNC | SPF_PURGEBEFORESPEAK | SPF_IS_NOT_XML, nullptr));
}

void LocalAudioOutput::Stop() {
  PlaySoundW(nullptr, nullptr, 0);
  if (voice_) voice_->Speak(nullptr, SPF_ASYNC | SPF_PURGEBEFORESPEAK, nullptr);
}
bool LocalAudioOutput::Play(const std::string& cue, const std::string& text, bool sound, bool speech) {
  if (text.size() > 4096 || (cue != "move" && cue != "capture" && cue != "check")) return false;
  bool ok = true;
  if (sound) ok = Tone(cue);
  if (speech) ok = Speak(text) && ok;
  return ok;
}
LocalAudioOutput::~LocalAudioOutput() { Stop(); }
