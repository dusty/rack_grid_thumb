Gem::Specification.new do |s|
  s.name = "rack_grid_thumb"
  s.version = "0.0.1"
  s.author = "Dusty Doris"
  s.email = "github@dusty.name"
  s.homepage = "http://github.com/dusty/rack_grid_thumb"
  s.platform = Gem::Platform::RUBY
  s.summary = "Auto-create thumbnails when used with rack_grid"
  s.description = "Auto-create thumbnails when used with rack_grid"
  s.files = [
    "README.txt",
    "lib/rack_grid_thumb.rb",
    "test/test_rack_grid_thumb.rb"
  ]
  s.extra_rdoc_files = ["README.txt"]
  s.add_dependency('mapel')
  s.rubyforge_project = "none"
end