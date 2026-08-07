#include "include/browsewell/browsewell_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gdk/gdkkeysyms.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>
#include <webkit2/webkit2.h>

#include <cstring>
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

WebKitWebView* FindWebView(GtkWidget* widget) {
  if (WEBKIT_IS_WEB_VIEW(widget) && gtk_widget_get_visible(widget)) {
    return WEBKIT_WEB_VIEW(widget);
  }
  if (!GTK_IS_CONTAINER(widget)) return nullptr;
  WebKitWebView* found = nullptr;
  gtk_container_forall(
      GTK_CONTAINER(widget),
      [](GtkWidget* child, gpointer data) {
        auto** result = static_cast<WebKitWebView**>(data);
        if (*result == nullptr) *result = FindWebView(child);
      },
      &found);
  return found;
}

const FlValue* Argument(FlMethodCall* call, const char* key) {
  FlValue* arguments = fl_method_call_get_args(call);
  if (arguments == nullptr || fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP)
    return nullptr;
  return fl_value_lookup_string(arguments, key);
}

double Number(const FlValue* value) {
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
  for (const auto type : {GDK_KEY_PRESS, GDK_KEY_RELEASE}) {
    GdkEvent* event = gdk_event_new(type);
    event->key.window = GDK_WINDOW(g_object_ref(window));
    event->key.send_event = FALSE;
    event->key.time = GDK_CURRENT_TIME;
    event->key.state = state;
    event->key.keyval = keyval;
    event->key.hardware_keycode = 0;
    event->key.group = 0;
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
  if (type == GDK_MOTION_NOTIFY) {
    event->motion.window = GDK_WINDOW(g_object_ref(window));
    event->motion.send_event = FALSE;
    event->motion.time = GDK_CURRENT_TIME;
    event->motion.x = x;
    event->motion.y = y;
    event->motion.state = state;
    event->motion.device = device;
  } else {
    event->button.window = GDK_WINDOW(g_object_ref(window));
    event->button.send_event = FALSE;
    event->button.time = GDK_CURRENT_TIME;
    event->button.x = x;
    event->button.y = y;
    event->button.state = state;
    event->button.button = button;
    event->button.device = device;
  }
  gtk_main_do_event(event);
  gdk_event_free(event);
}

bool RectCenter(const FlValue* rect, double* x, double* y) {
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
  WebKitWebView* webview = FindWebView(root);
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
    const FlValue* text = Argument(call, "text");
    const FlValue* replace = Argument(call, "replace");
    if (replace != nullptr && fl_value_get_type(replace) == FL_VALUE_TYPE_BOOL &&
        fl_value_get_bool(replace)) {
      SendKey(webview, GDK_KEY_a, GDK_CONTROL_MASK);
    }
    SendText(webview, text == nullptr ? "" : fl_value_get_string(text));
    RespondSuccess(call);
  } else if (strcmp(method, "keypress") == 0) {
    const FlValue* key = Argument(call, "key");
    SendKey(webview, KeyValue(key == nullptr ? nullptr : fl_value_get_string(key)));
    RespondSuccess(call);
  } else if (strcmp(method, "select") == 0) {
    const FlValue* value = Argument(call, "value");
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
    SendPointer(webview, GDK_BUTTON_PRESS, sx, sy, 1);
    SendPointer(webview, GDK_MOTION_NOTIFY, tx, ty, 0, GDK_BUTTON1_MASK);
    SendPointer(webview, GDK_BUTTON_RELEASE, tx, ty, 1);
    RespondSuccess(call);
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
    const FlValue* full_page = Argument(call, "fullPage");
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
    RespondError(call, "unsupported", "Native upload is not implemented yet.");
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
