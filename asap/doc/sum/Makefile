CC=asap-clang

CFLAGS=-Wall -g -O1 -fsanitize=address
LDFLAGS=-fsanitize=address

all: stamps/sum-asap-optimize

sum: sum.o
sum.o: sum.c

stamps/sum-asap-init:
	@if [ -z "$$ASAP_STATE_PATH" ]; then \
	  echo "Please run:"; \
	  echo "export ASAP_STATE_PATH=$$(pwd)/asap_state"; \
	  exit 1; \
	fi
	asap-clang -asap-init >/dev/null
	mkdir -p stamps
	touch $@

stamps/sum-compile: stamps/sum-asap-init sum
	mkdir -p stamps
	touch $@

stamps/sum-asap-coverage: stamps/sum-compile
	asap-clang -asap-coverage
	rm -f *.o sum
	$(MAKE) sum
	touch $@

stamps/sum-asap-profile: stamps/sum-asap-coverage
	echo 22 | ./sum
	echo 99 | ./sum
	echo -77 | ./sum
	echo 123 | ./sum || true
	touch $@

stamps/sum-asap-optimize: stamps/sum-asap-profile
	asap-clang -asap-optimize -asap-sanity-level=0.5
	rm -f *.o sum
	$(MAKE) sum
	touch $@

clean:
	rm -fr stamps asap_state asap-*.log *.o *.gcda *.gcno sum
