require 'rake/ask'
namespace :package do
  namespace :netdata do
    task :default => :install

    ask         = Rake::Ask.new
    name        = 'netdata'
    git_url     = 'https://github.com/firehol/netdata.git'
    base_dir    = File.join(ENV['HOME'], 'var', 'tmp', 'build')
    build_dir   = File.join(base_dir, name)
    dest_dir    = File.join(base_dir, 'fakeroot')
    prefix      = '/usr'
    mandir      = File.join(prefix, 'share', 'man')
    sources_dir = File.join(ENV['HOME'], 'rpmbuild', 'SOURCES')
    rpms_dir    = File.join(ENV['HOME'], 'rpmbuild', 'RPMS')

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
        rpm-build
      )
    }

    directory base_dir
    directory build_dir
    directory dest_dir
    directory ask.pkg_dir
    directory sources_dir

    task :clean do
      rm_rf base_dir
    end

    task :check_prerequisites => :clean do
      Rake::Task[:prerequisites].invoke(
        ask.net_install,
        dependencies.fetch(ask.os_family.downcase.to_sym, [])
      )
    end

    task :git_clone => [:check_prerequisites, build_dir, base_dir] do
      cd base_dir
      sh %(git clone #{git_url} #{name})
      cd name
      $version = `git tag | tail -n 1 | cut -c 2-`
      $version.strip!
      sh %(git checkout v#{$version})
    end

    task :link_debian => :git_clone do
      cd build_dir
      ln_s 'contrib/debian', 'debian'
      begin
        if ask.os_init != 'init' || ask.os_family.downcase != 'debian'
          Rake::Task['package:netdata:modify_recipe'].execute
        end
      rescue
        puts :foo
      end
    end

    task :modify_recipe => :link_debian do
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

    task :pre_prep => :link_debian do
      cd build_dir
      sh %(./autogen.sh)
      sh %(./configure)
    end

    task :build => [:pre_prep, sources_dir] do
      cd build_dir
      case ask.os_family.downcase
      when 'debian'
        cd 'contrib'
        sh %(make)
      when 'redhat'
        sh %(make dist)
        mv Rake::FileList["#{name}-#{$version}.tar.*"], sources_dir
      else
        puts "nothing to do"
      end
    end

    task :package => :build do
      cd build_dir
      case ask.os_family.downcase
      when 'debian' then sh %(dpkg-buildpackage -us -uc -rfakeroot)
      when 'redhat' then sh %(rpmbuild -bb netdata.spec)
      else ''
      end
    end

    task :install => :package do
      cd base_dir
      mkdir_p ask.pkg_dir
      case ask.os_family.downcase
      when 'debian' then mv Rake::FileList['*.deb'], ask.pkg_dir
      when 'redhat' then mv Rake::FileList["#{rpms_dir}/**/*.rpm"], ask.pkg_dir
      else ''
      end
    end
  end
end

desc 'Build the netdata monitoring app'
task 'package:netdata' => 'package:netdata:default'
