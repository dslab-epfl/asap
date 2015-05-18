// RUN: rm -rf %t %t.*

// Initial build
// RUN: ASAP_STATE_PATH=%t.state asap-clang -asap-init
// RUN: ASAP_STATE_PATH=%t.state asap-clang -Wall -O1 -fsanitize=address -c -o %t.o  %s
// RUN: ASAP_STATE_PATH=%t.state asap-clang -Wall -O1 -fsanitize=address -o %t %t.o

// Coverage build
// RUN: ASAP_STATE_PATH=%t.state asap-clang -asap-coverage
// RUN: ASAP_STATE_PATH=%t.state asap-clang -Wall -O1 -fsanitize=address -c -o %t.o  %s
// RUN: ASAP_STATE_PATH=%t.state asap-clang -Wall -O1 -fsanitize=address -o %t %t.o

// RUN: echo 10 | %t
// RUN: ASAP_STATE_PATH=%t.state asap-clang -asap-compute-costs

// RUN: FileCheck %s < %t.state/costs/*.costs

#include <stdio.h>

int main () {
    int a[10] = {1, 4, 9, 16, 25, 36, 49, 64, 81, 100};
    int sum = 0;
    int n_numbers;
    printf("How many numbers to sum up?\n");
    scanf("%d", &n_numbers);
    for (int i = 0; i < n_numbers; ++i) {
        // Two lines down, there should be a sanity check with cost 50.
        // CHECK: 50 {{.*}}test_compute_costs2.c:29
        sum += a[i];
    }
    printf("\n%d", sum);
    return 0;
}
