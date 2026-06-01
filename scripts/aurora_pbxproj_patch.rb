#!/usr/bin/env ruby
# One-shot pbxproj patch: register Aurora sources, remove BreatheHomeRootView.
require 'xcodeproj'

PROJECT = 'FreeAPS.xcodeproj'
TARGET  = 'FreeAPS'
AURORA_DIR = 'FreeAPS/Sources/Modules/Home/View/Aurora'

project = Xcodeproj::Project.open(PROJECT)
target  = project.targets.find { |t| t.name == TARGET }
abort "Target not found: #{TARGET}" unless target

# 1. Locate the existing "View" group under Home so the new "Aurora" group
#    sits next to BreatheHomeRootView's neighbors.
home_group = project.main_group.find_subpath('FreeAPS/Sources/Modules/Home/View', false)
abort 'Home/View group not found' unless home_group

# 2. Remove BreatheHomeRootView entry — file already deleted on disk.
removed = 0
project.files.each do |fref|
  next unless fref.path&.end_with?('BreatheHomeRootView.swift')
  target.source_build_phase.files.each do |bf|
    if bf.file_ref == fref
      bf.remove_from_project
      removed += 1
    end
  end
  fref.remove_from_project
  removed += 1
end
puts "BreatheHomeRootView entries removed: #{removed}"

# 3. Create an Aurora group (or reuse) mirroring on-disk hierarchy.
aurora_group = home_group.find_subpath('Aurora', true)
aurora_group.set_source_tree('<group>')
aurora_group.set_path('Aurora')

# Subfolders → groups
SUBFOLDERS = %w[Hero Chart Sheets Components Screens]
sub_groups = SUBFOLDERS.each_with_object({}) do |name, acc|
  g = aurora_group.find_subpath(name, true)
  g.set_source_tree('<group>')
  g.set_path(name)
  acc[name] = g
end

# 4. Walk the on-disk Aurora directory and register each .swift file.
added = 0
Dir.glob("#{AURORA_DIR}/**/*.swift").sort.each do |path|
  rel = path.sub("#{AURORA_DIR}/", '')
  parts = rel.split('/')
  filename = parts.pop
  parent = if parts.empty?
             aurora_group
           else
             sub_groups[parts.first] || aurora_group.find_subpath(parts.first, true)
           end
  # Skip if file already registered in this group.
  existing = parent.files.find { |f| f.path == filename }
  if existing
    # Make sure it's in the target.
    unless target.source_build_phase.files_references.include?(existing)
      target.add_file_references([existing])
    end
    next
  end
  ref = parent.new_reference(filename)
  ref.last_known_file_type = 'sourcecode.swift'
  target.add_file_references([ref])
  added += 1
end

puts "Aurora source files added: #{added}"

project.save
puts 'pbxproj saved.'
