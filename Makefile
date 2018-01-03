
ERLANG_PATH = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)
BIN_DIR=priv
C_SRC=$(wildcard c_src/*.c) $(wildcard c_src/pugl/pugl/*.c) $(wildcard c_src/nanovg/src/*.c)
OBJECTS=$(C_SRC:.c=.o)

CFLAGS=-g -Wall -fpic -Ic_src/pugl -Ic_src/nanovg/src -I$(ERLANG_PATH) -DPUGL_HAVE_GL -O2
LDFLAGS=-g -shared -lX11 -lm -lGL -lGLEW

$(BIN_DIR)/vz_nif.so: $(OBJECTS)
	mkdir -p priv
	$(CC) -o $@ $^ $(CFLAGS) $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) $(LDFLAGS) -c $< -o $@


.PHONY: clean

clean:
	rm -rf ./priv/vz_nif.so ./c_src/*.o ./c_src/pugl/pugl/*.o ./c_src/nanovg/src/*.o
