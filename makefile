CC=gcc -std=gnu99 # speed tests don't work with -std=cxx, they need the POSIX extensions
CFLAGS= -pedantic -Wall -Wextra -O3 -march=native
DESTDIR=
PREFIX=usr/local
PKGCONFIG=$(DESTDIR)/$(PREFIX)/lib/pkgconfig
MAN_DIR=$(DESTDIR)/$(PREFIX)/share/man/man3

TARBALL_VERSION=$$(cat VERSION.md)
TARBALL_DIR=.

ifeq ($(findstring -DED25519_SHA512, $(CFLAGS)),)
LINK_SHA512=
else
LINK_SHA512=lib/sha512.o
endif

.PHONY: all library static-library dynamic-library \
        install install-doc                        \
        check test speed                           \
        clean uninstall                            \
        tarball

all    : library
install: library src/monocypher.h install-doc
	mkdir -p $(DESTDIR)/$(PREFIX)/include
	mkdir -p $(DESTDIR)/$(PREFIX)/lib
	mkdir -p $(PKGCONFIG)
	cp -P lib/libmonocypher.a lib/libmonocypher.so* $(DESTDIR)/$(PREFIX)/lib
	cp src/monocypher.h $(DESTDIR)/$(PREFIX)/include
	@echo "Creating $(PKGCONFIG)/monocypher.pc"
	@echo "prefix=/$(PREFIX)"                > $(PKGCONFIG)/monocypher.pc
	@echo 'exec_prefix=$${prefix}'          >> $(PKGCONFIG)/monocypher.pc
	@echo 'libdir=$${exec_prefix}/lib'      >> $(PKGCONFIG)/monocypher.pc
	@echo 'includedir=$${prefix}/include'   >> $(PKGCONFIG)/monocypher.pc
	@echo ''                                >> $(PKGCONFIG)/monocypher.pc
	@echo 'Name: monocypher'                >> $(PKGCONFIG)/monocypher.pc
	@echo 'Version:' $$(cat VERSION.md)     >> $(PKGCONFIG)/monocypher.pc
	@echo 'Description: Easy to use, easy to deploy crypto library' \
                                                >> $(PKGCONFIG)/monocypher.pc
	@echo ''                                >> $(PKGCONFIG)/monocypher.pc
	@echo 'Libs: -L$${libdir} -lmonocypher' >> $(PKGCONFIG)/monocypher.pc
	@echo 'Cflags: -I$${includedir}'        >> $(PKGCONFIG)/monocypher.pc

install-doc:
	mkdir -p $(MAN_DIR)
	cp -r doc/man/man3/*.3monocypher $(MAN_DIR)

library: static-library dynamic-library
static-library : lib/libmonocypher.a
dynamic-library: lib/libmonocypher.so lib/libmonocypher.so.2

clean:
	rm -rf lib/
	rm -f  *.out

uninstall:
	rm -f $(DESTDIR)/$(PREFIX)/lib/libmonocypher.a
	rm -f $(DESTDIR)/$(PREFIX)/lib/libmonocypher.so*
	rm -f $(DESTDIR)/$(PREFIX)/include/monocypher.h
	rm -f $(PKGCONFIG)/monocypher.pc
	rm -f $(MAN_DIR)/*.3monocypher

check: test
test           : test.out
speed          : speed.out
speed-sodium   : speed-sodium.out
speed-tweetnacl: speed-tweetnacl.out
test speed speed-sodium speed-tweetnacl:
	./$<

# Monocypher libraries
lib/libmonocypher.a: lib/monocypher.o $(LINK_SHA512)
	ar cr $@ $^
lib/libmonocypher.so: lib/libmonocypher.so.2
	@mkdir -p $(@D)
	ln -s $$(basename $<) $@
lib/libmonocypher.so.2: lib/monocypher.o $(LINK_SHA512)
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -shared -o $@ $^
lib/sha512.o    : src/optional/sha512.c src/optional/sha512.h
lib/monocypher.o: src/monocypher.c src/monocypher.h
lib/monocypher.o lib/sha512.o:
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -I src -I src/optional -fPIC -c -o $@ $<

# Test & speed libraries
$TEST_COMMON=tests/utils.h src/monocypher.h src/optional/sha512.h
lib/test.o           : tests/test.c            $(TEST_COMMON) tests/vectors.h
lib/speed.o          : tests/speed.c           $(TEST_COMMON) tests/speed.h
lib/speed-sodium.o   : tests/speed-sodium.c    $(TEST_COMMON) tests/speed.h
lib/speed-tweetnacl.o: tests/speed-tweetnacl.c $(TEST_COMMON) tests/speed.h
lib/utils.o lib/test.o lib/speed.o lib/speed-sodium.o lib/speed-tweetnacl.o:
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -I src -I src/optional -fPIC -c -o $@ $<

# test & speed executables
test.out : lib/test.o  lib/monocypher.o lib/sha512.o
speed.out: lib/speed.o lib/monocypher.o lib/sha512.o
test.out speed.out:
	$(CC) $(CFLAGS) -I src -I src/optional -o $@ $^
speed-sodium.out: lib/speed-sodium.o
	$(CC) $(CFLAGS) -o $@ $^              \
            $$(pkg-config --cflags libsodium) \
            $$(pkg-config --libs   libsodium)
lib/tweetnacl.o: tests/tweetnacl.c tests/tweetnacl.h
	$(CC) $(CFLAGS) -c -o $@ $<
speed-tweetnacl.out: lib/speed-tweetnacl.o lib/tweetnacl.o
	$(CC) $(CFLAGS) -o $@ $^

tests/vectors.h:
	@echo ""
	@echo "======================================================"
	@echo " I cannot perform the tests without the test vectors."
	@echo " You must generate them.  This requires Libsodium."
	@echo " The following will generate the test vectors:"
	@echo ""
	@echo "     $ cd tests/gen"
	@echo "     $ make"
	@echo ""
	@echo " Alternatively, you can grab an official release."
	@echo " It will include the test vectors, so you won't"
	@echo " need libsodium."
	@echo "======================================================"
	@echo ""
	return 1

tarball: tests/vectors.h
	doc/man2html.sh
	touch     $(TARBALL_DIR)/monocypher-$(TARBALL_VERSION).tar.gz
	tar -czvf $(TARBALL_DIR)/monocypher-$(TARBALL_VERSION).tar.gz \
            -X tarball_ignore                                         \
            --transform='flags=r;s|^.|monocypher-'$(TARBALL_VERSION)'|' .
