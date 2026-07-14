#include "audio_converter.h"

#include <gst/gst.h>

#include <cstdio>
#include <cstring>
#include <stdexcept>
#include <string>
#include <thread>

namespace {

constexpr char kChannelName[] = "com.matthiasn.lotti/audio_converter";
constexpr char kConvertMethod[] = "convertM4aToWav";

bool HasAacDecoder() {
  constexpr const char* kAacDecoderNames[] = {
      "avdec_aac",
      "avdec_aac_fixed",
      "faad",
      "fdkaacdec",
  };
  for (const char* name : kAacDecoderNames) {
    GstElementFactory* factory = gst_element_factory_find(name);
    if (factory != nullptr) {
      gst_object_unref(factory);
      return true;
    }
  }
  return false;
}

void LinkDecodedAudioPad(GstElement* /* source */, GstPad* pad,
                         gpointer user_data) {
  GstElement* converter = GST_ELEMENT(user_data);
  GstCaps* caps = gst_pad_get_current_caps(pad);
  if (caps == nullptr) {
    caps = gst_pad_query_caps(pad, nullptr);
  }
  if (caps == nullptr || gst_caps_is_empty(caps)) {
    if (caps != nullptr) {
      gst_caps_unref(caps);
    }
    return;
  }

  const GstStructure* structure = gst_caps_get_structure(caps, 0);
  const char* media_type = gst_structure_get_name(structure);
  if (g_str_has_prefix(media_type, "audio/")) {
    GstPad* sink_pad = gst_element_get_static_pad(converter, "sink");
    if (!gst_pad_is_linked(sink_pad)) {
      gst_pad_link(pad, sink_pad);
    }
    gst_object_unref(sink_pad);
  }
  gst_caps_unref(caps);
}

std::string PipelineErrorMessage(GstMessage* message) {
  GError* error = nullptr;
  gchar* debug = nullptr;
  gst_message_parse_error(message, &error, &debug);
  const std::string result =
      error != nullptr ? error->message : "Unknown GStreamer decoding error";
  if (error != nullptr) {
    g_error_free(error);
  }
  g_free(debug);
  return result;
}

void ConvertM4aToWav(const std::string& input_path,
                     const std::string& output_path) {
  if (!HasAacDecoder()) {
    throw std::runtime_error(
        "No GStreamer AAC decoder is installed. On Ubuntu/Debian, install "
        "gstreamer1.0-libav and restart Lotti.");
  }

  GstElement* pipeline = gst_pipeline_new("lotti-m4a-to-wav");
  GstElement* decoder = gst_element_factory_make("uridecodebin", "decoder");
  GstElement* converter =
      gst_element_factory_make("audioconvert", "converter");
  GstElement* resampler =
      gst_element_factory_make("audioresample", "resampler");
  GstElement* caps_filter =
      gst_element_factory_make("capsfilter", "pcm-format");
  GstElement* wav_encoder = gst_element_factory_make("wavenc", "wav-encoder");
  GstElement* file_sink = gst_element_factory_make("filesink", "file-sink");

  if (pipeline == nullptr || decoder == nullptr || converter == nullptr ||
      resampler == nullptr || caps_filter == nullptr || wav_encoder == nullptr ||
      file_sink == nullptr) {
    GstElement* elements[] = {decoder,      converter,   resampler,
                              caps_filter, wav_encoder, file_sink};
    for (GstElement* element : elements) {
      if (element != nullptr) {
        gst_object_unref(element);
      }
    }
    gst_clear_object(&pipeline);
    throw std::runtime_error(
        "Required GStreamer audio conversion elements are unavailable.");
  }

  gst_bin_add_many(GST_BIN(pipeline), decoder, converter, resampler,
                   caps_filter, wav_encoder, file_sink, nullptr);

  GError* uri_error = nullptr;
  gchar* input_uri =
      g_filename_to_uri(input_path.c_str(), nullptr, &uri_error);
  if (input_uri == nullptr) {
    const std::string message = uri_error != nullptr
                                    ? uri_error->message
                                    : "Unable to create the input file URI";
    if (uri_error != nullptr) {
      g_error_free(uri_error);
    }
    gst_object_unref(pipeline);
    throw std::runtime_error(message);
  }

  GstCaps* pcm_caps = gst_caps_new_simple(
      "audio/x-raw", "format", G_TYPE_STRING, "S16LE", "layout",
      G_TYPE_STRING, "interleaved", nullptr);
  g_object_set(decoder, "uri", input_uri, nullptr);
  g_object_set(caps_filter, "caps", pcm_caps, nullptr);
  g_object_set(file_sink, "location", output_path.c_str(), nullptr);
  g_free(input_uri);
  gst_caps_unref(pcm_caps);

  if (!gst_element_link_many(converter, resampler, caps_filter, wav_encoder,
                             file_sink, nullptr)) {
    gst_object_unref(pipeline);
    throw std::runtime_error("Failed to link the GStreamer WAV pipeline.");
  }
  g_signal_connect(decoder, "pad-added", G_CALLBACK(LinkDecodedAudioPad),
                   converter);

  GstStateChangeReturn state =
      gst_element_set_state(pipeline, GST_STATE_PLAYING);
  if (state == GST_STATE_CHANGE_FAILURE) {
    gst_element_set_state(pipeline, GST_STATE_NULL);
    gst_object_unref(pipeline);
    throw std::runtime_error("Failed to start the GStreamer WAV pipeline.");
  }

  GstBus* bus = gst_element_get_bus(pipeline);
  GstMessage* message = gst_bus_timed_pop_filtered(
      bus, 15 * 60 * GST_SECOND,
      static_cast<GstMessageType>(GST_MESSAGE_ERROR | GST_MESSAGE_EOS));

  std::string failure;
  if (message == nullptr) {
    failure = "GStreamer audio conversion timed out.";
  } else if (GST_MESSAGE_TYPE(message) == GST_MESSAGE_ERROR) {
    failure = PipelineErrorMessage(message);
  }

  if (message != nullptr) {
    gst_message_unref(message);
  }
  gst_object_unref(bus);
  gst_element_set_state(pipeline, GST_STATE_NULL);
  gst_object_unref(pipeline);

  if (!failure.empty()) {
    std::remove(output_path.c_str());
    throw std::runtime_error("M4A-to-WAV conversion failed: " + failure);
  }
}

void RespondWithError(FlMethodCall* method_call, const char* code,
                      const char* message) {
  g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
      fl_method_error_response_new(code, message, nullptr));
  fl_method_call_respond(method_call, response, nullptr);
}

void HandleMethodCall(FlMethodCall* method_call) {
  const gchar* method = fl_method_call_get_name(method_call);
  if (std::strcmp(method, kConvertMethod) != 0) {
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  FlValue* arguments = fl_method_call_get_args(method_call);
  if (fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP) {
    RespondWithError(method_call, "INVALID_ARGUMENTS",
                     "Arguments map is required.");
    return;
  }
  FlValue* input = fl_value_lookup_string(arguments, "inputPath");
  FlValue* output = fl_value_lookup_string(arguments, "outputPath");
  if (input == nullptr || output == nullptr ||
      fl_value_get_type(input) != FL_VALUE_TYPE_STRING ||
      fl_value_get_type(output) != FL_VALUE_TYPE_STRING) {
    RespondWithError(method_call, "INVALID_ARGUMENTS",
                     "inputPath and outputPath are required.");
    return;
  }

  const std::string input_path = fl_value_get_string(input);
  const std::string output_path = fl_value_get_string(output);
  g_object_ref(method_call);
  std::thread([method_call, input_path, output_path]() {
    try {
      ConvertM4aToWav(input_path, output_path);
      g_autoptr(FlValue) result = fl_value_new_bool(true);
      g_autoptr(FlMethodResponse) response =
          FL_METHOD_RESPONSE(fl_method_success_response_new(result));
      fl_method_call_respond(method_call, response, nullptr);
    } catch (const std::exception& error) {
      RespondWithError(method_call, "CONVERSION_ERROR", error.what());
    }
    g_object_unref(method_call);
  }).detach();
}

void MethodCallCallback(FlMethodChannel* /* channel */,
                        FlMethodCall* method_call, gpointer /* user_data */) {
  HandleMethodCall(method_call);
}

}  // namespace

void audio_converter_register_with_registrar(FlPluginRegistrar* registrar) {
  gst_init(nullptr, nullptr);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), kChannelName,
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, MethodCallCallback,
                                            nullptr, nullptr);
}
