require 'rake/ask'

namespace :package do
  namespace :flameshot do

    task :default => :package

    ask           = Rake::Ask.new
    name          = 'flameshot'
    git_url       = 'https://github.com/lupoDharkael/flameshot.git'
    base_dir      = File.join(ENV['HOME'], 'var', 'tmp', 'build')
    build_dir     = File.join(base_dir, name)
    dest_dir      = File.join(base_dir, 'fakeroot')
    prefix        = '/usr'
    mandir        = File.join(prefix, 'share', 'man')

    dependencies  = {
      :debian => %w(
        g++
        build-essential
        qt5-qmake
        qt5-default
        qttools5-dev-tools
        git
      ),
      :redhat => %w(
        qt5-devel
        gcc-c++
        qt5-qtbase-devel
        qt5-linguist
        git
      )
    }

    directory base_dir
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

    task :check_prerequisites => :supported do
      Rake::Task[:prerequisites].invoke(
        ask.net_install,
        dependencies.fetch(ask.os_family.downcase.to_sym, [])
      )
    end

    task :git_clone => [:check_prerequisites, base_dir] do
      cd base_dir
      sh %(git clone #{git_url} #{name})
      cd name
      $version = `git tag | tail -n 1 | cut -c 2-`
      $version.strip!
      sh %(git checkout v#{$version})
    end

    task :build => :git_clone do
      cd build_dir
      sh %(qmake CONFIG+=packaging)
      sh %(make)
    end

    task :install => :build do
      cd build_dir
      sh %(qmake CONFIG+=packaging BASEDIR=#{dest_dir})
      sh %(make install)
    end

    task :package => :install do
      cd build_dir
      mkdir_p ask.pkg_dir
      cd ask.pkg_dir
      sh %(fpm ) +
         %(-s dir ) +
         %(-t #{ask.pkg_target} ) +
         %(--force ) +
         %(-C #{dest_dir} ) +
         %(--iteration 1 ) +
         %(--version #{$version} ) +
         %(--name #{name} ) +
         %(--rpm-dist #{ask.os_dist} ) +
         %( . )
    end
  end
end

desc 'Build the flameshot screenshot tool'
task 'package:flameshot' => 'package:flameshot:default'
