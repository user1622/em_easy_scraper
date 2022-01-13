# frozen_string_literal: true

require_relative 'lib/em_easy_scraper/version'

Gem::Specification.new do |spec|
  spec.name = 'em_easy_scraper'
  spec.version = EmEasyScraper::VERSION
  spec.authors = ['user1622']
  spec.email = ['pastushuk.denis@gmail.com']

  spec.summary = 'Easy scraper tool based on EventMachine library'
  spec.description = 'Easy scraper tool based on EventMachine library'
  spec.homepage = 'https://github.com/user1622/em_easy_scraper'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/user1622/em_easy_scraper'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency('activesupport')
  spec.add_dependency('em-files')
  spec.add_dependency('em-hiredis')
  spec.add_dependency('em-http-request')
  spec.add_dependency('promise_em')
  spec.add_dependency('eventmachine')
  spec.add_dependency('http-cookie')

  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.21'
end
