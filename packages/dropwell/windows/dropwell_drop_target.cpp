#include "dropwell_drop_target.h"

namespace dropwell {

DropTarget::DropTarget(HWND window, DropDelegate delegate)
    : window_(window), delegate_(std::move(delegate)) {}

HRESULT STDMETHODCALLTYPE DropTarget::QueryInterface(REFIID riid,
                                                     void** object) {
  if (object == nullptr) return E_POINTER;
  if (riid == IID_IUnknown || riid == IID_IDropTarget) {
    *object = static_cast<IDropTarget*>(this);
    AddRef();
    return S_OK;
  }
  *object = nullptr;
  return E_NOINTERFACE;
}

ULONG STDMETHODCALLTYPE DropTarget::AddRef() { return ++reference_count_; }

ULONG STDMETHODCALLTYPE DropTarget::Release() {
  const ULONG remaining = --reference_count_;
  if (remaining == 0) delete this;
  return remaining;
}

bool DropTarget::ToViewPoint(POINTL screen, double* x, double* y) const {
  POINT point{screen.x, screen.y};
  if (!::ScreenToClient(window_, &point)) return false;
  *x = static_cast<double>(point.x);
  *y = static_cast<double>(point.y);
  return true;
}

HRESULT STDMETHODCALLTYPE DropTarget::DragEnter(IDataObject* data,
                                                DWORD /*key_state*/,
                                                POINTL point, DWORD* effect) {
  acceptable_ = HasSupportedFormat(data);
  double x = 0;
  double y = 0;
  if (!acceptable_ || !ToViewPoint(point, &x, &y)) {
    if (effect != nullptr) *effect = DROPEFFECT_NONE;
    return S_OK;
  }
  delegate_.report("enter", x, y, {});
  if (effect != nullptr) {
    *effect = AnyContains(delegate_.regions(), x, y) ? DROPEFFECT_COPY
                                                     : DROPEFFECT_NONE;
  }
  return S_OK;
}

HRESULT STDMETHODCALLTYPE DropTarget::DragOver(DWORD /*key_state*/,
                                               POINTL point, DWORD* effect) {
  double x = 0;
  double y = 0;
  if (!acceptable_ || !ToViewPoint(point, &x, &y)) {
    if (effect != nullptr) *effect = DROPEFFECT_NONE;
    return S_OK;
  }
  delegate_.report("over", x, y, {});
  if (effect != nullptr) {
    *effect = AnyContains(delegate_.regions(), x, y) ? DROPEFFECT_COPY
                                                     : DROPEFFECT_NONE;
  }
  return S_OK;
}

HRESULT STDMETHODCALLTYPE DropTarget::DragLeave() {
  if (acceptable_) delegate_.report("leave", 0, 0, {});
  acceptable_ = false;
  return S_OK;
}

HRESULT STDMETHODCALLTYPE DropTarget::Drop(IDataObject* data,
                                           DWORD /*key_state*/, POINTL point,
                                           DWORD* effect) {
  acceptable_ = false;
  double x = 0;
  double y = 0;
  if (!ToViewPoint(point, &x, &y)) {
    if (effect != nullptr) *effect = DROPEFFECT_NONE;
    return S_OK;
  }
  // The payload is read even when the point sits outside every region: the
  // region list is a frame behind reality, and Dart does the authoritative hit
  // test against live render objects.
  std::vector<FileItem> files = ReadDataObject(data);
  delegate_.report("perform", x, y, std::move(files));
  if (effect != nullptr) *effect = DROPEFFECT_COPY;
  return S_OK;
}

}  // namespace dropwell
