SETLOCAL ENABLEEXTENSIONS
FOR /F "delims=" %%i IN ('erl -args_file get_erl_path.args') DO set erlang_path=%%i
cl /Z7 -D WINDOWS -D PUGL_HAVE_GL -D NANOVG_GLEW -LD -MD -I%erlang_path% -Ic_src/pugl -Ic_src/nanovg/src -Ic_src/glew-2.1.0/include -Fe c_src/vz_nif.c c_src/vz_atoms.c c_src/vz_resources.c c_src/vz_events.c c_src/vz_view_thread.c c_src/pugl/pugl/pugl_win.cpp c_src/nanovg/src/nanovg.c winmm.lib glew32.lib user32.lib gdi32.lib glu32.lib opengl32.lib kernel32.lib
mkdir priv\
move /Y vz_nif.dll priv\