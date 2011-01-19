require 'rake/clean'

CLEAN.include('dist').include('www/lib')
CLOBBER.include('dist').include('www/lib')

directory 'dist'
directory 'www/lib'

desc 'build dependencies'
task :deps => ['www/lib'] do
  FileList['deps/*'].each do |f|
    sh "ln -sf ../../#{f} www/lib"
  end
end

desc 'build dev sources continuously'
task :watch => [:deps,'www/lib'] do
  sh 'coffee -w -o www/lib -c src test'
end

desc 'run emacs for devel'
task :emacs do
  sh 'emacs todo `find www/ -type f -and \( -name "*.html" -o -name "*.css" \)` `find src test -type f` &'
end

desc 'graphics editing'
task :inkscape do
  sh 'inkscape www/sprite.svg &'
end

desc 'render assets'
task :assets => [:rasterize,:sfx]

task :sfx => ['www/lib'] do
  sh 'cp assets/*.ogg www/lib/'
end

task :rasterize => ['www/lib'] do
  sh 'inkscape assets/sprite.svg --export-png=www/lib/livedoll.png --export-id=livedoll --export-id-only'
  sh 'inkscape assets/sprite.svg --export-png=www/lib/deaddoll.png --export-id=deaddoll --export-id-only'
  sh 'inkscape assets/sprite.svg --export-png=www/lib/bullet.png --export-id=bullet --export-id-only'
  sh 'inkscape assets/sprite.svg --export-png=www/lib/alice.png --export-id=alice --export-id-only'
  sh 'inkscape assets/sprite.svg --export-png=www/lib/reimu.png --export-id=reimu --export-id-only'
end

desc 'line count of sources'
task :wc do
  sh 'wc -l `find src -type f`; wc -l `find test -type f`'
end

CHROMIUM='chromium-browser --allow-file-access-from-files --disable-web-security --user-data-dir=`mktemp -d /tmp/tmp.XXXXXXXXXXXX` --no-first-run'
desc 'launch it in chromium'
task :chromium do
  #sh 'chromium-browser --allow-file-access-from-files --user-data-dir=`mktemp -d /tmp/tmp.XXXXXXXXXXXX` --no-first-run --app file://`pwd`/www/index.html &'
  # allow-file-access-from-files: make img/css/script includes work locally (i think)
  # disable-web-security: ignore cors/same-origin-policy, to allow couchdb access from file:// without couchdb deployment
  sh "#{CHROMIUM} file://`pwd`/www/index.html file://`pwd`/www/test.html &"
end
desc 'launch it fullscreen'
task :fullchromium do
  sh "#{CHROMIUM} --app=file://`pwd`/www/index.html &"
end
