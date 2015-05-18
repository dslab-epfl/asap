// This file is part of ASAP.
// Please see LICENSE.txt for copyright and licensing information.

#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/Pass.h"

#include <map>

namespace llvm {
    class AnalysisUsage;
    class BasicBlock;
    class CallInst;
    class Function;
    class Instruction;
    class Value;
}

struct SanityCheckInstructionsPass : public llvm::ModulePass {
    static char ID;

    SanityCheckInstructionsPass() : ModulePass(ID) {}

    virtual bool runOnModule(llvm::Module &M);

    virtual void getAnalysisUsage(llvm::AnalysisUsage& AU) const {
        AU.setPreservesAll();
    }

    // Types used to store sanity check blocks / instructions
    typedef llvm::SmallPtrSet<llvm::BasicBlock*, 64> BlockSet;
    typedef llvm::SmallPtrSet<llvm::Instruction*, 64> InstructionSet;

    const InstructionSet &getSanityCheckBranches(llvm::Function *F) const {
        return SanityCheckBranches.at(F);
    }
    
    const BlockSet &getSanityCheckBlocks(llvm::Function *F) const {
        return SanityCheckBlocks.at(F);
    }
    
    const InstructionSet &getInstructionsBySanityCheck(llvm::Instruction *Inst) const {
        return InstructionsBySanityCheck.at(Inst);
    }

    // Searches the given basic block for a call instruction that corresponds to
    // a sanity check and will abort the program (e.g., __assert_fail).
    const llvm::CallInst *findSanityCheckCall(llvm::BasicBlock *BB) const;
    
private:

    // All blocks that abort due to sanity checks
    std::map<llvm::Function*, BlockSet> SanityCheckBlocks;

    // All instructions that belong to sanity checks
    std::map<llvm::Function*, InstructionSet> SanityCheckInstructions;
    
    // All sanity checks themselves (branch instructions that could lead to an abort)
    std::map<llvm::Function*, InstructionSet> SanityCheckBranches;
    
    // A map of all instructions required by a given sanity check branch.
    // Note that instructions can belong to multiple sanity check branches.
    std::map<llvm::Instruction*, InstructionSet> InstructionsBySanityCheck;

    void findInstructions(llvm::Function *F);
    bool onlyUsedInSanityChecks(llvm::Value *V);
};
