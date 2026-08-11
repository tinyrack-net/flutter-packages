/* wlkey: virtual-keyboard-v1 injector with a physical xkb layout.
 *
 * wtype builds a compact keymap whose keycodes do not match a physical
 * keyboard. ibus-hangul re-derives keysyms from those keycodes against a
 * built-in US map, so this test helper uploads the standard kr layout and
 * sends real evdev-compatible keycodes instead.
 *
 * Usage: wlkey [-g gap_ms] TOKEN...
 * TOKEN is an xkb keysym name or "shift+NAME" for a shifted chord.
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <time.h>

#include <wayland-client.h>
#include <xkbcommon/xkbcommon.h>

#include "vk-client.h"

static struct zwp_virtual_keyboard_manager_v1 *vk_manager;
static struct wl_seat *seat;

static void registry_global(void *data, struct wl_registry *registry,
                            uint32_t name, const char *interface,
                            uint32_t version) {
  (void)data;
  (void)version;
  if (strcmp(interface, zwp_virtual_keyboard_manager_v1_interface.name) == 0) {
    vk_manager = wl_registry_bind(
        registry, name, &zwp_virtual_keyboard_manager_v1_interface, 1);
  } else if (strcmp(interface, wl_seat_interface.name) == 0 && seat == NULL) {
    seat = wl_registry_bind(registry, name, &wl_seat_interface, 1);
  }
}

static void registry_global_remove(void *data, struct wl_registry *registry,
                                   uint32_t name) {
  (void)data;
  (void)registry;
  (void)name;
}

static const struct wl_registry_listener registry_listener = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

static uint32_t now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (uint32_t)(ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
}

static xkb_keycode_t find_keycode(struct xkb_keymap *keymap,
                                  xkb_keysym_t sym) {
  xkb_keycode_t min = xkb_keymap_min_keycode(keymap);
  xkb_keycode_t max = xkb_keymap_max_keycode(keymap);
  for (xkb_keycode_t kc = min; kc <= max; kc++) {
    const xkb_keysym_t *syms;
    int count = xkb_keymap_key_get_syms_by_level(keymap, kc, 0, 0, &syms);
    for (int index = 0; index < count; index++) {
      if (syms[index] == sym) return kc;
    }
  }
  return XKB_KEYCODE_INVALID;
}

int main(int argc, char **argv) {
  int gap_ms = 100;
  int argument = 1;
  if (argument < argc && strcmp(argv[argument], "-g") == 0) {
    gap_ms = atoi(argv[argument + 1]);
    argument += 2;
  }

  struct wl_display *display = wl_display_connect(NULL);
  if (!display) {
    fprintf(stderr, "wlkey: cannot connect to Wayland display\n");
    return 1;
  }
  struct wl_registry *registry = wl_display_get_registry(display);
  wl_registry_add_listener(registry, &registry_listener, NULL);
  wl_display_roundtrip(display);
  if (!vk_manager || !seat) {
    fprintf(stderr, "wlkey: compositor lacks virtual-keyboard-v1 or seat\n");
    return 1;
  }

  struct zwp_virtual_keyboard_v1 *keyboard =
      zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(vk_manager,
                                                              seat);
  struct xkb_context *context = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
  struct xkb_rule_names names = {.rules = "evdev", .layout = "kr"};
  struct xkb_keymap *keymap =
      xkb_keymap_new_from_names(context, &names,
                               XKB_KEYMAP_COMPILE_NO_FLAGS);
  if (!keymap) {
    fprintf(stderr, "wlkey: cannot compile kr keymap\n");
    return 1;
  }
  char *keymap_string =
      xkb_keymap_get_as_string(keymap, XKB_KEYMAP_FORMAT_TEXT_V1);
  size_t keymap_size = strlen(keymap_string) + 1;
  int file_descriptor = memfd_create("wlkey-keymap", 0);
  if (file_descriptor < 0 ||
      write(file_descriptor, keymap_string, keymap_size) < 0) {
    fprintf(stderr, "wlkey: cannot write keymap fd\n");
    return 1;
  }
  zwp_virtual_keyboard_v1_keymap(keyboard,
                                 WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1,
                                 file_descriptor, (uint32_t)keymap_size);
  wl_display_roundtrip(display);
  usleep(200 * 1000);

  xkb_mod_index_t shift_index =
      xkb_keymap_mod_get_index(keymap, XKB_MOD_NAME_SHIFT);
  uint32_t shift_mask = (uint32_t)1 << shift_index;

  for (int index = argument; index < argc; index++) {
    const char *token = argv[index];
    int shifted = 0;
    if (strncmp(token, "shift+", 6) == 0) {
      shifted = 1;
      token += 6;
    }
    xkb_keysym_t symbol = xkb_keysym_from_name(token, XKB_KEYSYM_NO_FLAGS);
    if (symbol == XKB_KEY_NoSymbol) {
      fprintf(stderr, "wlkey: unknown keysym '%s'\n", token);
      return 1;
    }
    xkb_keycode_t keycode = find_keycode(keymap, symbol);
    if (keycode == XKB_KEYCODE_INVALID) {
      fprintf(stderr, "wlkey: keysym '%s' not in kr layout\n", token);
      return 1;
    }
    uint32_t evdev = (uint32_t)keycode - 8;

    if (shifted) {
      zwp_virtual_keyboard_v1_modifiers(keyboard, shift_mask, 0, 0, 0);
      wl_display_flush(display);
      usleep(30 * 1000);
    }
    zwp_virtual_keyboard_v1_key(keyboard, now_ms(), evdev,
                                WL_KEYBOARD_KEY_STATE_PRESSED);
    wl_display_flush(display);
    usleep(40 * 1000);
    zwp_virtual_keyboard_v1_key(keyboard, now_ms(), evdev,
                                WL_KEYBOARD_KEY_STATE_RELEASED);
    wl_display_flush(display);
    if (shifted) {
      usleep(30 * 1000);
      zwp_virtual_keyboard_v1_modifiers(keyboard, 0, 0, 0, 0);
      wl_display_flush(display);
    }
    usleep((useconds_t)gap_ms * 1000);
  }

  wl_display_roundtrip(display);
  zwp_virtual_keyboard_v1_destroy(keyboard);
  wl_display_disconnect(display);
  free(keymap_string);
  return 0;
}
