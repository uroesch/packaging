require 'rake/ask'
namespace :package do
  namespace :embed_ttf do
    task :default => :package

    ask         = Rake::Ask.new
    name        = 'embed-ttf'
    url         = 'http://carnage-melon.tom7.org/embed/embed.c'
    base_dir    = File.join(ENV['HOME'], 'var', 'tmp', 'build')
    build_dir   = File.join(base_dir, name)
    dest_dir    = File.join(base_dir, 'fakeroot')
    prefix      = '/usr'
    mandir      = File.join(prefix, 'share', 'man')
    $version    = '1.0.0'

    dependencies = {
      :debian => %w(
        gcc
      ),
      :redhat => %w(
        gcc
      )
    }

    directory base_dir
    directory build_dir
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

    task :download => [:check_prerequisites, base_dir, build_dir] do
      cd build_dir
      sh %(wget "#{url}")
    end

    task :build => :download do
      cd build_dir
      sh %(gcc -o #{name} #{File.basename(url)})
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

desc 'Build the embed-ttf helper for TTF fonts'
task 'package:embed-ttf' => 'package:embed_ttf:default'
