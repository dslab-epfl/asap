#!/usr/bin/env ruby

# This is a wrapper script around clang, ar, ranlib, etc., to perform the
# different ASAP compilation steps:
#
# - First step: -asap-init
#   Creates the ASAP state directory, which contains all the additional files
#   that ASAP manages throughout a compilation.
#   After asap-init, the software is ready to be compiled.
# - Second step: -asap-coverage
#   Prepares the compilation with coverage instrumentation. After this step,
#   the software should be compiled again, and the resulting binary will be
#   instrumented for coverage.
# - Third step: -asap-compute-costs
#   Collects sanity checks and computes their costs
# - Fourth step: -asap-optimize
#   Prepares for optimized compilation. Running make/ninja again after this
#   should result in an optimized binary.

# This file is part of ASAP.
# Please see LICENSE.txt for copyright and licensing information.

require 'fileutils'
require 'parallel'
require 'pathname'

require_relative 'asap-clang-utils.rb'

# This class keeps track of the state of the ASAP compilation. It maintains the
# current state, compilation output files, ...
class AsapState
  attr_reader :state_path

  def initialize()
    @state_path = ENV['ASAP_STATE_PATH']
    raise "Please set ASAP_STATE_PATH" unless state_path
    raise "ASAP_STATE_PATH should be absolute" unless state_path == File.expand_path(state_path)
    raise "ASAP_STATE_PATH must be an existing folder" unless File.directory?(state_path)
  end

  def self.initialize_state()
    ENV['ASAP_STATE_PATH'] ||= File.realdirpath('asap_state')

    if File.exist?(ENV['ASAP_STATE_PATH'])
      $stderr.puts "Warning: removing old state folder #{ENV['ASAP_STATE_PATH']}" if $VERBOSE
      FileUtils.rm_r(ENV['ASAP_STATE_PATH'])
    end

    FileUtils.mkdir_p(ENV['ASAP_STATE_PATH'])

    state = self.new
    state.current_state = :initial
    puts "# Initialized ASAP state in #{state.state_path}. Now run:"
    puts "export ASAP_STATE_PATH=\"#{state.state_path}\""
  end

  # Create methods that compute paths to state subfolders
  [:coverage, :objects, :costs, :log].each do |dir|
    define_method "#{dir}_path".to_sym do |target|
      target_path = File.expand_path(target)
      target_rel = remove_shared_path_components(target_path, state_path)
      File.join(state_path, dir.to_s, target_rel)
    end

    define_method "#{dir}_directory".to_sym do
      File.join(state_path, dir.to_s)
    end
  end

  # Given two paths, returns the first path with all shared folders removed.
  # For example, /foo/bar/baz, /foo/quu => bar/baz
  #              /foo/bar/baz, /quu => foo/bar/baz
  def remove_shared_path_components(a, b)
    a_path = Pathname.new(a)
    b_path = Pathname.new(b)
    raise "Absolute path expected but #{a} given." unless a_path.absolute?
    raise "Absolute path expected but #{b} given." unless b_path.absolute?

    a_components = a_path.each_filename.to_a
    b_components = b_path.each_filename.to_a

    while a_components[0] == b_components[0]
      a_components.shift
      b_components.shift
    end
    File.join(a_components)
  end

  # Creates the right compiler for the given state
  def create_compiler()
    if current_state == :initial
      AsapInitialCompiler.new(self)
    elsif current_state == :coverage
      AsapProfilingCompiler.new(self)
    elsif current_state == :optimize
      AsapOptimizingCompiler.new(self)
    else
      raise "Unknown ASAP state: #{current_state}"
    end
  end

  def current_state()
    @current_state ||= IO.read(File.join(state_path, "current_state")).chomp.to_sym
  end

  def current_state=(state)
    @current_state = state
    IO.write(File.join(state_path, "current_state"), "#{state}\n")
  end

  def transition(from, to)
    raise "Expected ASAP state to be '#{from}', but it is '#{current_state}'" unless current_state == from
    yield
    self.current_state = to
  end
end


# This is a base class for executing compilation steps. The default behavior is
# to forward the commands to the original clang/ar/ranlib.
class BaseCompiler
  attr_reader :state

  def initialize(state)
    @state = state
  end

  def exec(cmd)
    command_type = get_command_type(cmd)
    if command_type == :compile
      do_compile(cmd)
    elsif command_type == :link
      do_link(cmd)
    elsif command_type == :ar
      do_ar(cmd)
    elsif command_type == :ranlib
      do_ranlib(cmd)
    else
      raise "invalid command: #{cmd}"
    end
  end

  def get_command_type(cmd)
    if cmd[0] =~ /(?:asap-|\/)clang(?:\+\+)?$/
        if get_arg(cmd, '-c', :first)
            return :compile
        else
            return :link
        end
    elsif cmd[0] =~ /(?:asap-|\/)ar$/
        return :ar
    elsif cmd[0] =~ /(?:asap-|\/)ranlib$/
        return :ranlib
    end
  end

  def do_compile(cmd)
    cmd = [find_clang()] + cmd[1..-1]
    run!(*cmd)
  end
  def do_link(cmd)
    cmd = [find_clang()] + cmd[1..-1]
    run!(*cmd)
  end
  def do_ar(cmd)
    cmd = [find_ar()] + cmd[1..-1]
    run!(*cmd)
  end
  def do_ranlib(cmd)
    cmd = [find_ar(), '-s'] + cmd[1..-1]
    run!(*cmd)
  end
end

# This is the compiler for ASAP's first stage. It ensures that crucial
# compilation flags are present.
class AsapInitialCompiler < BaseCompiler
  def do_compile(cmd)
    # For compilation, we try to obtain an instrumented bitcode file. If this
    # fails for whatever reason, we run the given command unmodified. This
    # means ASAP won't touch the target file again.

    clang = find_clang()

    target_name = get_arg(cmd, '-o')

    # Yet another special case :(
    # ASAP gets quite confused if the same file is used for different purposes
    # throughout a build. Yet, configure calls all its tests "conftest.c"...
    # just compile these normally.
    # TODO: at some point, we might want to store the ASAP state objects with
    # names that depend on the content of the source, rather than the object
    # name.
    return super if target_name =~ /conftest/

    if target_name and target_name.end_with?('.o')
      begin

        gcno_name = mangle(state.coverage_path(target_name), '.o', '.gcno')
        gcda_name = mangle(state.coverage_path(target_name), '.o', '.gcda')
        orig_name = mangle(state.objects_path(target_name), '.o', '.orig.o')
        FileUtils.mkdir_p(File.dirname(gcno_name))
        FileUtils.mkdir_p(File.dirname(orig_name))

        # Ensure that no target files exist. We had problems in the past with
        # stale gcda files, that were then updated incorrectly.
        FileUtils.rm_f([gcno_name, gcda_name, orig_name])

        clang_args = cmd[1..-1]
        clang_args = insert_arg(clang_args, '-gline-tables-only')
        clang_args = insert_arg(clang_args, '-flto')
        clang_args = ['-Xclang', '-femit-coverage-notes',
                      '-Xclang', "-coverage-file=#{gcno_name}"] + clang_args

        run!(clang, *clang_args)

        # If this lead to an instrumented bitcode file, copy it.
        # Also, run llc to generate a native object file instead of a bitcode file,
        # in order to avoid LTO linking which is just too slow.
        # We use the same optimization level for llc as for the original
        # compilation.
        if File.file?(gcno_name)
          FileUtils.mv(target_name, orig_name)
          opt_level = get_optlevel_for_llc(clang_args)
          run!(find_llc(), opt_level, '-filetype=obj', '-relocation-model=pic',
               '-o', target_name, orig_name)

          # If everthing so far worked, return happily
          return
        end
      rescue RunExternalCommandError
        # Nothing to do...
      end
    end

    # If we arrive here, some of the previous steps failed, so just run the
    # command normally.
    super
  end
end


# Compiler for ASAP's second stage. Adds profiling information to the program.
class AsapProfilingCompiler < BaseCompiler

  def do_compile(cmd)
    target_name = get_arg(cmd, '-o')
    return super unless target_name and target_name.end_with?('.o')

    # Check whether an .orig.o file exists. Otherwise, ASAP should not touch
    # the current target.
    orig_name = mangle(state.objects_path(target_name), '.o', '.orig.o')
    return super unless File.file?(orig_name)

    # Original file exists; create the target from there
    gcov_name = mangle(state.objects_path(target_name), '.o', '.gcov.o')
    opt_level = get_optlevel_for_llc(cmd)
    run!(find_opt(), '-insert-gcov-profiling',
              '-o', gcov_name,
              orig_name)
    run!(find_llc(), opt_level, '-filetype=obj', '-relocation-model=pic',
         '-o', target_name, gcov_name)
  end

  def do_link(cmd)
    linker_args = cmd[1..-1]
    linker_args = insert_arg(linker_args, '-coverage')

    super([cmd[0]] + linker_args)
  end
end


# Compiler for ASAP's fourth stage. Compiles an optimized program.
class AsapOptimizingCompiler < BaseCompiler
  def initialize(state)
    super
    threshold_file = IO.read(File.join(state.state_path, 'threshold'))
    raise "Threshold not defined" unless threshold_file =~ /^Cost threshold is (\d+)$/
    @cost_threshold = $1.to_i
  end

  def do_compile(cmd)
    target_name = get_arg(cmd, '-o')
    return super unless target_name and target_name.end_with?('.o')

    # Check whether we have both an .orig.o file and coverage data. Otherwise,
    # ASAP should not touch the current target.
    orig_name = mangle(state.objects_path(target_name), '.o', '.orig.o')
    gcda_name = mangle(state.coverage_path(target_name), '.o', '.gcda')
    gcno_name = mangle(state.coverage_path(target_name), '.o', '.gcno')
    return super unless [orig_name, gcda_name, gcno_name].all? { |f| File.file?(f) }

    # Original file exists; create the target from there
    asap_name = mangle(state.objects_path(target_name), '.o', '.asap.o')
    opt_name = mangle(state.objects_path(target_name), '.o', '.asap.opt.o')
    log_name  = mangle(state.log_path(target_name), '.o', '.asap.log')
    opt_level = get_optlevel_for_llc(cmd)
    FileUtils.mkdir_p(File.dirname(log_name))
    run!(find_opt(),
         '-load', find_asap_lib(),
         '-asap',
         '-print-removed-checks',
         "-asap-cost-threshold=#{@cost_threshold}",
         "-gcda=#{gcda_name}", "-gcno=#{gcno_name}",
         '-o', asap_name, orig_name,
         :out => log_name,
         :err => [:child, :out])
    run!(find_opt(),
         opt_level, '-o', opt_name, asap_name)
    run!(find_llc(), opt_level, '-filetype=obj', '-relocation-model=pic',
         '-o', target_name, opt_name)
  end
end


# Finds all sanity checks and computes their cost
def compute_costs(state)
  gcda_files = []
  Dir.chdir(state.coverage_directory) do |coverage_dir|
    gcda_files = Dir.glob('**/*.gcda')
  end

  Parallel.each(gcda_files) do |gcda_basename|
    gcda_name = File.join(state.coverage_directory, gcda_basename)
    gcno_name = mangle(File.join(state.coverage_directory, gcda_basename), '.gcda', '.gcno')
    orig_name = mangle(File.join(state.objects_directory, gcda_basename), '.gcda', '.orig.o')
    costs_name = mangle(File.join(state.costs_directory, gcda_basename), '.gcda', '.costs')

    FileUtils.mkdir_p(File.dirname(costs_name))

    run!(find_opt(),
         '-load', find_asap_lib(),
         '-analyze', '-sanity-check-cost',
         "-gcda=#{gcda_name}", "-gcno=#{gcno_name}", orig_name,
         :out => costs_name)
  end
end

# Obtains a cost threshold for the given sanity or cost level
def compute_cost_threshold(state, args)
  sanity_level = get_arg(args, '-asap-sanity-level=')
  cost_level = get_arg(args, '-asap-cost-level=')
  raise "specify -asap-cost-level or -asap-sanity-level" unless sanity_level or cost_level
  raise "specify -asap-cost-level or -asap-sanity-level" if sanity_level and cost_level

  # Read costs
  costs = []
  Dir.glob(File.join(state.costs_directory, '**', '*.costs')) do |cost_file|
    open(cost_file, 'r') do |f|
      f.each_line do |line|
        if line =~ /^\s*(\d+)\s/
          costs <<= $1.to_i
        end
      end
    end
  end
  raise "no costs found" if costs.empty?

  # Sort by decreasing cost
  costs.sort! { |a, b| b <=> a }
  total_cost = costs.reduce(:+)
  raise "all costs are zero" if total_cost == 0

  if sanity_level
    sanity_level = sanity_level.to_f
    cost_threshold = costs[0] + 1

    (0 ... costs.size).each do |i|
      next if costs[i+1] == costs[i]
      # costs.size - i - 1 is the number of checks that will be left in the
      # program, if we remove all those costing costs[i] or more.
      if costs.size - i - 1 >= costs.size * sanity_level
        cost_threshold = costs[i]
      end
    end

  elsif cost_level
    cost_level = cost_level.to_f
    cost_threshold = costs[0] + 1
    removed_cost = 0

    (0 ... costs.size).each do |i|
      removed_cost += costs[i]
      next if costs[i+1] == costs[i]

      # We never want to remove checks with cost zero
      break if costs[i] == 0

      # total_cost - removed_cost is the remaining cost.
      if total_cost - removed_cost >= total_cost * cost_level
        cost_threshold = costs[i]
      end
    end
  end

  # Print a summary of what we actually remove (numbers could differ from
  # what's expected due to granularity issues)
  removed_costs = costs.find_all { |c| c >= cost_threshold }
  removed_cost = removed_costs.reduce(0, :+)

  open(File.join(state.state_path, 'threshold'), 'w') do |threshold_file|
    [threshold_file, $stdout].each do |f|
      f.puts "Cost threshold is #{cost_threshold}"
      f.puts "Removing %d out of %d static checks (%.2f%%)" % [removed_costs.size, costs.size,
                                                               100.0 * removed_costs.size / costs.size]
      f.puts "Removing %d out of %d dynamic checks (%.2f%%)" % [removed_cost, total_cost,
                                                                100.0 * removed_cost / total_cost]
    end
  end

  cost_threshold
end

# Some makefiles compile and link with a single command. We need to handle this
# specially and convert it into multiple commands.
def handle_compile_and_link(argv)
  source_files = argv.select { |f| f =~ /\.(?:c|cc|C|cxx|cpp)$/ }
  is_compile = get_arg(argv, '-c', :first)
  output_file = get_arg(argv, '-o')
  return false if source_files.empty? or is_compile or not output_file

  # OK, this is a combined compile-and-link.
  # Replace it with multiple commands, where each command compiles a single source file.
  non_source_opts = argv.select { |a| not source_files.include?(a) }
  source_files.each do |f|
    current_args = non_source_opts.collect { |a| if a == output_file then "#{f}.o" else a end }
    current_args += ['-c', f]
    main(current_args)
  end

  # Add a link command
  link_args = argv.collect { |a| if source_files.include?(a) then "#{a}.o" else a end }
  main(link_args)

  return true
end

# Some makefiles compile without specifying -o, relying on compilers to choose
# the name of the object file.
def handle_missing_output_name(argv)
  source_files = argv.select { |f| f =~ /\.(?:c|cc|C|cxx|cpp)$/ }
  is_compile = get_arg(argv, '-c', :first)
  output_file = get_arg(argv, '-o')
  return false if source_files.size != 1 or not is_compile or output_file

  # Add the output name manually. The default compiler behavior is to replace
  # the extension with .o, and place the file in the current working directory.
  output_file = source_files[0].sub(/\.(?:c|cc|C|cxx|cpp)$/, '.o')
  output_file = File.basename(output_file)
  main(argv + ['-o', output_file])
  return true
end

# Some build systems (libtool, I'm looking at you) use -MF and related options.
# We create empty dependency files to make them happy. Note that this is a
# hack... for example, it doesn't handle the case when -M is given without -MF,
# and it will break dependency tracking.
def handle_mf_option(argv)
  is_compile = get_arg(argv, '-c', :first)
  dependency_file = get_arg(argv, '-MF')

  if is_compile and dependency_file
    IO.write(dependency_file, "# Stub dependency file created by asap-clang")
  end

  return false  # continue the compilation anyway
end

def main(argv)
  command = get_arg(argv, /^-asap-[a-z0-9-]+$/, :first)
  if command.nil?
    # We are being run like a regular compilation tool.

    # First, handle a few compiler/makefile quirks
    return if handle_compile_and_link(argv)
    return if handle_missing_output_name(argv)
    return if handle_mf_option(argv)

    # Figure out the right
    # compilation stage, and run the corresponding command.
    state = AsapState.new
    compiler = state.create_compiler
    compiler.exec([$0] + argv)
  elsif command == '-asap-init'
    AsapState.initialize_state
  elsif command == '-asap-coverage'
    state = AsapState.new
    state.transition(:initial, :coverage) do
      puts "Will build coverage-instrumented version on next rebuild; please run:"
      puts "make clean && make"
    end
  elsif command == '-asap-compute-costs'
    state = AsapState.new
    state.transition(:coverage, :costs) do
      puts "Computing costs..."
      compute_costs(state)
      puts "Done."
    end
  elsif command == '-asap-compute-threshold'
    state = AsapState.new
    state.transition(:costs, :threshold) do
      compute_cost_threshold(state, argv)
    end
  elsif command == '-asap-optimize'
    state = AsapState.new

    # Allow to fast-forward the state for convenience
    if state.current_state == :coverage
      state.transition(:coverage, :costs) { compute_costs(state) }
    end
    if state.current_state == :costs
      state.transition(:costs, :threshold) { compute_cost_threshold(state, argv) }
    end

    state.transition(:threshold, :optimize) do
      puts "Will build optimized version on next rebuild; please run:"
      puts "make clean && make"
    end

  else
    raise "unknown command: #{command}"
  end
end

main(ARGV)
