#!/usr/bin/env ruby

require "optparse"

$:.unshift File.join(File.dirname(__FILE__),'lib')
require "otfinstall"


o=OTFInstall.new
o.basedir=Dir.pwd + "/texmf"
o.fontbase=Dir.pwd


ARGV.options do |opt|
  opt.summary_width = 20
  opt.banner = "Usage: otfinst <fontdescription.oinst>"
  opt.on('-b DIR','--basedir', 'Set base directory where texmf is located. Default', 'is the current directory') do |d|
    o.basedir=d
  end
  opt.on('-f DIR','--fontbase', 'Set base directory for otf-fonts. If set, it', 'will look in vendor/collection for the fontfiles') do |d|
    o.fontbase=d
  end
  opt.parse!
end

unless ARGV.size == 1
  puts "Error: otfinst needs exactly one argument. See otfinst -h for help."
  exit(-1)
end

oinstfile=ARGV[0].chomp('.oinst') + '.oinst'

begin
  `otfinfo --help 2>&1`
  unless $?.success?
    puts "Command `otfinfo' not found. Did you install lcdf type tools?"
    exit(-1)
  end
  o.read_otfinstr(oinstfile)
rescue Errno::ENOENT
  puts "Error: Cannot find the file #{oinstfile}"
  exit(-1)
end

