#include "include/dropwell/dropwell_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <cstring>
#include <string>
#include <vector>

#include "dropwell_data.h"
#include "dropwell_internal.h"
#include "dropwell_testing.h"

#define DROPWELL_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), dropwell_plugin_get_type(), \
                              DropwellPlugin))

namespace {

/// The one drag target this package accepts.
///
/// GTK will happily hand over text or an image from a drag, but a drop here is
/// a file transfer; anything else belongs to the app's own text handling.
constexpr char kUriListTarget[] = "text/uri-list";

/// State that needs a constructor, which a GObject struct cannot give it.
struct State {
  std::vector<dropwell::Rect> regions;
  bool inside = false;
  double drop_x = 0;
  double drop_y = 0;
};

}  // namespace

struct _DropwellPlugin {
  GObject parent_instance;
  FlMethodChannel* channel;
  GtkWidget* view;
  State* state;
};

G_DEFINE_TYPE(DropwellPlugin, dropwell_plugin, g_object_get_type())

namespace {

FlValue* EncodeFile(const std::string& path) {
  const std::string file_name = dropwell::FileNameOf(path);
  const std::string mime = dropwell::MimeFromFileName(file_name);
  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "fileName",
                           fl_value_new_string(file_name.c_str()));
  fl_value_set_string_take(
      map, "mimeType",
      mime.empty() ? fl_value_new_null() : fl_value_new_string(mime.c_str()));
  fl_value_set_string_take(map, "path", fl_value_new_string(path.c_str()));
  return map;
}

/// Converts GTK's logical widget coordinates to the physical pixels Dart
/// publishes its regions in.
double ToPhysical(GtkWidget* widget, gint value) {
  return static_cast<double>(value) *
         static_cast<double>(gtk_widget_get_scale_factor(widget));
}

gboolean OnDragMotion(GtkWidget* widget, GdkDragContext* context, gint x,
                      gint y, guint time, gpointer user_data) {
  DropwellPlugin* self = DROPWELL_PLUGIN(user_data);
  const double physical_x = ToPhysical(widget, x);
  const double physical_y = ToPhysical(widget, y);
  const bool entering = !self->state->inside;
  self->state->inside = true;
  dropwell_plugin_report_drag(self, entering ? "enter" : "over", physical_x,
                              physical_y);
  gdk_drag_status(context,
                  dropwell_plugin_accepts(self, physical_x, physical_y)
                      ? GDK_ACTION_COPY
                      : static_cast<GdkDragAction>(0),
                  time);
  return TRUE;
}

void OnDragLeave(GtkWidget* /*widget*/, GdkDragContext* /*context*/,
                 guint /*time*/, gpointer user_data) {
  DropwellPlugin* self = DROPWELL_PLUGIN(user_data);
  if (!self->state->inside) return;
  self->state->inside = false;
  dropwell_plugin_report_drag(self, "leave", 0, 0);
}

gboolean OnDragDrop(GtkWidget* widget, GdkDragContext* context, gint x, gint y,
                    guint time, gpointer user_data) {
  DropwellPlugin* self = DROPWELL_PLUGIN(user_data);
  self->state->inside = false;
  self->state->drop_x = ToPhysical(widget, x);
  self->state->drop_y = ToPhysical(widget, y);
  GdkAtom target = gtk_drag_dest_find_target(widget, context, nullptr);
  if (target == GDK_NONE) return FALSE;
  gtk_drag_get_data(widget, context, target, time);
  return TRUE;
}

void OnDragDataReceived(GtkWidget* /*widget*/, GdkDragContext* context,
                        gint /*x*/, gint /*y*/, GtkSelectionData* selection,
                        guint /*info*/, guint time, gpointer user_data) {
  DropwellPlugin* self = DROPWELL_PLUGIN(user_data);
  const guchar* data = gtk_selection_data_get_data(selection);
  const gint length = gtk_selection_data_get_length(selection);
  const std::string payload =
      data == nullptr || length <= 0
          ? std::string()
          : std::string(reinterpret_cast<const char*>(data),
                        static_cast<size_t>(length));
  dropwell_plugin_deliver_uri_list(self, self->state->drop_x,
                                   self->state->drop_y, payload);
  gtk_drag_finish(context, TRUE, FALSE, time);
}

FlMethodResponse* ReadClipboardFiles() {
  GtkClipboard* clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
  g_autoptr(FlValue) files = fl_value_new_list();

  if (gtk_clipboard_wait_is_uris_available(clipboard)) {
    g_auto(GStrv) uris = gtk_clipboard_wait_for_uris(clipboard);
    for (gchar** uri = uris; uri != nullptr && *uri != nullptr; uri++) {
      for (const std::string& path : dropwell::ParseUriList(*uri)) {
        fl_value_append_take(files, EncodeFile(path));
      }
    }
    return FL_METHOD_RESPONSE(fl_method_success_response_new(files));
  }

  if (gtk_clipboard_wait_is_image_available(clipboard)) {
    g_autoptr(GdkPixbuf) pixbuf = gtk_clipboard_wait_for_image(clipboard);
    g_autofree gchar* buffer = nullptr;
    gsize size = 0;
    if (pixbuf != nullptr &&
        gdk_pixbuf_save_to_buffer(pixbuf, &buffer, &size, "png", nullptr,
                                  nullptr)) {
      FlValue* map = fl_value_new_map();
      fl_value_set_string_take(map, "fileName",
                               fl_value_new_string("pasted-image.png"));
      fl_value_set_string_take(map, "mimeType",
                               fl_value_new_string("image/png"));
      fl_value_set_string_take(
          map, "bytes",
          fl_value_new_uint8_list(reinterpret_cast<const uint8_t*>(buffer),
                                  size));
      fl_value_append_take(files, map);
    }
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(files));
}

FlMethodResponse* PublishDropRegions(DropwellPlugin* self, FlValue* args) {
  if (args == nullptr ||
      fl_value_get_type(args) != FL_VALUE_TYPE_FLOAT_LIST) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "bad-arguments", "publishDropRegions needs a double list", nullptr));
  }
  const double* values = fl_value_get_float_list(args);
  const size_t length = fl_value_get_length(args);
  auto parsed =
      dropwell::ParseRegions(std::vector<double>(values, values + length));
  if (!parsed.has_value()) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "bad-arguments", "publishDropRegions needs groups of four doubles",
        nullptr));
  }
  self->state->regions = std::move(*parsed);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

void MethodCallCallback(FlMethodChannel* /*channel*/, FlMethodCall* method_call,
                        gpointer user_data) {
  DropwellPlugin* self = DROPWELL_PLUGIN(user_data);
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "readClipboardFiles") == 0) {
    response = ReadClipboardFiles();
  } else if (strcmp(method, "publishDropRegions") == 0) {
    response = PublishDropRegions(self, fl_method_call_get_args(method_call));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(method_call, response, nullptr);
}

void AttachDropTarget(DropwellPlugin* self) {
  GtkWidget* view = self->view;
  if (view == nullptr) return;
  GtkTargetEntry target = {const_cast<gchar*>(kUriListTarget), 0, 0};
  // No GtkDestDefaults flags, because every accept decision is answered from
  // the region list Dart published rather than by GTK's default policy.
  gtk_drag_dest_set(view, static_cast<GtkDestDefaults>(0), &target, 1,
                    GDK_ACTION_COPY);
  g_signal_connect(view, "drag-motion", G_CALLBACK(OnDragMotion), self);
  g_signal_connect(view, "drag-leave", G_CALLBACK(OnDragLeave), self);
  g_signal_connect(view, "drag-drop", G_CALLBACK(OnDragDrop), self);
  g_signal_connect(view, "drag-data-received", G_CALLBACK(OnDragDataReceived),
                   self);
}

}  // namespace

void dropwell_plugin_report_drag(DropwellPlugin* plugin, const char* phase,
                                 double x, double y) {
  g_autoptr(FlValue) arguments = fl_value_new_map();
  fl_value_set_string_take(arguments, "phase", fl_value_new_string(phase));
  fl_value_set_string_take(arguments, "x", fl_value_new_float(x));
  fl_value_set_string_take(arguments, "y", fl_value_new_float(y));
  fl_value_set_string_take(arguments, "files", fl_value_new_list());
  fl_method_channel_invoke_method(plugin->channel, "drag", arguments, nullptr,
                                  nullptr, nullptr);
}

void dropwell_plugin_deliver_uri_list(DropwellPlugin* plugin, double x,
                                      double y, const std::string& uri_list) {
  g_autoptr(FlValue) files = fl_value_new_list();
  for (const std::string& path : dropwell::ParseUriList(uri_list)) {
    fl_value_append_take(files, EncodeFile(path));
  }
  g_autoptr(FlValue) arguments = fl_value_new_map();
  fl_value_set_string_take(arguments, "phase", fl_value_new_string("perform"));
  fl_value_set_string_take(arguments, "x", fl_value_new_float(x));
  fl_value_set_string_take(arguments, "y", fl_value_new_float(y));
  fl_value_set_string(arguments, "files", files);
  fl_method_channel_invoke_method(plugin->channel, "drag", arguments, nullptr,
                                  nullptr, nullptr);
}

gboolean dropwell_plugin_accepts(DropwellPlugin* plugin, double x, double y) {
  return dropwell::AnyContains(plugin->state->regions, x, y) ? TRUE : FALSE;
}

GtkWidget* dropwell_plugin_view(DropwellPlugin* plugin) {
  return plugin->view;
}

static void dropwell_plugin_dispose(GObject* object) {
  DropwellPlugin* self = DROPWELL_PLUGIN(object);
  g_clear_object(&self->channel);
  delete self->state;
  self->state = nullptr;
  G_OBJECT_CLASS(dropwell_plugin_parent_class)->dispose(object);
}

static void dropwell_plugin_class_init(DropwellPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = dropwell_plugin_dispose;
}

static void dropwell_plugin_init(DropwellPlugin* self) {
  self->state = new State();
}

void dropwell_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  DropwellPlugin* plugin =
      DROPWELL_PLUGIN(g_object_new(dropwell_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "dropwell",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      plugin->channel, MethodCallCallback, g_object_ref(plugin),
      g_object_unref);

  plugin->view = GTK_WIDGET(fl_plugin_registrar_get_view(registrar));
  AttachDropTarget(plugin);
  dropwell_register_testing_channel(registrar, plugin);

  g_object_unref(plugin);
}
