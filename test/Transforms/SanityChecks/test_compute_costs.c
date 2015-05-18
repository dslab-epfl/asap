// Tests whether costs are computed correctly

// RUN: rm -rf %t %t.*

// Initial build
// RUN: ASAP_STATE_PATH=%t.state asap-clang -asap-init
// RUN: ASAP_STATE_PATH=%t.state asap-clang -Wall -g -O1 -fsanitize=address -c -o %t.foo.o %s
// RUN: ASAP_STATE_PATH=%t.state asap-clang -Wall -g -O1 -fsanitize=address -c -o %t.main.o -DCOMPILE_MAIN %s
// RUN: ASAP_STATE_PATH=%t.state asap-clang -Wall -g -O1 -fsanitize=address -o %t %t.foo.o %t.main.o

// Coverage build
// RUN: ASAP_STATE_PATH=%t.state asap-clang -asap-coverage
// RUN: ASAP_STATE_PATH=%t.state asap-clang -Wall -g -O1 -fsanitize=address -c -o %t.foo.o %s
// RUN: ASAP_STATE_PATH=%t.state asap-clang -Wall -g -O1 -fsanitize=address -c -o %t.main.o -DCOMPILE_MAIN %s
// RUN: ASAP_STATE_PATH=%t.state asap-clang -Wall -g -O1 -fsanitize=address -o %t %t.foo.o %t.main.o

// RUN: %t
// RUN: ASAP_STATE_PATH=%t.state asap-clang -asap-compute-costs

// RUN: FileCheck %s < %t.state/costs/*.foo.costs

#ifndef COMPILE_MAIN

int foo(int *a, int n) {
    int sum = 0;
    for (int i = 0; i < n; ++i) {
        // Verify that there is a sanity check two lines down, with cost 50.
        // CHECK: 50 {{.*}}:29
        sum += a[i];
    }
    return sum;
}

#else

int foo(int *a, int n);
int a[] = {1, 4, 9, 16, 25, 36, 49, 64, 81, 100};

int main() {
    if (foo(a, 10) == 385) {
        return 0;
    } else {
        return 1;
    }
}

#endif
