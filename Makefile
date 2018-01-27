
ERLANG_PATH = $(shell erl -args_file get_erl_path.args)
BIN_DIR=priv
C_SRC=$(wildcard c_src/*.c) $(wildcard c_src/pugl/pugl/*.c) $(wildcard c_src/nanovg/src/*.c) $(wildcard c_src/glew-2.1.0/src/*.c)
OBJECTS=$(C_SRC:.c=.o)

CFLAGS=-g -Wall -fpic -Ic_src/glew-2.1.0/include -Ic_src/pugl -Ic_src/nanovg/src -I$(ERLANG_PATH) -DPUGL_HAVE_GL -DVZ_PLATFORM_X11 -DVZ_LOG_TIMING -O2
LDFLAGS=-g -shared -lX11 -lXxf86vm -lm -lGL

$(BIN_DIR)/vz_nif.so: $(OBJECTS)
	mkdir -p priv
	$(CC) -o $@ $^ $(CFLAGS) $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) $(LDFLAGS) -c $< -o $@


.PHONY: clean

clean:
	rm -rf ./priv/vz_nif.so ./c_src/*.o ./c_src/pugl/pugl/*.o ./c_src/nanovg/src/*.o
