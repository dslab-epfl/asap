// This file is part of ASAP.
// Please see LICENSE.txt for copyright and licensing information.

#ifndef SANITYCHECKS_UTILS_H
#define	SANITYCHECKS_UTILS_H

#include "llvm/IR/DebugLoc.h"

namespace llvm {
    class BranchInst;
    class CallInst;
    class LLVMContext;
    class raw_ostream;
}

struct SanityCheckInstructionsPass;

// Returns true if a given instruction is a call to an aborting, error reporting
// function
bool isAbortingCall(const llvm::CallInst *CI);

// Returns the index of the regular branch of a sanity check, i.e., the branch
// that continues program execution. Returns (unsigned) -1 if such a branch does
// not exist.
unsigned int getRegularBranch(llvm::BranchInst *BI,
        SanityCheckInstructionsPass *SCI);

// Returns the debug location of a sanity check.
llvm::DebugLoc getSanityCheckDebugLoc(llvm::BranchInst *BI,
        unsigned int RegularBranch);

void printDebugLoc(const llvm::DebugLoc& DbgLoc, llvm::LLVMContext &Ctx,
        llvm::raw_ostream &Outs);

#endif	/* SANITYCHECKS_UTILS_H */

