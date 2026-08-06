#include "dropwell_testing.h"

#ifdef NDEBUG

void dropwell_register_testing_channel(FlPluginRegistrar* /*registrar*/,
                                       DropwellPlugin* /*plugin*/) {}

#else

#include <glib.h>
#include <gtk/gtk.h>

#include <cstring>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>

#include "dropwell_data.h"
#include "dropwell_internal.h"

namespace {

FlValue* Lookup(FlValue* map, const char* key) {
  if (map == nullptr || fl_value_get_type(map) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  return fl_value_lookup_string(map, key);
}

std::string StringAt(FlValue* map, const char* key) {
  FlValue* value = Lookup(map, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
    return {};
  }
  return fl_value_get_string(value);
}

double DoubleAt(FlValue* map, const char* key) {
  FlValue* value = Lookup(map, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_FLOAT) {
    return 0;
  }
  return fl_value_get_float(value);
}

bool BoolAt(FlValue* map, const char* key) {
  FlValue* value = Lookup(map, key);
  return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_BOOL &&
         fl_value_get_bool(value);
}

std::vector<uint8_t> BytesAt(FlValue* map, const char* key) {
  FlValue* value = Lookup(map, key);
  if (value == nullptr ||
      fl_value_get_type(value) != FL_VALUE_TYPE_UINT8_LIST) {
    return {};
  }
  const uint8_t* data = fl_value_get_uint8_list(value);
  return std::vector<uint8_t>(data, data + fl_value_get_length(value));
}

/// Writes a payload into the temporary directory under its own name.
///
/// The clipboard and a drag payload both hand over *files*, so a suite that
/// only ever passed bytes would never exercise the path real users take.
std::string MaterializeFile(const std::string& file_name,
                            const std::vector<uint8_t>& bytes) {
  g_autofree gchar* directory =
      g_build_filename(g_get_tmp_dir(), "dropwell", nullptr);
  g_mkdir_with_parents(directory, 0700);
  g_autofree gchar* path =
      g_build_filename(directory, file_name.c_str(), nullptr);
  std::ofstream out(path, std::ios::binary | std::ios::trunc);
  if (!out) return {};
  if (!bytes.empty()) {
    out.write(reinterpret_cast<const char*>(bytes.data()),
              static_cast<std::streamsize>(bytes.size()));
  }
  return std::string(path);
}

std::vector<std::string> MaterializeAll(FlValue* files) {
  std::vector<std::string> paths;
  if (files == nullptr || fl_value_get_type(files) != FL_VALUE_TYPE_LIST) {
    return paths;
  }
  for (size_t index = 0; index < fl_value_get_length(files); index++) {
    FlValue* entry = fl_value_get_list_value(files, index);
    const std::string existing = StringAt(entry, "path");
    if (!existing.empty()) {
      paths.push_back(existing);
      continue;
    }
    const std::string file_name = StringAt(entry, "fileName");
    if (file_name.empty()) continue;
    std::string path = MaterializeFile(file_name, BytesAt(entry, "bytes"));
    if (!path.empty()) paths.push_back(std::move(path));
  }
  return paths;
}

/// GTK has no one-shot setter for a URI list, so the suite owns the selection
/// with a data callback instead.
struct ClipboardUris {
  std::vector<std::string> uris;
};

void ClipboardGet(GtkClipboard* /*clipboard*/, GtkSelectionData* selection,
                  guint /*info*/, gpointer user_data) {
  auto* state = static_cast<ClipboardUris*>(user_data);
  std::vector<const gchar*> pointers;
  pointers.reserve(state->uris.size() + 1);
  for (const std::string& uri : state->uris) pointers.push_back(uri.c_str());
  pointers.push_back(nullptr);
  gtk_selection_data_set_uris(selection,
                              const_cast<gchar**>(pointers.data()));
}

void ClipboardClear(GtkClipboard* /*clipboard*/, gpointer user_data) {
  delete static_cast<ClipboardUris*>(user_data);
}

void OfferUris(const std::vector<std::string>& paths) {
  auto* state = new ClipboardUris();
  for (const std::string& path : paths) {
    g_autofree gchar* uri = g_filename_to_uri(path.c_str(), nullptr, nullptr);
    if (uri != nullptr) state->uris.emplace_back(uri);
  }
  GtkTargetList* targets = gtk_target_list_new(nullptr, 0);
  gtk_target_list_add_uri_targets(targets, 0);
  gint count = 0;
  GtkTargetEntry* entries = gtk_target_table_new_from_list(targets, &count);
  gtk_clipboard_set_with_data(gtk_clipboard_get(GDK_SELECTION_CLIPBOARD),
                              entries, count, ClipboardGet, ClipboardClear,
                              state);
  gtk_target_table_free(entries, count);
  gtk_target_list_unref(targets);
}

void OfferBitmap(const std::vector<uint8_t>& bytes) {
  g_autoptr(GdkPixbufLoader) loader = gdk_pixbuf_loader_new();
  gdk_pixbuf_loader_write(loader, bytes.data(), bytes.size(), nullptr);
  gdk_pixbuf_loader_close(loader, nullptr);
  GdkPixbuf* pixbuf = gdk_pixbuf_loader_get_pixbuf(loader);
  if (pixbuf == nullptr) return;
  gtk_clipboard_set_image(gtk_clipboard_get(GDK_SELECTION_CLIPBOARD), pixbuf);
}

FlMethodResponse* HandleCall(DropwellPlugin* plugin, FlMethodCall* call) {
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);

  if (strcmp(method, "clearSystemClipboard") == 0) {
    GtkClipboard* clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
    gtk_clipboard_clear(clipboard);
    gtk_clipboard_set_text(clipboard, "", 0);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }

  if (strcmp(method, "setSystemClipboard") == 0) {
    FlValue* files = Lookup(args, "files");
    if (BoolAt(args, "asBitmap")) {
      if (files == nullptr || fl_value_get_length(files) == 0) {
        return FL_METHOD_RESPONSE(fl_method_error_response_new(
            "bad-arguments", "a bitmap needs bytes", nullptr));
      }
      OfferBitmap(BytesAt(fl_value_get_list_value(files, 0), "bytes"));
    } else {
      OfferUris(MaterializeAll(files));
    }
    return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }

  if (strcmp(method, "synthesizeDrag") == 0) {
    const std::string phase = StringAt(args, "phase");
    const double x = DoubleAt(args, "x");
    const double y = DoubleAt(args, "y");
    if (phase == "perform") {
      dropwell_plugin_deliver_uri_list(
          plugin, x, y,
          dropwell::BuildUriList(MaterializeAll(Lookup(args, "files"))));
    } else if (phase == "enter" || phase == "over") {
      dropwell_plugin_report_drag(plugin, phase.c_str(), x, y);
    } else if (phase == "leave") {
      dropwell_plugin_report_drag(plugin, "leave", 0, 0);
    } else {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
          "bad-arguments", "unknown drag phase", nullptr));
    }
    return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }

  if (strcmp(method, "readFile") == 0) {
    if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_STRING) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
          "bad-arguments", "readFile needs a path", nullptr));
    }
    std::ifstream in(fl_value_get_string(args), std::ios::binary);
    if (!in) {
      return FL_METHOD_RESPONSE(
          fl_method_error_response_new("io", "could not open", nullptr));
    }
    const std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(in)),
                                     std::istreambuf_iterator<char>());
    g_autoptr(FlValue) value =
        fl_value_new_uint8_list(bytes.data(), bytes.size());
    return FL_METHOD_RESPONSE(fl_method_success_response_new(value));
  }

  return FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
}

void TestingCallback(FlMethodChannel* /*channel*/, FlMethodCall* call,
                     gpointer user_data) {
  g_autoptr(FlMethodResponse) response =
      HandleCall(static_cast<DropwellPlugin*>(user_data), call);
  fl_method_call_respond(call, response, nullptr);
}

}  // namespace

void dropwell_register_testing_channel(FlPluginRegistrar* registrar,
                                       DropwellPlugin* plugin) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "dropwell/testing",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, TestingCallback, g_object_ref(plugin), g_object_unref);
}

#endif  // NDEBUG
