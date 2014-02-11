#!/usr/bin/env ruby

require 'yaml'

config = YAML.load_file 'gpm.yaml'

def create_directory directory
  puts "mkdir --parents #{directory}"
end

def change_to directory
  puts "cd #{directory}"
end

def directory_exists? directory
  File.directory? directory
end

def sync_with_upstream directory, repository
  create_directory directory unless directory_exists? directory
  change_to directory
  if directory_exists? '.git'
    puts "git pull"
  else
    puts "git clone #{repository} ."
  end
end

def checkout_version tag
  puts "git checkout #{tag}"
end

def run_configure package, config
  configure = './configure'

  unless package['configure'].class == TrueClass
    if package['configure']['flags'] then
      package['configure']['flags'].each do |flag|
        configure << " " + flag
      end
    end
  end
  configure.gsub!('#{base_path}', "#{config['base_path']}")
  puts "#{configure}"
end

def run_autoconf
  puts 'autoconf'
end

def install package
  unless package['install'] == false
    if package['alternate_install']
      alternate_install package
    else
      traditional_install package
    end
  end
end

def traditional_install package
  puts 'make'
  puts 'make install'
end

def alternate_install package
  puts package['alternate_install']
end

config['packages'].each do |name, package|
  puts "\nFor package #{name}..."
  package_path = config['base_path'] + '/' + package['local']

  sync_with_upstream package_path, package['remote']
  checkout_version package['version']

  run_autoconf if package['needs_autoconf']
  run_configure package, config if package['configure']
  install package unless config['dry_run']
end
