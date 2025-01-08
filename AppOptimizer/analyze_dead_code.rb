#!/usr/bin/ruby

require 'fileutils'

# Проверка на валидность пути к проекту
def validate_project_path(path)
  abort "Error: Invalid project path: #{path}" unless path && !path.empty? && Dir.exist?(path)
end

# Поиск файла с расширением .xcworkspace или .xcodeproj
def find_project_files(project_path)
  workspace = Dir.glob("\#{project_path}/*.xcworkspace").first
  project = Dir.glob("\#{project_path}/*.xcodeproj").first

  abort "Error: Neither .xcworkspace nor .xcodeproj found in \#{project_path}" if workspace.nil? && project.nil?
  [workspace, project]
end

# Получение списка элементов (targets или schemes) из xcodebuild
def fetch_xcodebuild_list(list_command, label)
  output = `\#{list_command}`
  items = output[/\b\#{label}:\s*(.+?)$/m, 1]&.split("\n")&.map(&:strip)
  abort "Error: No \#{label.downcase} found in the project." if items.nil? || items.empty?
  items
end

# Подготовка команды для periphery
def build_periphery_command(periphery_path, workspace, project, scheme, target, retain_public)
  command = [periphery_path, "scan"]
  command << (workspace ? "--workspace \"\#{workspace}\"" : "--project \"\#{project}\"")
  command << "--schemes \"\#{scheme}\""
  command << "--targets \"\#{target}\""
  command << "--retain-public" if retain_public
  command.join(" ")
end

# Запуск команды и обработка результатов
def run_and_process_periphery(command, output_file)
  result = `\#{command}`
  
  # Фильтрация и сортировка результатов
  formatted_result = result.each_line
                           .grep(/:\d+:\d+:/)
                           .map { |line| line.sub(/:\d+:\d+:/, '').strip }
                           .sort
                           .join("\n") + "\n"

  File.write(output_file, formatted_result)
  puts "Output saved to \#{output_file}"
rescue Errno::EACCES
  abort "Error: Cannot write to file \#{output_file}"
end

# Основной процесс
project_path = ARGV[0]
retain_public = ARGV[1] == "retain_public:true"
validate_project_path(project_path)

workspace, project = find_project_files(project_path)

list_command = "xcodebuild -list"
list_command += workspace ? " -workspace \"\#{workspace}\"" : " -project \"\#{project}\""

targets = fetch_xcodebuild_list(list_command, "Targets")
schemes = fetch_xcodebuild_list(list_command, "Schemes")

target = targets.first
scheme = schemes.first

puts "Using target: \#{target}"
puts "Using scheme: \#{scheme}"

periphery_path = "/opt/homebrew/bin/periphery"
abort "Error: Periphery not found at \#{periphery_path}" unless File.exist?(periphery_path)

command = build_periphery_command(periphery_path, workspace, project, scheme, target, retain_public)
puts "Running command: \#{command}"

output_file = File.join(project_path, "periphery_output.txt")
run_and_process_periphery(command, output_file)
