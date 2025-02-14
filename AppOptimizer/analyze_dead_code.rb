#!/usr/bin/ruby

require 'fileutils'
require 'digest'

# Проверка на валидность пути к проекту
def validate_project_path(path)
  abort "Error: Invalid project path: #{path}" unless path && !path.empty? && Dir.exist?(path)
end

# Поиск файла с расширением .xcworkspace или .xcodeproj
def find_project_files(project_path)
  workspace = Dir.glob("#{project_path}/*.xcworkspace").first
  project = Dir.glob("#{project_path}/*.xcodeproj").first

  if workspace.nil? && project.nil?
    abort "Error: Neither .xcworkspace nor .xcodeproj found in #{project_path}"
  end

  [workspace, project]
end

# Получение списка элементов (targets или schemes) из xcodebuild
def fetch_xcodebuild_list(list_command, label)
  output = `#{list_command}`
  items = output[/\b#{label}:\s*(.+?)$/m, 1]&.split("\n")&.map(&:strip)
  abort "Error: No #{label.downcase} found in the project." if items.nil? || items.empty?
  items
end

# Подготовка команды для periphery
def build_periphery_command(periphery_path, workspace, project, scheme, target, retain_public)
  command = [periphery_path, "scan"]
  command << (workspace ? "--workspace \"#{workspace}\"" : "--project \"#{project}\"")
  command << "--schemes \"#{scheme}\""
  command << "--targets \"#{target}\""
  command << "--retain-public" if retain_public
  command.join(" ")
end

# Запуск команды и обработка результатов
def run_and_process_periphery(command, output_file)
  result = `#{command}`
  
  # Фильтрация и сортировка результатов
  formatted_result = result.each_line
                           .grep(/:\d+:\d+:/)
                           .map { |line| line.sub(/:\d+:\d+:/, '').strip }
                           .sort
                           .join("\n") + "\n"

  File.write(output_file, formatted_result)
rescue Errno::EACCES
  abort "Error: Cannot write to file #{output_file}"
end

# Хэширование файла
def file_hash(file_path)
  # Проверка, является ли путь директорией
  if File.directory?(file_path)
    # Если это директория, проверим, не является ли это .xcodeproj (пакет Xcode)
    if file_path.end_with?(".xcodeproj")
      # Внутри .xcodeproj есть несколько файлов, и мы должны хэшировать один из них, например, project.pbxproj
      project_file = File.join(file_path, "project.pbxproj")
      unless File.file?(project_file)
        abort "Error: project.pbxproj not found in #{file_path}."
      end
      file_path = project_file  # Теперь используем именно этот файл для хэширования
    else
      abort "Error: #{file_path} is a directory, not a file."
    end
  end

  # Если это файл, продолжаем хэширование
  Digest::SHA256.hexdigest(File.read(file_path))
end

# Сохранение хэшей в отдельный файл
def save_cache(cache_file, file_hashes)
  File.write(cache_file, Marshal.dump(file_hashes))
end

# Загрузка хэшей из кэша
def load_cache(cache_file)
  return {} unless File.exist?(cache_file)
  Marshal.load(File.read(cache_file))
rescue => e
  puts "Error loading cache: #{e.message}"
  {}
end

# Основной процесс
project_path = ARGV[0]
retain_public = ARGV[1] == "retain_public:true"
validate_project_path(project_path)

workspace, project = find_project_files(project_path)

list_command = "xcodebuild -list"
list_command += workspace ? " -workspace \"#{workspace}\"" : " -project \"#{project}\""

targets = fetch_xcodebuild_list(list_command, "Targets")
schemes = fetch_xcodebuild_list(list_command, "Schemes")

target = targets.first
scheme = schemes.first

periphery_path = "/opt/homebrew/bin/periphery"
abort "Error: Periphery not found at #{periphery_path}" unless File.exist?(periphery_path)

# Кэширование
cache_file = File.join(project_path, ".file_hashes_cache")  # Путь для кэшированного файла с хэшами
file_hashes = load_cache(cache_file)

# Проверяем хэши для всех файлов проекта (например, workspace или project)
files_to_check = [workspace, project].compact
files_to_analyze = []

files_to_check.each do |file|
  current_hash = file_hash(file)
  if file_hashes[file] != current_hash
    puts "Файлы изменились, проводим анализ."
    files_to_analyze << file
    file_hashes[file] = current_hash
  else
    puts "Файлы не изменились. Пропускаем анализ."
  end
end

# Если были изменения, запускаем анализ
if files_to_analyze.any?
  command = build_periphery_command(periphery_path, workspace, project, scheme, target, retain_public)

  output_file = File.join(project_path, "unused_dead_code.txt")
  run_and_process_periphery(command, output_file)
end

# Сохраняем хэши файлов в кэш
save_cache(cache_file, file_hashes)
