#ifndef FLUTTER_AUDIO_CONVERTER_H_
#define FLUTTER_AUDIO_CONVERTER_H_

#include <flutter_linux/flutter_linux.h>

// Registers Lotti's Linux audio conversion method channel.
void audio_converter_register_with_registrar(FlPluginRegistrar* registrar);

#endif  // FLUTTER_AUDIO_CONVERTER_H_
