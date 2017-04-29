require 'rake'
require 'rake/ask'

namespace :bootstrap do
  namespace :fpm do

    ask   = Rake::Ask.new
    name = 'fpm'

    gem_version = {
      '1.8' => {
        'fpm'  => '1.4.0',
        'json' => '1.7.7'
      }
    }

    def find_gem_preinstalls(ask, gem_version)
      preinstalls = gem_version.fetch(ask.ruby_major, {}).clone
      preinstalls.delete('fpm')
      preinstalls
    end

    def check_fpm_dependencies(ask)
      case ask.pkg_target
      when 'deb'
        %w(ruby-dev gcc).each do |dep|
          unless system("dpkg -l #{dep}")
            unless system("apt-get -y install #{dep}")
              puts %(Missing dependency #{dep})
              exit 63
            end
          end
        end
      when 'rpm'
        %w(ruby-devel rpm-build gcc).each do |dep|
          # currently only redhat
          unless system("rpm -q #{dep}")
            unless system("yum -y install #{dep}")
              puts %(Missing dependency #{dep})
              exit 63
            end
          end
        end
      end
    end

    dependencies = {
      :debian => %w(
        build-essential
        dh-autoreconf
        dh-systemd
        ruby-dev
        rubygems-integration
      ),
      :redhat => %w(
        gcc
        make
        rubygems
        ruby-devel
      )
    }

    task :default => :deploy

    fpm_version    = gem_version.fetch(ask.ruby_major, {}).fetch('fpm', '>0')
    bootstrap_dir = File.join(ENV['HOME'], 'var', 'tmp', 'bootstrap')
    bootstrap_bin = File.join(bootstrap_dir, 'bin')
    build_dir     = File.join(ENV['HOME'], 'var', 'tmp', 'gem-build', $$.to_s)

    directory bootstrap_dir
    directory ask.pkg_dir
    directory build_dir

    task :clean do
      rm_rf bootstrap_dir
      rm_rf build_dir
    end

    task :check_prerequisites => :clean do
      Rake::Task[:prerequisites].invoke(
        ask.net_install,
        dependencies.fetch(ask.os_family.downcase.to_sym, [])
      )
      check_fpm_dependencies(ask)
    end


    task :gem_prerequisites => [bootstrap_dir , :check_prerequisites] do
      find_gem_preinstalls(ask, gem_version).each do |name, version|
        sh %(gem install #{name} --install-dir #{bootstrap_dir} ) +
           %(--no-rdoc --no-ri ) +
           %(--version '#{version}')
      end
    end

    task :bootstrap => :gem_prerequisites do
      sh %(gem install fpm --install-dir #{bootstrap_dir} ) +
         %(--no-rdoc ) +
         %(--no-ri ) +
         %(--bindir #{bootstrap_bin} ) +
         %(--version '#{fpm_version}')
    end

    task :build_package => [:bootstrap, ask.pkg_dir] do
      puts ask.pkg_dir
      cd ask.pkg_dir
      gems = Rake::FileList.new("#{bootstrap_dir}/cache/*.gem")
      gems.each do |gem|
        sh %(GEM_PATH=#{bootstrap_dir}; export GEM_PATH; ) +
           %( #{bootstrap_bin}/fpm ) +
           %(-s gem ) +
           %(-t #{ask.pkg_target} ) +
           %(-d ruby ) +
           %(--force ) +
           %(--prefix #{ask.gem_dir} ) +
           %(--gem-bin-path #{ask.gem_bindir} ) +
	   %(--rpm-dist #{ask.os_dist} ) +
           gem
      end
    end

    task :deploy => :build_package do
      pkgs = Rake::FileList.new(
        "#{ask.pkg_dir}/*.#{ask.pkg_target}"
      )
      sh %(sudo #{ask.local_install} #{pkgs.join(' ')})
    end

    task :remove_deps do
      sh %(sudo apt-get purge #{remove_deps.join(' ')})
    end
  end
end

desc 'Build and deploy the fpm command'
task 'bootstrap:fpm' => 'bootstrap:fpm:default'
