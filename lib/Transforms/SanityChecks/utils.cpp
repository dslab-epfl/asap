// Various utility functions

// This file is part of ASAP.
// Please see LICENSE.txt for copyright and licensing information.

#include "utils.h"
#include "SanityCheckInstructionsPass.h"

#include "llvm/IR/DebugInfo.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/raw_ostream.h"
using namespace llvm;

static cl::opt<bool>
OptimizeSanityChecks("asap-optimize-sanitychecks",
        cl::desc("Should ASAP affect sanity checks (e.g., from ASan)?"),
        cl::init(true));

static cl::opt<bool>
OptimizeAssertions("asap-optimize-assertions",
        cl::desc("Should ASAP affect programmer-written assertions?"),
        cl::init(true));

// Returns true if a given instruction is a call to an aborting, error reporting
// function
bool isAbortingCall(const CallInst *CI) {
    if (CI->getCalledFunction()) {
        StringRef name = CI->getCalledFunction()->getName();
        if (name.startswith("__ubsan_") && name.endswith("_abort")) {
            return OptimizeSanityChecks;
        }
        if (name.startswith("__softboundcets_") && name.endswith("_abort")) {
            return OptimizeSanityChecks;
        }
        if (name.startswith("__asan_report_")) {
            return OptimizeSanityChecks;
        }
        if (name == "__assert_fail" || name == "__assert_rtn") {
            return OptimizeAssertions;
        }
    }
    return false;
}

unsigned int getRegularBranch(BranchInst *BI, SanityCheckInstructionsPass *SCI) {
    unsigned int RegularBranch = (unsigned)(-1);
    Function *F = BI->getParent()->getParent();
    for (unsigned int I = 0, E = BI->getNumSuccessors(); I != E; ++I) {
        if (!SCI->getSanityCheckBlocks(F).count(BI->getSuccessor(I))) {
            assert(RegularBranch == (unsigned)(-1) && "More than one regular branch?");
            RegularBranch = I;
        }
    }
    return RegularBranch;
}

llvm::DebugLoc getSanityCheckDebugLoc(BranchInst *BI, unsigned int RegularBranch) {
    DebugLoc DL = BI->getDebugLoc();
    if (!DL && RegularBranch != (unsigned int)(-1)) {
        // If the branch instruction itself does not have a debug location,
        // we take the location of the first instruction in the regular
        // branch. This will most likely be the original instruction that
        // was protected with a sanity check.
        BasicBlock *Succ = BI->getSuccessor(RegularBranch);
        for (auto SI = Succ->begin(), SE = Succ->end();
                SI != SE && !DL; ++SI) {
            DL = SI->getDebugLoc();
        }
    }
    return DL;
}

void printDebugLoc(const DebugLoc& DbgLoc,
        LLVMContext &Ctx, raw_ostream &Outs) {
    if (!DbgLoc) {
        Outs << "<debug info not available>";
        return;
    }

    DILocation *DL = dyn_cast_or_null<DILocation>(DbgLoc.getAsMDNode());
    if (!DL) {
        Outs << "<debug info not available>";
        return;
    }

    StringRef Filename = DL->getFilename();
    Outs << Filename << ':' << DL->getLine();

    if (DL->getColumn() != 0) {
        Outs << ':' << DL->getColumn();
    }
}
