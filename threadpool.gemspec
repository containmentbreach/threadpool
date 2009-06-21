gemspec = Gem::Specification.new do |s|
  s.name = 'threadpool'
  s.version = '0.2.4'
  s.date = '2009-06-21'
  s.authors = ['Igor Gunko']
  s.email = 'tekmon@gmail.com'
  s.summary = 'Thread pool for Ruby'
  s.homepage = 'http://github.com/omg/threadpool'
  s.rubygems_version = '1.3.1'

  s.require_paths = %w(lib)

  s.files = %w(
    README.rdoc MIT-LICENSE Rakefile
    lib/threadpool.rb
    lib/omg-threadpool.rb
  )

  s.test_files = %w(
    test/threadpool_test.rb
  )

  s.has_rdoc = true
  s.rdoc_options = %w(--line-numbers --main README.rdoc)
  s.extra_rdoc_files = %w(README.rdoc MIT-LICENSE)

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then

    else
    end
  else
  end
end
