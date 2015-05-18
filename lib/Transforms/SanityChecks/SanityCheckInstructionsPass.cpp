// This file is part of ASAP.
// Please see LICENSE.txt for copyright and licensing information.

#include "SanityCheckInstructionsPass.h"
#include "utils.h"

#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/Pass.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Metadata.h"
#include "llvm/IR/CFG.h"
#include "llvm/Support/Debug.h"
#include "llvm/IR/Module.h"
#define DEBUG_TYPE "sanity-check-instructions"

using namespace llvm;

bool SanityCheckInstructionsPass::runOnModule(Module &M) {
    for (Function &F: M) {
        DEBUG(dbgs() << "SanityCheckInstructionsPass on " << F.getName() << "\n");
        SanityCheckBlocks[&F] = BlockSet();
        SanityCheckInstructions[&F] = InstructionSet();
        SanityCheckBranches[&F] = InstructionSet();
        findInstructions(&F);

        MDNode *MD = MDNode::get(M.getContext(), {});
        for (Instruction *Inst: SanityCheckInstructions[&F]) {
            Inst->setMetadata("sanitycheck", MD);
        }
    }
    
    return false;
}

void SanityCheckInstructionsPass::findInstructions(Function *F) {

    // A list of instructions that are used by sanity checks. They become sanity
    // check instructions if it turns out they're not used by anything else.
    SmallPtrSet<Instruction*, 128> Worklist;
    
    // A list of basic blocks that contain sanity check instructions. They
    // become sanity check blocks if it turns out they don't contain anything
    // else.
    SmallPtrSet<BasicBlock*, 64>   BlockWorklist;
    
    // A map from instructions to the checks that use them.
    std::map<Instruction*, SmallPtrSet<Instruction*, 4> > ChecksByInstruction;

    for (BasicBlock &BB: *F) {
        if (findSanityCheckCall(&BB)) {
            SanityCheckBlocks[F].insert(&BB);

            // All instructions inside sanity check blocks are sanity check instructions
            for (Instruction &I: BB) {
                Worklist.insert(&I);
            }

            // All branches to sanity check blocks are sanity check branches
            for (User *U: BB.users()) {
                if (Instruction *Inst = dyn_cast<Instruction>(U)) {
                    Worklist.insert(Inst);
                }
                BranchInst *BI = dyn_cast<BranchInst>(U);
                if (BI && BI->isConditional()) {
                    SanityCheckBranches[F].insert(BI);
                    ChecksByInstruction[BI].insert(BI);
                }
            }
        }
    }

    while (!Worklist.empty()) {
        // Alternate between emptying the worklist...
        while (!Worklist.empty()) {
            Instruction *Inst = *Worklist.begin();
            Worklist.erase(Inst);
            if (onlyUsedInSanityChecks(Inst)) {
                if (SanityCheckInstructions[F].insert(Inst).second) {
                    for (Use &U: Inst->operands()) {
                        if (Instruction *Op = dyn_cast<Instruction>(U.get())) {
                            Worklist.insert(Op);
                            
                            // Copy ChecksByInstruction from Inst to Op
                            auto CBI = ChecksByInstruction.find(Inst);
                            if (CBI != ChecksByInstruction.end()) {
                                ChecksByInstruction[Op].insert(CBI->second.begin(), CBI->second.end());
                            }
                        }
                    }

                    BlockWorklist.insert(Inst->getParent());

                    // Fill InstructionsBySanityCheck from the inverse ChecksByInstruction
                    auto CBI = ChecksByInstruction.find(Inst);
                    if (CBI != ChecksByInstruction.end()) {
                        for (Instruction *CI : CBI->second) {
                            InstructionsBySanityCheck[CI].insert(Inst);
                        }
                    }
                }
            }
        }

        // ... and checking whether this causes basic blocks to contain only
        // sanity checks. This would in turn cause terminators to be added to
        // the worklist.
        while (!BlockWorklist.empty()) {
            BasicBlock *BB = *BlockWorklist.begin();
            BlockWorklist.erase(BB);
            
            bool allInstructionsAreSanityChecks = true;
            for (Instruction &I: *BB) {
                if (!SanityCheckInstructions.at(BB->getParent()).count(&I)) {
                    allInstructionsAreSanityChecks = false;
                    break;
                }
            }
            
            if (allInstructionsAreSanityChecks) {
                for (User *U: BB->users()) {
                    if (Instruction *Inst = dyn_cast<Instruction>(U)) {
                        Worklist.insert(Inst);
                    }
                }
            }
        }
    }
}

const CallInst *SanityCheckInstructionsPass::findSanityCheckCall(BasicBlock* BB) const {
    for (const Instruction &I: *BB) {
        if (const CallInst *CI = dyn_cast<CallInst>(&I)) {
            if (isAbortingCall(CI)) {
                return CI;
            }
        }
    }
    return 0;
}

bool SanityCheckInstructionsPass::onlyUsedInSanityChecks(Value* V) {
    for (User *U: V->users()) {
        Instruction *Inst = dyn_cast<Instruction>(U);
        if (!Inst) return false;
        
        Function *F = Inst->getParent()->getParent();
        if (!(SanityCheckInstructions[F].count(Inst))) {
            return false;
        }
    }
    return true;
}

char SanityCheckInstructionsPass::ID = 0;

static RegisterPass<SanityCheckInstructionsPass> X("sanity-check-instructions",
        "Finds instructions belonging to sanity checks", false, false);
