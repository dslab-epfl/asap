// Tests whether ASAP can recognize sanity check instructions correctly.

// RUN: clang -Wall -c %s -flto -fsanitize=address -O1 -o %t.o
// RUN: opt -load $(llvm-config --libdir)/SanityChecks.* -sanity-check-instructions %t.o -o %t.sanitychecks.ll -S
// RUN: FileCheck %s < %t.sanitychecks.ll

int foo(int *a) {
    // It should recognize code that ASan inserted to load metadata...
    // CHECK: ptrtoint i32* %a to i64, !sanitycheck

    // It should recognize the two branches (fast path and slow path) inserted
    // by ASan...
    // CHECK: br {{.*}}, !sanitycheck
    // CHECK: br {{.*}}, !sanitycheck

    // It should recognize the aborting call, too
    // CHECK: call void @__asan_report_load4{{.*}} !sanitycheck

    // On the other hand, the final load instruction should not be recognized as check
    // CHECK-NOT: load i32* %a{{.*}} !sanitycheck
    return a[0];
}
