// This file is part of ASAP.
// Please see LICENSE.txt for copyright and licensing information.

#include "llvm/Pass.h"

namespace sanitychecks {
    class GCOVFile;
}

namespace llvm {
    class Instruction;
}

struct SanityCheckCostPass;
struct SanityCheckInstructionsPass;

struct AsapPass : public llvm::ModulePass {
    static char ID;

    AsapPass() : ModulePass(ID), SCC(0), SCI(0) {}

    virtual bool runOnModule(llvm::Module &M);

    virtual void getAnalysisUsage(llvm::AnalysisUsage& AU) const;

private:

    SanityCheckCostPass *SCC;
    SanityCheckInstructionsPass *SCI;
    
    // Tries to remove a sanity check; returns true if it worked.
    bool optimizeCheckAway(llvm::Instruction *Inst);
};
