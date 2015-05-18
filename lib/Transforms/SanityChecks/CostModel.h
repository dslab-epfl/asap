// This file is part of ASAP.
// Please see LICENSE.txt for copyright and licensing information.

#include "llvm/Pass.h"

namespace llvm {
    class Function;
    class Instruction;
    class Module;
    class raw_ostream;
    class TargetTransformInfo;
}

namespace sanitychecks {
    class CostModelAnalysis : public llvm::ImmutablePass {
    public:
        static char ID; // Class identification, replacement for typeinfo

        CostModelAnalysis() : ImmutablePass(ID), TTI(nullptr) {}

        /// Returns the expected cost of the instruction.
        /// Returns -1 if the cost is unknown.
        /// Note, this method does not cache the cost calculation and it
        /// can be expensive in some cases.
        unsigned getInstructionCost(const llvm::Instruction *I) const;

        virtual void initializePass();
        virtual void getAnalysisUsage(llvm::AnalysisUsage &AU) const;

    private:

        /// Target information.
        const llvm::TargetTransformInfo *TTI;
    };
}  // namespace sanitychecks
