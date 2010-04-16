require "rake/packagetask"

Rake::PackageTask.new("otfinstall", "0.2") do |p|
  p.need_zip = true
  p.package_files.include("lib/**/*.rb","examples/*oinst", "otfinst.rb")
end
