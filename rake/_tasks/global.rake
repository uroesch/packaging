#desc "Install system prerequisites"
task :prerequisites, [:cmd, :deps] do |t,args|
  sh %(sudo #{args[:cmd]} #{args[:deps].join(' ')})
  Rake::Task[:prerequisites].reenable
end

