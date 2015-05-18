#!/usr/bin/env ruby

config = IO.read("asap.cfg")

autogenerate_re = /
  ^ \# \s AUTOGENERATE: \s+ (.*) $
  (?:.|\n)*
  ^ \# \s END \s AUTOGENERATE: \s+ \1 $
/x

config.gsub!(autogenerate_re) do |match|
  puts "Replacing autogenerate-block for #{$1}"
  result = "# AUTOGENERATE: #{$1}\n"
  result += %x{ #{$1} }
  result += "# END AUTOGENERATE: #{$1}"
  result
end

IO.write("asap.cfg", config)
