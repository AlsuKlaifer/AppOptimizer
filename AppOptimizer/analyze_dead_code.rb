#!/usr/bin/ruby

project_path = ARGV[0]
if project_path.nil? || project_path.empty?
  puts "Error: No project path provided."
  exit(1)
end

begin
  Dir.chdir(project_path)
rescue Errno::EACCES
  puts "Error: Cannot access directory #{project_path}"
  exit(1)
end

result = `/opt/homebrew/bin/periphery scan --report-exclude \"#{project_path}/Service/GraphQL/**\"`
result_stripped_of_absolute_path_prefix = result.gsub(Dir.pwd, '')
filtered_out_result = result_stripped_of_absolute_path_prefix.split("\n").filter { |line| /:\d+:\d+:/.match?(line) }
sorted_result = filtered_out_result.sort
result_with_removed_code_line_number = sorted_result.map { |l| l.sub(/:\d+:\d+:/, '') }
output = result_with_removed_code_line_number.join("\n") + "\n"

# Сохраняем результат
output_file = File.join(File.dirname(__FILE__), "periphery_output.txt")
File.write(output_file, output)
