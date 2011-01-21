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

task :build => [:deps,:rasterize,:sfx] do
  sh 'coffee -o www/lib -c src test'
end

desc 'build dev sources continuously'
task :watch => [:deps,'www/lib'] do
  sh 'coffee -w -o www/lib -c src test'
end

task :mkDist => [:build, 'dist'] do
  sh 'rsync -auvL --delete www/ dist/www/'
  # NFS doesn't have mod_gzip. See www/.htaccess for the rewrite that tells it to use .gz files
  FileList['dist/www/**/*.{js,html,css}'].each do |f|
    sh "gzip --stdout #{f} > #{f}.gz"
  end
end

desc 'deploy'
task :deployProd => :mkDist do
  account = ENV['NFS_ACCOUNT_NAME']
  sh "rsync -auvL --delete dist/www/ #{account}_touhou@ssh.phx.nearlyfreespeech.net:margatroid/"
end

# http://www.trottercashion.com/2010/10/29/replacing-make-with-rake.html
WAVS = FileList['assets/*.wav']
OGGS = WAVS.ext('.ogg')
task :sfx => OGGS
rule '.ogg' => '.wav' do |t|
  sh "oggenc #{t.source}"
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

# made with sfxr
task :sfx => ['www/lib'] do
  sh 'cp assets/*.ogg www/lib/'
end

task :rasterize => ['www/lib']
SPRITES = %w(livedoll deaddoll bullet alice reimu)
SPRITES.each do |id|
  png = "www/lib/#{id}.png"
  task :rasterize => png
  file png => 'assets/sprite.svg' do
    sh "inkscape assets/sprite.svg --export-png=#{png} --export-id=#{id} --export-id-only"
  end
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
FIREFOX='firefox'
desc 'launch it in firefox'
task :firefox do
  sh "#{FIREFOX} file://`pwd`/www/index.html file://`pwd`/www/test.html &"
end
desc 'launch it fullscreen'
task :fullchromium do
  sh "#{CHROMIUM} --app=file://`pwd`/www/index.html &"
end
