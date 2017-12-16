require 'rake/ask'
namespace :package do
  namespace :zopflipng do
    task :default => :package

    ask         = Rake::Ask.new
    name        = 'zopflipng'
    git_url     = 'https://github.com/google/zopfli.git'
    base_dir    = File.join(ENV['HOME'], 'var', 'tmp', 'build')
    build_dir   = File.join(base_dir, name)
    dest_dir    = File.join(base_dir, 'fakeroot')
    prefix      = '/usr'
    mandir      = File.join(prefix, 'share', 'man')

    dependencies = {
      :debian => %w(
        build-essential
        git
      ),
      :redhat => %w(
        gcc
        gcc-c++
        make
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

    task :check_prerequisites => :clean do
      Rake::Task[:prerequisites].invoke(
        ask.net_install,
        dependencies.fetch(ask.os_family.downcase.to_sym, [])
      )
    end

    task :git_clone => [:check_prerequisites, base_dir] do
      cd base_dir
      sh %(git clone #{git_url} #{name})
      cd name
      $version = `git tag | tail -n 1`
      $version.strip!
      sh %(git checkout #{$version})
      $version.sub!(/.*-/, '')
    end

    task :build => :git_clone do
      cd build_dir
      sh %(make #{name})
    end

    task :install => :build do
      destination = File.join(dest_dir, 'usr', 'bin')
      mkdir_p destination
      cd build_dir
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

desc 'Build the zopflipng PNG optimizer'
task 'package:zopflipng' => 'package:zopflipng:default'
