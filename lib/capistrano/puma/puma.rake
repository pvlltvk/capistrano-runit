require "erb"

namespace :runit do
  namespace :puma do
    task :map_bins do
      if Rake::Task.task_defined?("bundler:map_bins")
        fetch(:bundle_bins).push "puma"
      end
      if Rake::Task.task_defined?("rbenv:map_bins")
        fetch(:rbenv_map_bins).push "puma"
      end
    end

    if Rake::Task.task_defined?("bundler:map_bins")
      before "bundler:map_bins", "runit:puma:map_bins"
    end
    if Rake::Task.task_defined?("rbenv:map_bins")
      before "rbenv:map_bins", "runit:puma:map_bins"
    end

    desc "Setup puma runit service"
    task :setup do
      # requirements
      if fetch(:runit_puma_bind).nil?
        $stderr.puts "You should set 'runit_puma_bind' variable."
        exit 1
      end

      on roles(:app) do |host|
        if test "[ ! -d #{deploy_to}/runit/available/puma-#{fetch(:application)} ]"
          execute :mkdir, "-v", "#{deploy_to}/runit/available/puma-#{fetch(:application)}"
        end
        if test "[ ! -d #{shared_path}/tmp/puma ]"
          execute :mkdir, "-v", "#{shared_path}/tmp/puma"
        end
        run_template_path = fetch(:runit_puma_run_template)
        if !run_template_path.nil? && File.exist?(run_template_path)
          run_template = ERB.new(File.read(run_template_path))
          run_stream = StringIO.new(run_template.result(binding))
          upload! run_stream, "#{deploy_to}/runit/available/puma-#{fetch(:application)}/run"
          execute :chmod, "0755", "#{deploy_to}/runit/available/puma-#{fetch(:application)}/run"
        else
          error "Template from 'runit_puma_run_template' variable isn't found: #{run_template_path}"
        end

	config_template_path = fetch(:runit_puma_config_template)
	if !config_template_path.nil? && File.exist?(config_template_path)
          config_template = ERB.new(File.read(config_template_path))
          config_stream = StringIO.new(config_template.result(binding))
          upload! config_stream, "#{deploy_to}/runit/puma.rb"
        else
          error "Template from 'config_puma_template' variable isn't found: #{config_template_path}"
        end

      end
    end

    desc "Change puma config"
    task :change_config do
      on roles(:app) do |host|
        if test "[ -f #{deploy_to}/runit/puma.rb ]"
          execute :rm, "-f", "{deploy_to}/runit/puma.rb}"
          config_template_path = fetch(:runit_puma_config_template)
          if !config_template_path.nil? && File.exist?(config_template_path)
            config_template = ERB.new(File.read(config_template_path))
            config_stream = StringIO.new(config_template.result(binding))
            upload! config_stream, "#{deploy_to}/runit/puma.rb"
          else
            error "Template from 'config_puma_template' variable isn't found: #{config_template_path}"
          end
        else
          error "Puma config isn't found. You should run runit:puma:setup."
        end
      end
    end

    desc "Enable puma runit service"
    task :enable do
      on roles(:app) do |host|
        if test "[ -d #{deploy_to}/runit/available/puma-#{fetch(:application)} ]"
          within "#{deploy_to}/runit/enabled" do
            execute :ln, "-sf", "../available/puma-#{fetch(:application)}", "puma-#{fetch(:application)}"
	    execute :ln, "-sf", "#{deploy_to}/runit/available/puma-#{fetch(:application)}", "/etc/service/"
          end
        else
          error "Puma runit service isn't found. You should run runit:puma:setup."
        end
      end
    end

    desc "Disable puma runit service"
    task :disable do
      invoke "runit:puma:stop"
      on roles(:app) do
        if test "[ -d #{deploy_to}/runit/enabled/puma-#{fetch(:application)} ]"
          execute :rm, "-f", "#{deploy_to}/runit/enabled/puma-#{fetch(:application)}"
	  execute :rm, "-f", "/etc/service/puma-#{fetch(:application)}"
        else
          error "Puma runit service isn't enabled."
        end
      end
    end

    %w[start stop restart status].each do |command|
    desc "#{command} Puma server."
    task command do
      on roles(:app) do
        if test "[ -d #{deploy_to}/runit/enabled/puma-#{fetch(:application)} ]"
          execute :sv, "#{command}", "puma-#{fetch(:application)}"
        else
          error "Puma runit service isn't enabled."
        end
      end
    end

    desc "Run phased restart puma runit service"
    task :phased_restart do
      on roles(:app) do
        if test "[ -d #{deploy_to}/runit/enabled/puma-#{fetch(:application)} ]"
          execute :sv, "1", "puma-#{fetch(:application)}"
        else
          error "Puma runit service isn't enabled."
        end
      end
    end
  end
end

namespace :load do
  task :defaults do
    set :runit_puma_run_template, File.expand_path("../run-puma.erb", __FILE__)
    set :runit_puma_config_template, File.expand_path("../puma.erb", __FILE__)
    set :runit_puma_workers, 1
    set :runit_puma_threads_min, 0
    set :runit_puma_threads_max, 16
    set :runit_puma_bind, nil
  end
end
