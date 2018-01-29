Gem::Specification.new { |s|
	s.platform = Gem::Platform::RUBY

	s.authors = ["Pete Elmore"]
	s.email = ["pete@tenka.io"]
	s.files = Dir["{lib,doc,bin,ext}/**/*"].delete_if {|f|
		/\/rdoc(\/|$)/i.match f
	} + %w(Rakefile)
	s.require_path = 'lib'
	s.has_rdoc = true
	s.extra_rdoc_files = (Dir['doc/*'] << 'README').select(&File.method(:file?))
	s.extensions << 'ext/extconf.rb' if File.exist? 'ext/extconf.rb'
	Dir['bin/*'].map(&File.method(:basename)).map(&s.executables.method(:<<))

	s.name = 'tenka'
	s.summary = "A client for Tenka's REST API."
	s.description = <<-EOS.gsub(/^\t+/, '')
		Tenka is a REST API that lets you do GIS operations.  It makes it easy
		to add intelligence about the earth to your applications.
	EOS
	s.homepage = "https://github.com/tenka/tenka-client-ruby"

	s.version = '1.0.1'
	s.platform = Gem::Platform::RUBY
	s.required_ruby_version = '>= 2.2.0'
	s.license = 'MIT'
	[
		['json', '~> 0'],
	].each { |a| s.add_runtime_dependency *a }
}
