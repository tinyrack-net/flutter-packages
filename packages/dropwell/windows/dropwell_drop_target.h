#ifndef FLUTTER_PLUGIN_DROPWELL_DROP_TARGET_H_
#define FLUTTER_PLUGIN_DROPWELL_DROP_TARGET_H_

#include <objidl.h>
#include <oleidl.h>
#include <windows.h>

#include <functional>
#include <vector>

#include "dropwell_data.h"
#include "dropwell_reader.h"

namespace dropwell {

/// What the plugin wants to know about a drag session.
struct DropDelegate {
  /// Regions currently accepting a drop, in physical pixels.
  std::function<const std::vector<Rect>&()> regions;

  /// Reports a drag phase with a position relative to the view origin.
  std::function<void(const char* phase, double x, double y,
                     std::vector<FileItem> files)>
      report;
};

/// Receives OLE drag-and-drop for the Flutter view.
///
/// The answer to "will you accept this?" has to be returned synchronously from
/// inside `DragOver`, so it is computed from the region list Dart published
/// ahead of the drag. Asking Dart here would deadlock the platform thread.
class DropTarget : public IDropTarget {
 public:
  DropTarget(HWND window, DropDelegate delegate);

  DropTarget(const DropTarget&) = delete;
  DropTarget& operator=(const DropTarget&) = delete;

  // IUnknown.
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** object) override;
  ULONG STDMETHODCALLTYPE AddRef() override;
  ULONG STDMETHODCALLTYPE Release() override;

  // IDropTarget.
  HRESULT STDMETHODCALLTYPE DragEnter(IDataObject* data, DWORD key_state,
                                      POINTL point, DWORD* effect) override;
  HRESULT STDMETHODCALLTYPE DragOver(DWORD key_state, POINTL point,
                                     DWORD* effect) override;
  HRESULT STDMETHODCALLTYPE DragLeave() override;
  HRESULT STDMETHODCALLTYPE Drop(IDataObject* data, DWORD key_state,
                                 POINTL point, DWORD* effect) override;

 private:
  /// Converts a screen position to physical pixels inside the view.
  bool ToViewPoint(POINTL screen, double* x, double* y) const;

  HWND window_;
  DropDelegate delegate_;
  bool acceptable_ = false;
  ULONG reference_count_ = 1;
};

}  // namespace dropwell

#endif  // FLUTTER_PLUGIN_DROPWELL_DROP_TARGET_H_
