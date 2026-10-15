#include "audio_feedback.h"
#include <flutter/standard_method_codec.h>

AudioFeedback::AudioFeedback(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "anxin/audio", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "stop") { output_.Stop(); result->Success(); return; }
    if (call.method_name() != "play") { result->NotImplemented(); return; }
    const auto* args = call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
    if (!args) { result->Error("arguments", "Expected audio options"); return; }
    const auto get = [&](const char* name) -> const flutter::EncodableValue* {
      const auto found = args->find(flutter::EncodableValue(name));
      return found == args->end() ? nullptr : &found->second;
    };
    const auto* cue_value = get("cue"); const auto* text_value = get("text");
    const auto* sound_value = get("sound"); const auto* speech_value = get("speech");
    const auto* cue = cue_value ? std::get_if<std::string>(cue_value) : nullptr;
    const auto* text = text_value ? std::get_if<std::string>(text_value) : nullptr;
    const auto* sound = sound_value ? std::get_if<bool>(sound_value) : nullptr;
    const auto* speech = speech_value ? std::get_if<bool>(speech_value) : nullptr;
    if (!cue || !text || !sound || !speech || text->size() > 4096 ||
        (*cue != "move" && *cue != "capture" && *cue != "check")) {
      result->Error("arguments", "Invalid audio options"); return;
    }
    const bool ok = output_.Play(*cue, *text, *sound, *speech);
    result->Success(flutter::EncodableValue(ok));
  });
}

AudioFeedback::~AudioFeedback() { channel_->SetMethodCallHandler(nullptr); }
