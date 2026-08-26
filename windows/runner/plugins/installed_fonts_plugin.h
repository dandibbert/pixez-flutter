#pragma once

#include <string>

#include <flutter/binary_messenger.h>
#include <flutter/standard_method_codec.h>

class InstalledFonts
{
private:
  static std::string name;

public:
  static void Initialize(flutter::BinaryMessenger *messenger, const flutter::StandardMethodCodec *codec);
};
