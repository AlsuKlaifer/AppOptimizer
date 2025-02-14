#!/usr/bin/ruby

require 'bundler/setup'
puts "Gems loaded: #{Gem.loaded_specs.keys}"
require 'set'
require 'concurrent-ruby'

# Функция для извлечения всех строковых литералов из AST
def extract_string_literals(ast)
  literals = []
  if ast.is_a?(Parser::AST::Node)
    if ast.type == :str
      literals << ast.children[0]
    else
      ast.children.each do |child|
        literals += extract_string_literals(child)
      end
    end
  end
  literals
end

# Проверка валидности пути к проекту
project_path = ARGV[0]
if project_path.nil? || project_path.empty? || !Dir.exist?(project_path)
  abort "Error: Invalid project path: #{project_path}"
end

# Собираем все ассеты
assets_dirs = Dir.glob("#{project_path}/**/*.xcassets")
if assets_dirs.empty?
  puts "No assets found in the project."
  exit(0)
end

all_assets = Set.new
assets_dirs.each do |assets_dir|
  Dir.glob("#{assets_dir}/**/*.imageset") do |asset_dir|
    asset_name = File.basename(asset_dir, ".imageset")
    all_assets << asset_name
  end
end

# Фильтруем исходные файлы (например, .swift, .xib, .storyboard) для ускорения анализа
source_files = Dir.glob("#{project_path}/**/*.{swift,xib,storyboard}")

# Функция для обработки одного файла
def process_file(file_path, all_assets)
  used_assets = Set.new
  begin
    file_content = File.read(file_path)
    ast = Parser::CurrentRuby.parse(file_content)
    string_literals = extract_string_literals(ast)
    
    string_literals.each do |literal|
      all_assets.each do |asset_name|
        if literal.include?(asset_name)
          used_assets << asset_name
          break
        end
      end
    end
  rescue SyntaxError => e
    puts "Error parsing #{file_path}: #{e.message}"
  end
  used_assets
end

# Используем параллельную обработку для ускорения анализа исходных файлов
executor = Concurrent::ThreadPoolExecutor.new(
  min_threads: 4, max_threads: 16, max_queue: 1000, fallback_policy: :caller_runs
)

# Массив задач для параллельной обработки файлов
future_results = source_files.map do |source_file|
  Concurrent::Future.execute(executor: executor) do
    process_file(source_file, all_assets)
  end
end

# Собираем результаты из всех параллельных задач
used_assets = Set.new
future_results.each do |future|
  used_assets.merge(future.value)
end

# Исключаем системные ассеты
system_assets = ["AppIcon"]
unused_assets = all_assets.to_a - used_assets.to_a - system_assets

# Записываем неиспользуемые ассеты в файл
output_file = File.join(project_path, "unused_assets.txt")
if unused_assets.empty?
  puts "No unused assets found."
else
  File.write(output_file, unused_assets.join("\n"))
  puts "Unused assets saved to #{output_file}"
end
