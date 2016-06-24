module Dapp
  class Config
    include CommonHelper

    attr_reader :home_branch

    class << self
      def default_opts
        @default_opts ||= {}
      end

      def dappfiles_paths(path, pattern = '*')
        pattern.split('-').instance_eval { count.downto(1).map { |n| slice(0, n).join('-') } }
            .map { |p| Dir.glob(File.join([path, p, default_opts[:dappfile_name] || 'Dappfile'].compact)) }.find(&:any?) || []
      end

      def process_directory(path, pattern = '*')
        dappfiles_paths(path, pattern).map { |dappfile_path| process_file(dappfile_path, app_filter: pattern) }.flatten
      end

      def process_file(dappfile_path, app_filter: '*')
        conf = new(dappfile_path: dappfile_path, app_filter: app_filter) do |build_conf|
          build_conf.log "Processing dappfile '#{dappfile_path}'"

          # indent all subsequent messages
          build_conf.indent_log

          # eval instructions from file
          build_conf.instance_eval File.read(dappfile_path), dappfile_path
        end
        conf.to_a
      end
    end

    def initialize(**options, &block)
      opts.merge! self.class.default_opts
      opts.merge! options

      # default log indentation
      opts[:log_indent] = 0

      # basename
      if opts[:name]
        opts[:basename] = opts[:name]
        opts[:name] = nil
      elsif opts[:dappfile_path]
        opts[:basename] ||= Pathname.new(opts[:dappfile_path]).expand_path.parent.basename
      end

      # home path
      opts[:home_path] ||= Pathname.new(opts[:dappfile_path] || 'fakedir').parent.expand_path.to_s

      # home branch
      @home_branch = shellout("git -C #{home_path} rev-parse --abbrev-ref HEAD").stdout.strip

      self.instance_eval(&block)
    end

    def log(message)
      puts ' ' * opts[:log_indent] + ' * ' + message if opts[:log_verbose] || !opts[:log_quiet]
    end

    def indent_log
      opts[:log_indent] += 1
    end

    def to_a
      apps_to_build.empty? ? [to_h] : apps_to_build.map(&:to_h).compact
    end

    def to_h
      unless !opts[:app_filter] || File.fnmatch("#{opts[:app_filter]}*", name)
        log "Skipped (does not match filter: '#{opts[:app_filter]}')!"
        return
      end
      log "Prepared application config '#{name}'"
      { name: name, type: type }.merge(opts.select { |k, _v| [:from_name, :home_path, :dapps, :exposes, :git_artifact,
                                                              :infra_install, :infra_setup, :app_install, :app_setup].include?(k) } )
    end

    protected

    def home_path(*path)
      path.compact.inject(Pathname.new(opts[:home_path]), &:+).expand_path.to_s
    end

    def save_opt(opt, *args)
      opts[opt] ||= []
      opts[opt] += args.flatten
    end

    def opts
      @opts ||= {}
    end

    def apps
      @apps ||= []
    end

    def apps_to_build
      apps.map { |app| app.apps.empty? ? app : app.apps }.flatten
    end

    def name
      [opts[:basename], opts[:name]].compact.join '-'
    end

    def docker # TODO
      self
    end

    # TODO => exposes
    def expose(*args)
      save_opt(:exposes, *args)
    end

    # TODO => from
    def from_centos7
      opts[:from] = :'centos:7'
    end

    def from_ubuntu1404
      opts[:from_name] = :'ubuntu:14.04'
    end

    def from_ubuntu1604
      opts[:from] = :'ubuntu:16.04'
    end

    # TODO => dapps
    def dappit(*args)
      save_opt(:dapps, *args)
    end

    [:infra_install, :infra_setup, :app_install, :app_setup].each do |m|
      define_method(m) do |*args|
        raise "instruction '#{m}' only supported for 'shell' type!" unless opts[:type] == :shell
        save_opt(m, *args)
      end
    end

    # TODO => git_artifact
    def add_git_artifact(where_to_add, **kwargs)
      opts[:git_artifact] ||= {}
      opts[:git_artifact][:local] = {
          where_to_add: where_to_add,
          cwd: kwargs[:cwd] || '/',
          paths: kwargs[:paths],
          owner: kwargs[:owner],
          group: kwargs[:group],
          interlayer_period: interlayer_period(:week)
      }
    end

    # TODO => remote_git_artifact
    def add_remote_git_artifact(url, where_to_add, branch: opts[:git_artifact_branch] || home_branch, ssh_key_path: nil, **kwargs)
      opts[:git_artifact] ||= {}
      opts[:git_artifact][:remote] ||= []
      opts[:git_artifact][:remote] << {
          url: url,
          name: url.gsub(%r{.*?([^\/ ]+)\.git}, '\\1'), # extract git repo name from url
          branch: branch,
          ssh_key_path: ssh_key_path,
          where_to_add: where_to_add,
          cwd: kwargs[:cwd] || '/',
          paths: kwargs[:paths],
          owner: kwargs[:owner],
          group: kwargs[:group],
          interlayer_period: interlayer_period(:week)
      }
    end

    def interlayer_period(period)
      case period
        when :day then 60*60*24
        when :week then interlayer_period(:day)*7
        when :month then interlayer_period(:week)*7
        else nil
      end
    end

    def app(name, &block)
      name = "#{send(:name)}-#{name}"
      options = opts.merge(name: name, basename: name, log_indent: opts[:log_indent] + 1)
      apps << self.class.new(**options, &block)
    end

    def type
      opts[:type]
    end

    def build_dapp(*args, extra_dapps: [], **kwargs, &blk)
      dappit(*extra_dapps)
    end
  end
end
