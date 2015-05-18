// This file is part of ASAP.
// Please see LICENSE.txt for copyright and licensing information.

#include "llvm/Pass.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/InstIterator.h"
#include "utils.h"
#include <vector>

using namespace llvm;

namespace {

    // This pass can be useful when we depend on atexit() functions to be
    // called. This happens, for instance, when we would like profiling counters
    // to be written out even if the program is aborted.
    struct ExitInsteadOfAbortPass : public FunctionPass {
        static char ID;

        ExitInsteadOfAbortPass() : FunctionPass(ID) {}

        virtual bool runOnFunction(Function &F) {
            // Setup functions and exit values
            Module *M = F.getParent();
            LLVMContext &Ctx = M->getContext();
            Constant *ExitFunction = M->getOrInsertFunction("exit",
                    Type::getVoidTy(Ctx),
                    Type::getInt32Ty(Ctx),
                    NULL);
            // I think 27 is a great return value :-)
            Constant *ExitValue = ConstantInt::get(Type::getInt32Ty(Ctx), 27);

            std::vector<CallInst *> CallsToReplace;
            for (inst_iterator I = inst_begin(F), E = inst_end(F); I != E; ++I) {
                Instruction *Inst = &*I;
                if (CallInst *CI = dyn_cast<CallInst>(Inst)) {
                    if (isAbortingCall(CI)) {
                        CallsToReplace.push_back(CI);
                    }
                }
            }
            IRBuilder<> Builder(Ctx);
            for (Instruction *Inst : CallsToReplace) {
                Builder.SetInsertPoint(Inst);
                Builder.SetCurrentDebugLocation(Inst->getDebugLoc());
                Builder.CreateCall(ExitFunction, ExitValue);
                Inst->eraseFromParent();
            }

            return false;
        }
    };
}

char ExitInsteadOfAbortPass::ID = 0;
static RegisterPass<ExitInsteadOfAbortPass> X("exit-instead-of-abort", "Transforms calls to abort and similar functions into clean exits", false, false);
