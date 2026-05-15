#!/usr/bin/env bash
set -euo pipefail

# Add a Swift source file (or test file) to a target in GhosttyTabs.xcodeproj.
# Usage: ./scripts/add-source-file.sh <relative-path> [target-name]
#   default target-name: GhosttyTabs  (the main app target)
# For test files, pass "cmuxTests" or "cmuxUITests" as the second argument.
#
# Uses the Ruby `xcodeproj` gem, which re-serializes project.pbxproj in its own
# normalized format on save. The first add per session produces a large
# normalization diff against project.pbxproj; subsequent adds inside the same
# normalized state produce smaller diffs. Reviewers should treat the
# normalization as boilerplate.

if [ $# -lt 1 ]; then
    echo "Usage: $0 <relative-path> [target-name]" >&2
    exit 2
fi

if ! ruby -e "require 'xcodeproj'" 2>/dev/null; then
    echo "Installing xcodeproj gem (user install)..." >&2
    gem install --user-install xcodeproj >/dev/null
fi

FILE_PATH="$1"
TARGET_NAME="${2:-GhosttyTabs}"

ruby -e "
require 'xcodeproj'
project = Xcodeproj::Project.open('GhosttyTabs.xcodeproj')
target = project.targets.find { |t| t.name == ARGV[1] }
abort(\"target not found: #{ARGV[1]}\") unless target

file_path = ARGV[0]
relative_dir = File.dirname(file_path)
group = project.main_group
unless relative_dir == '.' || relative_dir.empty?
  relative_dir.split('/').each do |segment|
    next if segment == '.'
    sub = group.children.find { |g| g.is_a?(Xcodeproj::Project::Object::PBXGroup) && g.path == segment }
    group = sub || group.new_group(segment, segment)
  end
end

basename = File.basename(file_path)
existing_ref = group.files.find { |f| f.path == basename }
already_in_target = existing_ref && target.source_build_phase.files_references.include?(existing_ref)

if already_in_target
  puts \"#{file_path} already in target #{ARGV[1]} (no changes)\"
  exit 0
end

file_ref = existing_ref || group.new_reference(basename)
target.add_file_references([file_ref])
project.save
puts \"added #{file_path} to target #{ARGV[1]}\"
" -- "$FILE_PATH" "$TARGET_NAME"
