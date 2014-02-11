set :application, "my.busylife.co"
set :repo_url, "git@github.com:ProvidentVentures/BusyLife.git"
set :branch, "master"

set :deploy_to, "/var/www/my.busylife.co/"
set :scm, :git
set :user, "bl_deployer"
set :rails_env, "production"
set :deploy_via, :copy

set :rbenv_ruby, '2.0.0-p353'
set :rbenv_type, :user
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w{rake gem bundle ruby rails}
set :rbenv_roles, :all

# set :format, :pretty
# set :log_level, :debug
# set :pty, true

# set :linked_files, %w{config/database.yml}
# set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# set :default_env, { path: "/opt/ruby/bin:$PATH" }
set :keep_releases, 5

namespace :deploy do

  role :app, %{bl_deployer@mylifebook.com}
  task :restart do
    on roles(:app) do
      execute :mkdir, "#{current_path}/tmp"
      execute :touch, "#{current_path}/tmp/restart.txt"
    end
  end

  role :app, %{bl_deployer@mylifebook.com}
  task :setup_config do
    on roles(:app) do
      execute :sudo, "ln -nfs #{current_path}/config/apache.conf /etc/apache2/sites-available/my.busylife.co.conf"
    end
  end
  after 'deploy', 'deploy:setup_config'

  desc "Make sure local git is in sync with remote."
  role :web, %w{bl_deployer@mylifebook.com}
  task :check_revision do
    on roles(:web) do
      unless `git rev-parse HEAD` == `git rev-parse origin/master`
        puts "WARNING: HEAD is not the same as origin/master"
        puts "Run `git push` to sync changes."
        exit
      end
    end
  end
  before "deploy", "deploy:check_revision"

  after :finishing, 'deploy:cleanup'

end
