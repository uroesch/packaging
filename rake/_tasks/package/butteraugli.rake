require 'rake/ask'

namespace :package do
  namespace :butteraugli do

    task :default => :package

    ask           = Rake::Ask.new
    name          = 'butteraugli'
    git_url       = 'https://github.com/google/butteraugli.git'
    base_dir      = File.join(ENV['HOME'], 'var', 'tmp', 'build')
    build_dir     = File.join(base_dir, name)
    dest_dir      = File.join(base_dir, 'fakeroot')
    prefix        = '/usr'
    mandir        = File.join(prefix, 'share', 'man')

    dependencies  = {
      :debian => %w(
        build-essential
        libpng-dev
        libjpeg-dev
        git
      ),
      :redhat => %w(
        gcc-c++
        libpng-devel
        libjpeg-devel
        git
      )
    }

    directory base_dir
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
      $version = `git log -n 1 --date=iso | awk '/^Date/ {print $2}'`
      $version.strip!
    end

    task :build => :git_clone do
      cd File.join(build_dir, name)
      sh %(make)
    end

    task :install => :build do
      destination = File.join(dest_dir, 'usr', 'bin')
      mkdir_p destination
      cd File.join(build_dir, name)
      cp name, destination
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

desc 'Build the butteraugli image comparison tool'
task 'package:butteraugli' => 'package:butteraugli:default'
