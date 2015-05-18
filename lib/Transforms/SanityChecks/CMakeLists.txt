# This file is part of ASAP.
# Please see LICENSE.txt for copyright and licensing information.

add_llvm_loadable_module(SanityChecks
  AsapPass.cpp
  CostModel.cpp
  ExitInsteadOfAbortPass.cpp
  GCOV.cpp
  SanityCheckCostPass.cpp
  SanityCheckInstructionsPass.cpp
  utils.cpp
)

add_dependencies(SanityChecks LLVMInstrumentation)

# Create symlinks for asap-clang.rb
add_custom_command(OUTPUT ${CMAKE_BINARY_DIR}/bin/asap-clang
  COMMAND cd ${CMAKE_BINARY_DIR}/bin && ln -s ${CMAKE_CURRENT_SOURCE_DIR}/asap-clang.rb asap-clang
  COMMENT Creating symlink for asap-clang
  VERBATIM)
add_custom_command(OUTPUT ${CMAKE_BINARY_DIR}/bin/asap-clang++
  COMMAND cd ${CMAKE_BINARY_DIR}/bin && ln -s ${CMAKE_CURRENT_SOURCE_DIR}/asap-clang.rb asap-clang++
  COMMENT Creating symlink for asap-clang++
  VERBATIM)
add_custom_command(OUTPUT ${CMAKE_BINARY_DIR}/bin/asap-ranlib
  COMMAND cd ${CMAKE_BINARY_DIR}/bin && ln -s ${CMAKE_CURRENT_SOURCE_DIR}/asap-clang.rb asap-ranlib
  COMMENT Creating symlink for asap-ranlib
  VERBATIM)
add_custom_command(OUTPUT ${CMAKE_BINARY_DIR}/bin/asap-ar
  COMMAND cd ${CMAKE_BINARY_DIR}/bin && ln -s ${CMAKE_CURRENT_SOURCE_DIR}/asap-clang.rb asap-ar
  COMMENT Creating symlink for asap-ar
  VERBATIM)
add_custom_target(asap_clang_symlinks
  ALL
  DEPENDS ${CMAKE_BINARY_DIR}/bin/asap-clang
          ${CMAKE_BINARY_DIR}/bin/asap-clang++
          ${CMAKE_BINARY_DIR}/bin/asap-ranlib
          ${CMAKE_BINARY_DIR}/bin/asap-ar)
