require 'rake/ask'

namespace :package do
  namespace :stubby do
    task :default => :package

    ask           = Rake::Ask.new
    name          = 'stubby'
    git_url       = 'https://github.com/getdnsapi/stubby.git'
    base_dir      = File.join(ENV['HOME'], 'var', 'tmp', 'build')
    build_dir     = File.join(base_dir, name)
    dest_dir      = File.join(base_dir, 'fakeroot')
    prefix        = '/usr'
    mandir        = File.join(prefix, 'share', 'man')

    dependencies  = {
      :debian => %w(
        build-essential
        git
      ),
      :redhat => %w(
        gcc-c++
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
      sh %(git clone #{git_url})
      cd name
      $version = `git tag | tail -n 1 | cut -c 2-`
      $version.strip!
      sh %(git checkout v#{$version})
    end

    task :modify_makefile => :git_clone do
      cd build_dir
      sh %(sed -i '/^  TARGETDIR/s#=.*#= #{dest_dir}/usr/bin#' ) +
         %(#{build_dir}/guetzli.make)
    end

    task :build => :modify_makefile do
      cd build_dir
      sh %(make)
    end

    task :package => :build do
      cd build_dir
      mkdir_p ask.pkg_dir
      cd ask.pkg_dir
      sh %(fpm ) +
         %(-s dir ) +
         %(-t deb ) +
         %(--force ) +
         %(-C #{dest_dir} ) +
         %(--iteration 1 ) +
         %(--version #{$version} ) +
         %(--name #{name} ) +
         %( . )
    end
  end
end

desc 'Build the stubby dns cache with tls forwarding'
task 'package:stubby' => 'package:stubby:default'
