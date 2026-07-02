#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // Modo visor (--play): la ventana toma el nombre del canal (--name) y un
  // tamaño más contenido, pensado para ver varias a la vez.
  std::wstring window_title = L"IPTV Player";
  bool viewer_mode = false;
  for (size_t i = 0; i < command_line_arguments.size(); ++i) {
    const std::string& arg = command_line_arguments[i];
    if (arg == "--play") {
      viewer_mode = true;
    } else if (arg == "--name" && i + 1 < command_line_arguments.size()) {
      const std::string& name = command_line_arguments[i + 1];
      int len = ::MultiByteToWideChar(CP_UTF8, 0, name.c_str(), -1, nullptr, 0);
      if (len > 1) {
        std::wstring wide(static_cast<size_t>(len) - 1, L'\0');
        ::MultiByteToWideChar(CP_UTF8, 0, name.c_str(), -1, &wide[0], len);
        window_title = wide;
      }
    }
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (viewer_mode) {
    origin = Win32Window::Point(60, 60);
    size = Win32Window::Size(880, 495);
  }
  if (!window.Create(window_title.c_str(), origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
