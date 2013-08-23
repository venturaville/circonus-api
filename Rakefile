
require 'rake'

namespace :gem do
  desc "Install the gem locally"
  task :install do
    puts "Building gem"
    `gem build circonus.gemspec`
    puts "Installing gem"
    `sudo gem install ./circonus-*.gem`
    puts "Removing built gem"
    `rm circonus-*.gem`
  end
end

namespace :git do
  desc "make a git tag"
  task :tag do
    version = `awk -F \\\" ' /version/ { print $2 } ' circonus.gemspec`
    puts "Tagging git with version=#{version}"
    system "git tag #{version}"
    system "git push --tags"
  end
end

