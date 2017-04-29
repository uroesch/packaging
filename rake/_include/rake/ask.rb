require 'rubygems'
module Rake
  class Ask

    PKG_DIR = 'packages'

    attr_reader :system,
      :kernel,
      :arch,
      :os_name,
      :os_description,
      :os_release,
      :os_major,
      :os_codename,
      :os_dist,
      :os_family,
      :pkg_target,
      :pkg_dir,
      :local_install,
      :net_install,
      :ruby_version,
      :ruby_major,
      :gem_dir,
      :gem_bindir

    def initialize
      system_type
      os
      package_type
      ruby
    end

    private

    def system_type
      @system = `uname -s`.strip
      @kernel = `uname -r`.strip
      @arch   = `uname -m`.strip
    end

    def ruby
       require 'rubygems'
       @ruby_version = RUBY_VERSION.to_s
       @ruby_major   = RUBY_VERSION.to_f.to_s
       @gem_dir      = Gem.path.delete_if { |x| x.match(ENV['HOME']) }.first
       @gem_bindir   = '/usr/bin'
    end

    def os
      lsb_release = `which lsb_release 2>/dev/null`.strip
      if ! lsb_release.empty?
        @os_name        = `#{lsb_release} -s -i`.strip
        @os_description = `#{lsb_release} -s -d`.strip
        @os_relase      = `#{lsb_release} -s -r`.strip
        @os_major       = @os_relase.to_i
        @os_codename    = `#{lsb_release} -s -c`.strip
        @os_dist        = @os_codename
      else File.exist?('/etc/redhat-release')
        content = File.open('/etc/redhat-release').readline.strip
        content.match(%r{^(.+?)\s.+?([\d.]+)\s+\((.*)\)})
        @os_name        = $1
        @os_description = content
        @os_relase      = $2
        @os_major       = @os_relase.to_i
        which_osdist
        @os_codename    = @os_dist
      end
      which_osfamily
    end

    def package_type
      @pkg_dir = File.join(Rake.original_dir, '..', PKG_DIR, @os_dist)
      case @os_family
      when 'Debian'
         @pkg_target    = 'deb'
         @local_install = 'dpkg -i'
         @net_install   = 'apt-get -y install'
      when 'RedHat'
         @pkg_target    = 'rpm'
         @local_install = 'rpm -Uvh'
         @net_install   = 'yum -y install' if @os_dist =~ /^el/
         @net_install   = 'dnf -y install' if @os_name == 'Fedora'
      end
    end

    def which_osfamily
      @os_family = case @os_name
                   when /Ubuntu|Debian|Mint/i
                     'Debian'
                   when /Fedora|RedHat|CentOS/i
                     'RedHat'
                   else
                     'unknown'
                   end
    end

    def which_osdist
      @os_dist = case @os_name
                 when /RedHat|CentOS/i
                     'el' + @os_major.to_s
                 when /Fedora/i
                     'fc' + @os_major.to_s
                 else
                   ''
                 end
    end

  end
end
