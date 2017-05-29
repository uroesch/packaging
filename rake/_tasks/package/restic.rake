require 'rake/ask'

namespace :package do
  namespace :restic do
    task :default => :package

    ask           = Rake::Ask.new
    name          = 'restic'
    version       = '0.6.0'
    basename      = "#{name}_#{version}_linux_#{ask.port}.bz2"
    download      = "https://github.com/#{name}/#{name}/releases/download/v#{version}/#{basename}"
    base_dir      = File.join(ENV['HOME'], 'var', 'tmp', 'build')
    build_dir     = File.join(base_dir, name)
    dest_dir      = File.join(base_dir, 'fakeroot')
    prefix        = '/usr'
    mandir        = File.join(prefix, 'share', 'man')

    directory base_dir
    directory build_dir
    directory dest_dir
    directory ask.pkg_dir

    task :clean do
      rm_rf base_dir
    end

    task :supported => :clean do
      case ask.os_codename
      when 'el6'
        puts
        puts 'platform not supported'
        puts
        exit 0
      else
        puts 'platform supported'
      end
    end

    task :download => [build_dir, dest_dir, ask.pkg_dir] do
      cd build_dir
      sh %(wget #{download})
    end

    task :unpack => :download do
      cd build_dir
      sh %(bunzip2 #{basename})
    end

    task :scaffold => :unpack do
      cd dest_dir
      mkdir_p 'usr/local/bin'
      mkdir_p 'etc/bash_completion.d'
    end

    task :install => :scaffold do
      cd dest_dir
      mv File.join(build_dir, basename.ext), 'usr/local/bin/restic'
      chmod 0755, 'usr/local/bin/restic'
      sh %(usr/local/bin/restic autocomplete ) +
	 %(--completionfile etc/bash_completion.d/restic.sh)
    end

    task :package => :install do
      cd build_dir
      mkdir_p ask.pkg_dir
      cd ask.pkg_dir
      sh %(fpm ) +
         %(-s dir ) +
         %(-t deb ) +
         %(--force ) +
         %(-C #{dest_dir} ) +
         %(--iteration 1 ) +
         %(--version #{version} ) +
         %(--name #{name} ) +
         %( . )
    end
  end
end

desc 'Package the restic cloud backup application'
task 'package:restic' => 'package:restic:default'
