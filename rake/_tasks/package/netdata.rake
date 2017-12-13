require 'rake/ask'
namespace :package do
  namespace :netdata do
    task :default => :package

    ask         = Rake::Ask.new
    name        = 'netdata'
    git_url     = 'https://github.com/firehol/netdata.git'
    base_dir    = File.join(ENV['HOME'], 'var', 'tmp', 'build')
    build_dir   = File.join(base_dir, name)
    dest_dir    = File.join(base_dir, 'fakeroot')
    prefix      = '/usr'
    mandir      = File.join(prefix, 'share', 'man')


    dependencies = {
      :debian => %w(
        build-essential
        uuid-dev
        zlib1g-dev
        uuid-dev
        dh-autoreconf
        git
        dh-systemd
        libmnl-dev
        pkg-config
      ),
      :redhat => %w(
        autoconf
        automake
        gcc
        git
        libmnl-devel
        libuuid-devel
        lm-sensors
        make
        MySQL-python
        nc
        pkgconfig
        python
        python-psycopg2
        PyYAML
        zlib-devel
      )
    }

    directory base_dir
    directory dest_dir
    directory ask.pkg_dir

    task :clean do
      rm_rf base_dir
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
      $version = `git tag | tail -n 1 | cut -c 2-`
      $version.strip!
      sh %(git checkout v#{$version})
    end

    task :link_debian => :git_clone do
      return ask.os_family.downcase != 'debian'
      cd build_dir
      ln_s 'contrib/debian', 'debian'
    end

    task :modify_recipe => :link_debian do
      return ask.os_init != 'init' || ask.os_family.downcase != 'debian'
      sh %(sed -i '/systemd/s/autoreconf,systemd/autoreconf/' ) +
         %(#{build_dir}/debian/rules)
      ## mv build_dir + '/debian/control.wheezy', build_dir + '/debian/control'
      sh %(sed -i 's|dh-systemd (>= 1.5)|pkg-config|' ) +
         %(#{build_dir}/debian/control)
      sh %(sed -ri 's|#(EXTRA_OPTS="-P /var/run/netdata.pid")|\\1|' ) +
         %(#{build_dir}/debian/netdata.default)
      sh %(sed -ri 's|(PIDFILE=/var/run/)netdata/(netdata.pid)|\\1\\2|' ) +
         %(#{build_dir}/debian/netdata.init)
      sh %(sed -i -e '/#postrotate/,/#endscript/s/#//' ) +
         %( -e 's/try-restart/restart/' ) +
         %(#{build_dir}/system/netdata.logrotate.in)
    end

    task :pre_prep do
      cd build_dir
      sh %(./autogen.sh)
      sh %(./configure)
    end

    task :build => :pre_prep do
      cd 'contrib'
      sh %(make)
    end

    task :package => :build do
      cd build_dir
      sh %(dpkg-buildpackage -us -uc -rfakeroot)
    end

    task :install => :build do
      destination = File.join(dest_dir, 'usr', 'bin')
      mkdir_p destination
      cd build_dir
      cp name, destination
    end

  end
end

desc 'Build the netdata monitoring app'
task 'package:netdata' => 'package:netdata:default'
