#include "include/browsewell/browsewell_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gdk/gdkkeysyms.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>
#include <webkit2/webkit2.h>

#include <cstring>
#include <limits>
#include <string>
#include <vector>

#include "browsewell_plugin_private.h"

#define BROWSEWELL_PLUGIN(obj)                                      \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), browsewell_plugin_get_type(), \
                              BrowsewellPlugin))

struct _BrowsewellPlugin {
  GObject parent_instance;
  FlView* view;
};

G_DEFINE_TYPE(BrowsewellPlugin, browsewell_plugin, g_object_get_type())

namespace {

struct WebViewSearch {
  GtkWidget* root;
  double target_x;
  double target_y;
  double distance = std::numeric_limits<double>::max();
  WebKitWebView* found = nullptr;
};

void FindWebView(GtkWidget* widget, WebViewSearch* search) {
  if (WEBKIT_IS_WEB_VIEW(widget) && gtk_widget_get_visible(widget)) {
    gint x = 0;
    gint y = 0;
    if (gtk_widget_translate_coordinates(widget, search->root, 0, 0, &x, &y)) {
      const double dx = x - search->target_x;
      const double dy = y - search->target_y;
      const double distance = dx * dx + dy * dy;
      if (distance < search->distance) {
        search->distance = distance;
        search->found = WEBKIT_WEB_VIEW(widget);
      }
    }
  }
  if (!GTK_IS_CONTAINER(widget)) return;
  gtk_container_forall(
      GTK_CONTAINER(widget),
      [](GtkWidget* child, gpointer data) {
        FindWebView(child, static_cast<WebViewSearch*>(data));
      },
      search);
}

FlValue* Argument(FlMethodCall* call, const char* key) {
  FlValue* arguments = fl_method_call_get_args(call);
  if (arguments == nullptr || fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP)
    return nullptr;
  return fl_value_lookup_string(arguments, key);
}

double Number(FlValue* value) {
  if (value == nullptr) return 0;
  if (fl_value_get_type(value) == FL_VALUE_TYPE_FLOAT)
    return fl_value_get_float(value);
  if (fl_value_get_type(value) == FL_VALUE_TYPE_INT)
    return static_cast<double>(fl_value_get_int(value));
  return 0;
}

void RespondSuccess(FlMethodCall* call, FlValue* value = nullptr) {
  g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
      fl_method_success_response_new(value));
  fl_method_call_respond(call, response, nullptr);
}

void RespondError(FlMethodCall* call, const char* code, const char* message) {
  g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
      fl_method_error_response_new(code, message, nullptr));
  fl_method_call_respond(call, response, nullptr);
}

void SendKey(WebKitWebView* webview, guint keyval, GdkModifierType state =
                                                  static_cast<GdkModifierType>(0)) {
  GdkWindow* window = gtk_widget_get_window(GTK_WIDGET(webview));
  if (window == nullptr) return;
  GdkKeymap* keymap = gdk_keymap_get_for_display(gdk_window_get_display(window));
  GdkKeymapKey* keys = nullptr;
  gint key_count = 0;
  guint hardware_keycode = 0;
  gint group = 0;
  if (gdk_keymap_get_entries_for_keyval(keymap, keyval, &keys, &key_count) &&
      key_count > 0) {
    hardware_keycode = keys[0].keycode;
    group = keys[0].group;
    if (keys[0].level == 1) {
      state = static_cast<GdkModifierType>(state | GDK_SHIFT_MASK);
    }
  }
  g_free(keys);
  for (const auto type : {GDK_KEY_PRESS, GDK_KEY_RELEASE}) {
    GdkEvent* event = gdk_event_new(type);
    event->key.window = GDK_WINDOW(g_object_ref(window));
    event->key.send_event = FALSE;
    event->key.time = GDK_CURRENT_TIME;
    event->key.state = state;
    event->key.keyval = keyval;
    event->key.hardware_keycode = hardware_keycode;
    event->key.group = group;
    event->key.is_modifier = FALSE;
    gtk_main_do_event(event);
    gdk_event_free(event);
  }
}

void SendText(WebKitWebView* webview, const gchar* text) {
  for (const gchar* cursor = text; cursor != nullptr && *cursor != '\0';
       cursor = g_utf8_next_char(cursor)) {
    SendKey(webview, gdk_unicode_to_keyval(g_utf8_get_char(cursor)));
  }
}

void SendPointer(WebKitWebView* webview, GdkEventType type, double x, double y,
                 guint button = 0,
                 GdkModifierType state = static_cast<GdkModifierType>(0)) {
  GtkWidget* widget = GTK_WIDGET(webview);
  GdkWindow* window = gtk_widget_get_window(widget);
  if (window == nullptr) return;
  GdkEvent* event = gdk_event_new(type);
  GdkDisplay* display = gtk_widget_get_display(widget);
  GdkDevice* device =
      gdk_seat_get_pointer(gdk_display_get_default_seat(display));
  gint root_x = 0;
  gint root_y = 0;
  gdk_window_get_root_coords(window, static_cast<gint>(x),
                             static_cast<gint>(y), &root_x, &root_y);
  if (type == GDK_MOTION_NOTIFY) {
    event->motion.window = GDK_WINDOW(g_object_ref(window));
    event->motion.send_event = FALSE;
    event->motion.time = GDK_CURRENT_TIME;
    event->motion.x = x;
    event->motion.y = y;
    event->motion.x_root = root_x;
    event->motion.y_root = root_y;
    event->motion.state = state;
    event->motion.is_hint = FALSE;
    event->motion.device = device;
  } else {
    event->button.window = GDK_WINDOW(g_object_ref(window));
    event->button.send_event = FALSE;
    event->button.time = GDK_CURRENT_TIME;
    event->button.x = x;
    event->button.y = y;
    event->button.x_root = root_x;
    event->button.y_root = root_y;
    event->button.state = state;
    event->button.button = button;
    event->button.device = device;
  }
  gtk_main_do_event(event);
  gdk_event_free(event);
}

bool RectCenter(FlValue* rect, double* x, double* y) {
  if (rect == nullptr || fl_value_get_type(rect) != FL_VALUE_TYPE_MAP)
    return false;
  *x = Number(fl_value_lookup_string(rect, "left")) +
       Number(fl_value_lookup_string(rect, "width")) / 2;
  *y = Number(fl_value_lookup_string(rect, "top")) +
       Number(fl_value_lookup_string(rect, "height")) / 2;
  return true;
}

guint KeyValue(const gchar* key) {
  if (key == nullptr) return 0;
  if (strcmp(key, "Enter") == 0) return GDK_KEY_Return;
  if (strcmp(key, "Tab") == 0) return GDK_KEY_Tab;
  if (strcmp(key, "Escape") == 0) return GDK_KEY_Escape;
  if (strcmp(key, "Backspace") == 0) return GDK_KEY_BackSpace;
  if (strcmp(key, "Delete") == 0) return GDK_KEY_Delete;
  if (strcmp(key, "Home") == 0) return GDK_KEY_Home;
  if (strcmp(key, "End") == 0) return GDK_KEY_End;
  if (strcmp(key, "ArrowUp") == 0) return GDK_KEY_Up;
  if (strcmp(key, "ArrowDown") == 0) return GDK_KEY_Down;
  if (strcmp(key, "ArrowLeft") == 0) return GDK_KEY_Left;
  if (strcmp(key, "ArrowRight") == 0) return GDK_KEY_Right;
  return gdk_unicode_to_keyval(g_utf8_get_char(key));
}

struct SnapshotRequest {
  FlMethodCall* call;
  std::vector<uint8_t> bytes;
};

struct UploadRequest {
  FlMethodCall* call;
  gulong handler;
  std::vector<std::string> paths;
};

struct DragRequest {
  FlMethodCall* call;
  WebKitWebView* webview;
  double source_x;
  double source_y;
  double target_x;
  double target_y;
  int step;
};

gboolean ContinueDrag(gpointer data) {
  auto* request = static_cast<DragRequest*>(data);
  constexpr int kMotionSteps = 8;
  if (request->step == 0) {
    SendPointer(request->webview, GDK_BUTTON_PRESS, request->source_x,
                request->source_y, 1);
  } else if (request->step <= kMotionSteps) {
    const double progress = static_cast<double>(request->step) / kMotionSteps;
    SendPointer(request->webview, GDK_MOTION_NOTIFY,
                request->source_x +
                    (request->target_x - request->source_x) * progress,
                request->source_y +
                    (request->target_y - request->source_y) * progress,
                0, GDK_BUTTON1_MASK);
  } else {
    SendPointer(request->webview, GDK_BUTTON_RELEASE, request->target_x,
                request->target_y, 1);
    RespondSuccess(request->call);
    g_object_unref(request->call);
    g_object_unref(request->webview);
    delete request;
    return G_SOURCE_REMOVE;
  }
  request->step += 1;
  return G_SOURCE_CONTINUE;
}

gboolean FileChooserReady(WebKitWebView* webview,
                          WebKitFileChooserRequest* chooser,
                          gpointer user_data) {
  auto* request = static_cast<UploadRequest*>(user_data);
  std::vector<const gchar*> paths;
  paths.reserve(request->paths.size() + 1);
  for (const auto& path : request->paths) paths.push_back(path.c_str());
  paths.push_back(nullptr);
  webkit_file_chooser_request_select_files(chooser, paths.data());
  RespondSuccess(request->call);
  g_signal_handler_disconnect(webview, request->handler);
  return TRUE;
}

void DeleteUploadRequest(gpointer data, GClosure*) {
  auto* request = static_cast<UploadRequest*>(data);
  g_object_unref(request->call);
  delete request;
}

cairo_status_t WritePng(void* closure, const unsigned char* data,
                        unsigned int length) {
  auto* request = static_cast<SnapshotRequest*>(closure);
  request->bytes.insert(request->bytes.end(), data, data + length);
  return CAIRO_STATUS_SUCCESS;
}

void SnapshotReady(GObject* source, GAsyncResult* result, gpointer user_data) {
  auto* request = static_cast<SnapshotRequest*>(user_data);
  g_autoptr(GError) error = nullptr;
  cairo_surface_t* surface = webkit_web_view_get_snapshot_finish(
      WEBKIT_WEB_VIEW(source), result, &error);
  if (surface == nullptr) {
    RespondError(request->call, "internal",
                 error == nullptr ? "Snapshot failed." : error->message);
  } else {
    cairo_surface_write_to_png_stream(surface, WritePng, request);
    g_autoptr(FlValue) bytes = fl_value_new_uint8_list(
        request->bytes.data(), request->bytes.size());
    RespondSuccess(request->call, bytes);
    cairo_surface_destroy(surface);
  }
  g_object_unref(request->call);
  delete request;
}

void HandleMethodCall(BrowsewellPlugin* self, FlMethodCall* call) {
  const gchar* method = fl_method_call_get_name(call);
  if (strcmp(method, "setViewport") == 0) {
    RespondSuccess(call);
    return;
  }
  GtkWidget* root = gtk_widget_get_toplevel(GTK_WIDGET(self->view));
  WebViewSearch search{root, Number(Argument(call, "viewportLeft")),
                       Number(Argument(call, "viewportTop"))};
  FindWebView(root, &search);
  WebKitWebView* webview = search.found;
  if (webview == nullptr) {
    RespondError(call, "no_host", "No visible WebKitWebView is available.");
    return;
  }
  gtk_widget_grab_focus(GTK_WIDGET(webview));

  if (strcmp(method, "click") == 0 || strcmp(method, "hover") == 0) {
    double x = 0;
    double y = 0;
    if (!RectCenter(Argument(call, "rect"), &x, &y)) {
      RespondError(call, "internal", "Element bounds are missing.");
      return;
    }
    SendPointer(webview, GDK_MOTION_NOTIFY, x, y);
    if (strcmp(method, "click") == 0) {
      SendPointer(webview, GDK_BUTTON_PRESS, x, y, 1);
      SendPointer(webview, GDK_BUTTON_RELEASE, x, y, 1);
    }
    RespondSuccess(call);
  } else if (strcmp(method, "type") == 0) {
    FlValue* text = Argument(call, "text");
    FlValue* replace = Argument(call, "replace");
    if (replace != nullptr && fl_value_get_type(replace) == FL_VALUE_TYPE_BOOL &&
        fl_value_get_bool(replace)) {
      SendKey(webview, GDK_KEY_a, GDK_CONTROL_MASK);
    }
    SendText(webview, text == nullptr ? "" : fl_value_get_string(text));
    RespondSuccess(call);
  } else if (strcmp(method, "keypress") == 0) {
    FlValue* key = Argument(call, "key");
    SendKey(webview, KeyValue(key == nullptr ? nullptr : fl_value_get_string(key)));
    RespondSuccess(call);
  } else if (strcmp(method, "select") == 0) {
    FlValue* value = Argument(call, "value");
    SendKey(webview, GDK_KEY_Home);
    SendText(webview, value == nullptr ? "" : fl_value_get_string(value));
    SendKey(webview, GDK_KEY_Return);
    RespondSuccess(call);
  } else if (strcmp(method, "drag") == 0) {
    double sx = 0;
    double sy = 0;
    double tx = 0;
    double ty = 0;
    if (!RectCenter(Argument(call, "source"), &sx, &sy) ||
        !RectCenter(Argument(call, "target"), &tx, &ty)) {
      RespondError(call, "internal", "Drag bounds are missing.");
      return;
    }
    SendPointer(webview, GDK_MOTION_NOTIFY, sx, sy);
    auto* request = new DragRequest{FL_METHOD_CALL(g_object_ref(call)),
                                    WEBKIT_WEB_VIEW(g_object_ref(webview)),
                                    sx, sy, tx, ty, 0};
    g_timeout_add(16, ContinueDrag, request);
  } else if (strcmp(method, "scroll") == 0) {
    GdkWindow* window = gtk_widget_get_window(GTK_WIDGET(webview));
    GdkEvent* event = gdk_event_new(GDK_SCROLL);
    event->scroll.window = GDK_WINDOW(g_object_ref(window));
    event->scroll.send_event = FALSE;
    event->scroll.time = GDK_CURRENT_TIME;
    event->scroll.direction = GDK_SCROLL_SMOOTH;
    event->scroll.delta_x = Number(Argument(call, "deltaX"));
    event->scroll.delta_y = Number(Argument(call, "deltaY"));
    gtk_main_do_event(event);
    gdk_event_free(event);
    RespondSuccess(call);
  } else if (strcmp(method, "screenshot") == 0) {
    FlValue* full_page = Argument(call, "fullPage");
    const bool full = full_page != nullptr &&
                      fl_value_get_type(full_page) == FL_VALUE_TYPE_BOOL &&
                      fl_value_get_bool(full_page);
    auto* request = new SnapshotRequest{FL_METHOD_CALL(g_object_ref(call)), {}};
    webkit_web_view_get_snapshot(
        webview,
        full ? WEBKIT_SNAPSHOT_REGION_FULL_DOCUMENT
             : WEBKIT_SNAPSHOT_REGION_VISIBLE,
        WEBKIT_SNAPSHOT_OPTIONS_NONE, nullptr, SnapshotReady, request);
  } else if (strcmp(method, "upload") == 0) {
    FlValue* raw_paths = Argument(call, "filePaths");
    if (raw_paths == nullptr ||
        fl_value_get_type(raw_paths) != FL_VALUE_TYPE_LIST) {
      RespondError(call, "denied", "Upload paths are missing.");
      return;
    }
    auto* request = new UploadRequest{FL_METHOD_CALL(g_object_ref(call)), 0, {}};
    for (size_t index = 0; index < fl_value_get_length(raw_paths); ++index) {
      FlValue* value = fl_value_get_list_value(raw_paths, index);
      if (fl_value_get_type(value) == FL_VALUE_TYPE_STRING)
        request->paths.emplace_back(fl_value_get_string(value));
    }
    request->handler = g_signal_connect_data(
        webview, "run-file-chooser", G_CALLBACK(FileChooserReady), request,
        DeleteUploadRequest, static_cast<GConnectFlags>(0));
    SendKey(webview, GDK_KEY_Return);
  } else {
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(call, response, nullptr);
  }
}

}  // namespace

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar* version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void browsewell_plugin_dispose(GObject* object) {
  auto* self = BROWSEWELL_PLUGIN(object);
  g_clear_object(&self->view);
  G_OBJECT_CLASS(browsewell_plugin_parent_class)->dispose(object);
}

static void browsewell_plugin_class_init(BrowsewellPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = browsewell_plugin_dispose;
}

static void browsewell_plugin_init(BrowsewellPlugin* self) { self->view = nullptr; }

static void method_call_cb(FlMethodChannel*, FlMethodCall* call,
                           gpointer user_data) {
  HandleMethodCall(BROWSEWELL_PLUGIN(user_data), call);
}

void browsewell_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  BrowsewellPlugin* plugin =
      BROWSEWELL_PLUGIN(g_object_new(browsewell_plugin_get_type(), nullptr));
  plugin->view = FL_VIEW(g_object_ref(fl_plugin_registrar_get_view(registrar)));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "net.tinyrack.browsewell/automation", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);
  g_object_unref(plugin);
}
