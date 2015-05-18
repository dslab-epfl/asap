// This file is part of ASAP.
// Please see LICENSE.txt for copyright and licensing information.

#include "llvm/Pass.h"

#include <utility>
#include <vector>

namespace sanitychecks {
    class GCOVFile;
}

namespace llvm {
    class BranchInst;
    class raw_ostream;
}

struct SanityCheckCostPass : public llvm::ModulePass {
    static char ID;

    SanityCheckCostPass() : ModulePass(ID) {}

    virtual bool runOnModule(llvm::Module &M);

    virtual void getAnalysisUsage(llvm::AnalysisUsage& AU) const;
    
    virtual void print(llvm::raw_ostream &O, const llvm::Module *M) const;

    // A pair that stores a sanity check and its cost.
    typedef std::pair<llvm::BranchInst *, uint64_t> CheckCost;
    
    const std::vector<CheckCost> &getCheckCosts() const {
        return CheckCosts;
    };

private:

    std::vector<CheckCost> CheckCosts;
    
    sanitychecks::GCOVFile *createGCOVFile();
};
