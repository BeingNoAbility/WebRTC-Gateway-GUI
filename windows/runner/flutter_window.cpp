#include "flutter_window.h"

#include <commctrl.h>
#include <cwchar>
#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr UINT_PTR kViewSubclassId = 0x5747;

bool ShouldAllowAccessibility() {
  const wchar_t* cmd = ::GetCommandLineW();
  if (cmd != nullptr && ::wcsstr(cmd, L"--enable-accessibility") != nullptr) {
    return true;
  }
  BOOL screen_reader = FALSE;
  if (::SystemParametersInfoW(SPI_GETSCREENREADER, 0, &screen_reader, 0) &&
      screen_reader != FALSE) {
    return true;
  }
  return false;
}

LRESULT CALLBACK FlutterViewSubclassProc(HWND hwnd,
                                         UINT message,
                                         WPARAM wparam,
                                         LPARAM lparam,
                                         UINT_PTR subclass_id,
                                         DWORD_PTR /*ref_data*/) {
  // Flutter 3.50.1 on Windows has an engine bug in
  // AccessibilityBridge::CreateRemoveReparentedNodesUpdate (0xc0000005 /
  // 0xc000041d) when background RDP/IME/shell utilities send WM_GETOBJECT
  // and semantics nodes reparent during navigation transitions. Only activate
  // the accessibility bridge when an actual screen reader is active or the
  // user opts in via --enable-accessibility.
  if (message == WM_GETOBJECT && !ShouldAllowAccessibility()) {
    return ::DefWindowProcW(hwnd, message, wparam, lparam);
  }
  if (message == WM_NCDESTROY) {
    ::RemoveWindowSubclass(hwnd, FlutterViewSubclassProc, subclass_id);
  }
  return ::DefSubclassProc(hwnd, message, wparam, lparam);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  view_hwnd_ = flutter_controller_->view()->GetNativeWindow();
  SetChildContent(view_hwnd_);
  if (view_hwnd_ != nullptr) {
    ::SetWindowSubclass(view_hwnd_, FlutterViewSubclassProc, kViewSubclassId,
                        0);
  }

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (view_hwnd_ != nullptr) {
    ::RemoveWindowSubclass(view_hwnd_, FlutterViewSubclassProc,
                           kViewSubclassId);
    view_hwnd_ = nullptr;
  }

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_GETOBJECT && !ShouldAllowAccessibility()) {
    return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
