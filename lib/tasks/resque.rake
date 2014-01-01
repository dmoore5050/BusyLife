require 'resque/tasks'

task 'resque:setup' => :environment

Resque.before_fork = Proc.new { ActiveRecord::Base.establish_connection }

desc "Retries the failed jobs and clears the current failed jobs queue at the same time"
task "resque:retry-failed-jobs" => :environment do
  (Resque::Failure.count-1).downto(0).each { |i| Resque::Failure.requeue(i) }; Resque::Failure.clear
end
