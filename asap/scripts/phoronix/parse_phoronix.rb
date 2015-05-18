#!/usr/bin/env ruby

require 'nokogiri'

puts "variable,benchmark,value"

ARGV.each do |filename|
  open(filename) do |f|
    doc = Nokogiri::XML(f)
    doc.xpath('//Result').each do |r|
      identifier = r.xpath('Identifier').text
      raise "Strange identifier" unless identifier =~ /^local\/.*-(asan-[0-9a-z]*|ubsan-[0-9a-z]*|baseline)$/

      variable = $1
      benchmark = "#{r.xpath('Title').text} - #{r.xpath('Description').text}"
      benchmark.gsub!(',', '')
      value = r.xpath('Data/Entry/Value').text
      proportion = r.xpath('Proportion').text
      raise "Strange proportion" unless proportion =~ /LIB|HIB/

      value = 1.0 / value.to_f if proportion == 'HIB'

      puts "#{variable},#{benchmark},#{value}"
    end
  end
end
