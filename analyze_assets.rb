#!/usr/bin/ruby
require 'set'

project_path = ARGV[0]

if project_path.nil? || project_path.empty? || !Dir.exist?(project_path)
  abort "Error: Invalid project path: #{project_path}"
end

assets_dirs = Dir.glob("#{project_path}/**/*.xcassets")
if assets_dirs.empty?
  puts "No assets found in the project."
  exit(0)
end

# Собираем все ассеты с использованием Set для исключения дубликатов
all_assets = Set.new

assets_dirs.each do |assets_dir|
  Dir.glob("#{assets_dir}/**/*.imageset") do |asset_dir|
    asset_name = File.basename(asset_dir, ".imageset")
    all_assets << asset_name
  end
end

# Выполняем один вызов grep для поиска всех ассетов разом
asset_names_pattern = all_assets.to_a.map { |name| Regexp.escape(name) }.join("|")
grep_command = "grep -rwE \"#{asset_names_pattern}\" \"#{project_path}\" --include=*.{swift,xib,storyboard,plist,json,xml}"
grep_results = `#{grep_command}`

# Парсим использованные ассеты из результатов grep
used_assets = Set.new
grep_results.each_line do |line|
  all_assets.each do |asset_name|
    if line.include?(asset_name)
      used_assets << asset_name
      break
    end
  end
end

# Исключаем системные ассеты
system_assets = ["AppIcon"]
unused_assets = all_assets.to_a - used_assets.to_a - system_assets

output_file = File.join(project_path, "unused_assets.txt")

if unused_assets.empty?
  puts "No unused assets found."
else
  File.write(output_file, unused_assets.join("\n"))
  puts "Unused assets saved to #{output_file}"
end
