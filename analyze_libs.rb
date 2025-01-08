#!/usr/bin/ruby

require 'json'
require 'set'

project_path = ARGV[0]
pods_lock_file = File.join(project_path, "Podfile.lock")
package_resolved_file = File.join(project_path, "Package.resolved")

if project_path.nil? || project_path.empty? || !Dir.exist?(project_path)
  abort "Error: Invalid project path"
end

# Список зависимостей из Podfile.lock
def parse_pods(pods_lock_file)
  return [] unless File.exist?(pods_lock_file)

  pods = []
  File.foreach(pods_lock_file) do |line|
    if line.strip.start_with?("-")
      pod_name = line.strip.split(" ")[1]
      pods << pod_name.split("/").first
    end
  end
  pods.uniq
end

# Список зависимостей из Package.resolved
def parse_spm(package_resolved_file)
  return [] unless File.exist?(package_resolved_file)

  resolved = JSON.parse(File.read(package_resolved_file))
  resolved["object"]["pins"].map { |pin| pin["package"] }
end

# Сканирование начальных частей файлов Swift для использования библиотек
def find_usage(library_names, project_path)
  used_libraries = Set.new
  pattern = library_names.map { |name| "import #{Regexp.escape(name)}" }.join("|")
  
  grep_results = `grep -rE "#{pattern}" "#{project_path}" --include=*.swift`

  grep_results.each_line do |line|
    library_names.each do |library|
      if line.include?("import #{library}")
        used_libraries << library
        break
      end
    end
  end

  used_libraries.to_a
end

# Поиск зависимостей
pods = parse_pods(pods_lock_file)
spm_packages = parse_spm(package_resolved_file)
all_libraries = pods + spm_packages

puts "Found libraries: #{all_libraries}"

used_libraries = find_usage(all_libraries, project_path)
unused_libraries = all_libraries - used_libraries

output_file = File.join(project_path, "unused_lib.txt")
File.write(output_file, unused_libraries.join("\n"))

if unused_libraries.empty?
  puts "No unused libraries found."
else
  puts "Unused libraries saved to #{output_file}"
end
