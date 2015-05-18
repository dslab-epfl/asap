#include <stdio.h>
#include <assert.h>

int main() {
    const int MAX_SIZE = 100;
    int a[MAX_SIZE];

    for (int i = 0; i < MAX_SIZE; ++i) {
        a[i] = i * i + 4;
    }

    int n_numbers;
    printf("How many numbers should I sum up? ");
    scanf("%d", &n_numbers);

    int sum = 0;
    for (int i = 0; i < n_numbers; ++i) {
        sum += a[i];
    }

    assert(sum >= 0);
    printf("The sum is: %d\n", sum);
    return 0;
}
