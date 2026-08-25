#include "installed_fonts_plugin.h"

#include "../utils.h"

#include <Windows.h>
#include <set>
#include <string>
#include <vector>

#include <flutter/method_channel.h>

using namespace std;
using namespace flutter;

string InstalledFonts::name = "com.perol.dev/fonts";

int CALLBACK EnumFontFamExProc(const LOGFONTW *lpelfe, const TEXTMETRICW *,
                               DWORD, LPARAM lParam)
{
  auto *names = reinterpret_cast<set<wstring> *>(lParam);
  wstring face(lpelfe->lfFaceName);
  if (!face.empty() && face[0] != L'@')
  {
    names->insert(face);
  }
  return 1;
}

void InstalledFonts::Initialize(BinaryMessenger *messenger,
                                const StandardMethodCodec *codec)
{
  MethodChannel<EncodableValue> channel(messenger, name, codec);

  channel.SetMethodCallHandler(
      [](const MethodCall<EncodableValue> &call,
         unique_ptr<MethodResult<EncodableValue>> result)
      {
        if (call.method_name().compare("listFamilies") == 0)
        {
          set<wstring> names;
          HDC hdc = GetDC(nullptr);
          LOGFONTW logfont = {};
          logfont.lfCharSet = DEFAULT_CHARSET;
          EnumFontFamiliesExW(hdc, &logfont, EnumFontFamExProc,
                              reinterpret_cast<LPARAM>(&names), 0);
          ReleaseDC(nullptr, hdc);

          EncodableList families;
          for (const auto &name : names)
          {
            families.push_back(EncodableValue(Utf8FromUtf16(name.c_str())));
          }
          result->Success(families);
        }
        else
        {
          result->NotImplemented();
        }
      });
}
