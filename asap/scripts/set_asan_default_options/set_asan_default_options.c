// A file that, when linked into a program, will cause a default ASAN_OPTIONS
// string to be set.

#ifndef ASAN_DEFAULT_OPTIONS
#error "Please define ASAN_DEFAULT_OPTIONS when compiling this file"
#endif

#define STRINGIFY_MACRO(s) STRINGIFY(s)
#define STRINGIFY(s) #s

const char* __asan_default_options() {
    return STRINGIFY_MACRO(ASAN_DEFAULT_OPTIONS);
}
