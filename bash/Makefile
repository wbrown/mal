TESTS = tests/types.sh tests/reader.sh

SOURCES_BASE = types.sh reader.sh printer.sh
SOURCES_LISP = env.sh core.sh stepA_more.sh
SOURCES = $(SOURCES_BASE) $(SOURCES_LISP)

all: mal.sh

mal.sh: $(SOURCES)
	cat $+ > $@
	echo "#!/bin/bash" > $@
	cat $+ | grep -v "^source " >> $@
	chmod +x $@

clean:
	rm -f mal.sh

.PHONY: stats tests $(TESTS)

stats: $(SOURCES)
	@wc $^
stats-lisp: $(SOURCES_LISP)
	@wc $^

tests: $(TESTS)

$(TESTS):
	@echo "Running $@"; \
	bash $@ || exit 1; \
