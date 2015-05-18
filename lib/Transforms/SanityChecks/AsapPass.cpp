// This file is part of ASAP.
// Please see LICENSE.txt for copyright and licensing information.

#include "AsapPass.h"
#include "SanityCheckCostPass.h"
#include "SanityCheckInstructionsPass.h"
#include "utils.h"

#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/DebugInfo.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/Format.h"
#include "llvm/Support/raw_ostream.h"
#define DEBUG_TYPE "asap"

using namespace llvm;

static cl::opt<double>
SanityLevel("sanity-level", cl::desc("Fraction of static checks to be preserved"), cl::init(-1.0));

static cl::opt<double>
CostLevel("cost-level", cl::desc("Fraction of dynamic checks to be preserved"), cl::init(-1.0));

static cl::opt<unsigned long long>
CostThreshold("asap-cost-threshold",
        cl::desc("Remove checks costing this or more"),
        cl::init((unsigned long long)(-1)));

static cl::opt<bool>
PrintRemovedChecks("print-removed-checks",
        cl::desc("Should a list of removed checks be printed?"),
        cl::init(false));


bool AsapPass::runOnModule(Module &M) {
    SCC = &getAnalysis<SanityCheckCostPass>();
    SCI = &getAnalysis<SanityCheckInstructionsPass>();

    // Check whether we got the right amount of parameters
    int nParams = 0;
    if (SanityLevel >= 0.0) nParams += 1;
    if (CostLevel >= 0.0) nParams += 1;
    if (CostThreshold != (unsigned long long)(-1)) nParams += 1;
    if (nParams != 1) {
        report_fatal_error("Please specify exactly one of -cost-level, "
                           "-sanity-level or -asap-cost-threshold");
    }

    size_t TotalChecks = SCC->getCheckCosts().size();
    if (TotalChecks == 0) {
        dbgs() << "Removed 0 out of 0 static checks (nan%)\n";
        dbgs() << "Removed 0 out of 0 dynamic checks (nan%)\n";
        return false;
    }

    uint64_t TotalCost = 0;
    for (const SanityCheckCostPass::CheckCost &I : SCC->getCheckCosts()) {
        TotalCost += I.second;
    }

    // Start removing checks. They are given in order of decreasing cost, so we
    // simply remove the first few.
    uint64_t RemovedCost = 0;
    size_t NChecksRemoved = 0;
    for (const SanityCheckCostPass::CheckCost &I : SCC->getCheckCosts()) {
        
        if (SanityLevel >= 0.0) {
            if ((NChecksRemoved + 1) > TotalChecks * (1.0 - SanityLevel)) {
                break;
            }
        } else if (CostLevel >= 0.0) {
            // Make sure we get the boundary conditions right... it's important
            // that at cost level 0.0, we don't remove checks that cost zero.
            if (RemovedCost >= TotalCost * (1.0 - CostLevel) ||
                    (RemovedCost + I.second) > TotalCost * (1.0 - CostLevel)) {
                break;
            }
        } else if (CostThreshold != (unsigned long long)(-1)) {
            if (I.second < CostThreshold) {
                break;
            }
        }
        
        if (optimizeCheckAway(I.first)) {
            RemovedCost += I.second;
            NChecksRemoved += 1;
        }
    }
    
    dbgs() << "Removed " << NChecksRemoved << " out of " << TotalChecks
           << " static checks (" << format("%0.2f", (100.0 * NChecksRemoved / TotalChecks)) << "%)\n";
    dbgs() << "Removed " << RemovedCost << " out of " << TotalCost
           << " dynamic checks (" << format("%0.2f", (100.0 * RemovedCost / TotalCost)) << "%)\n";
    return false;
}

void AsapPass::getAnalysisUsage(AnalysisUsage& AU) const {
    AU.addRequired<SanityCheckCostPass>();
    AU.addRequired<SanityCheckInstructionsPass>();
}

// Tries to remove a sanity check; returns true if it worked.
bool AsapPass::optimizeCheckAway(llvm::Instruction *Inst) {
    BranchInst *BI = cast<BranchInst>(Inst);
    assert(BI->isConditional() && "Sanity check must be conditional branch.");
    
    unsigned int RegularBranch = getRegularBranch(BI, SCI);
    
    bool Changed = false;
    if (RegularBranch == 0) {
        BI->setCondition(ConstantInt::getTrue(Inst->getContext()));
        Changed = true;
    } else if (RegularBranch == 1) {
        BI->setCondition(ConstantInt::getFalse(Inst->getContext()));
        Changed = true;
    } else {
        // This can happen, e.g., in the following case:
        //     array[-1] = a + b;
        // is transformed into
        //     if (a + b overflows)
        //         report_overflow()
        //     else
        //         report_index_out_of_bounds();
        // In this case, removing the sanity check does not help much, so we
        // just do nothing.
        // Thanks to Will Dietz for his explanation at
        // http://lists.cs.uiuc.edu/pipermail/llvmdev/2014-April/071958.html
        dbgs() << "Warning: Sanity check with no regular branch found.\n";
        dbgs() << "The sanity check has been kept intact.\n";
    }
    
    if (PrintRemovedChecks && Changed) {
        DebugLoc DL = getSanityCheckDebugLoc(BI, RegularBranch);
        printDebugLoc(DL, BI->getContext(), dbgs());
        dbgs() << ": SanityCheck with cost ";
        dbgs() << *BI->getMetadata("cost")->getOperand(0);

        if (MDNode *IA = DL.getInlinedAt()) {
            dbgs() << " (inlined at ";
            printDebugLoc(DebugLoc(IA), BI->getContext(), dbgs());
            dbgs() << ")";
        }

        BasicBlock *Succ = BI->getSuccessor(RegularBranch == 0 ? 1 : 0);
        if (const CallInst *CI = SCI->findSanityCheckCall(Succ)) {
            dbgs() << " " << CI->getCalledFunction()->getName();
        }
        dbgs() << "\n";
    }

    return Changed;
}

char AsapPass::ID = 0;
static RegisterPass<AsapPass> X("asap",
        "Removes too costly sanity checks", false, false);
