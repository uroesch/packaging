require 'rake/ask'

namespace :package do
  namespace :restic do
    task :default => :package

    ask           = Rake::Ask.new
    name          = 'restic'
    version       = ENV['VERSION'] || '0.8.0'
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
      Rake::Task[base_dir].reenable
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
    end

    task :postinstall => :install do
      cd dest_dir
      case
      when version.to_f <= 0.7
        sh %(usr/local/bin/restic autocomplete ) +
	         %(--completionfile etc/bash_completion.d/restic.sh)
      when version.to_f >= 0.8
        man1dir = File.join(mandir[1..-1], 'man1')
        sh %(usr/local/bin/restic generate ) +
	         %(--bash-completion etc/bash_completion.d/restic.sh)
        mkdir_p man1dir
        sh %(usr/local/bin/restic generate --man #{man1dir})
      end
    end

    task :package => :postinstall do
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

desc 'Package the restic cloud backup application; Options: VERSION=X.X.X'
task 'package:restic' => 'package:restic:default'
