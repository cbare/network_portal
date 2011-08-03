set :application, "network_portal"
set :repository,  "git://github.com/cbare/network_portal.git"

set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

role :web, "bragi"                          # Your HTTP server, Apache/etc
role :app, "bragi"                          # This may be the same as your `Web` server
role :db,  "bragi", :primary => true # This is where Rails migrations will run
# role :db,  "your slave db-server here"

set :deploy_to, "/local/rails_apps/network_portal"
set :deploy_via, :checkout

set :use_sudo, false


# If you are using Passenger mod_rails uncomment this:
# if you're still using the script/reapear helper you will need
# these http://github.com/rails/irs_process_scripts

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end

# after "deploy:update_code", :fixup
# 
# task :fixup do
#   run "mv #{release_path}/config/initializers/mongo.rb.example #{release_path}/config/initializers/mongo.rb"
# end
