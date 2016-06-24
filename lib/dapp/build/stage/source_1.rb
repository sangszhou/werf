module Dapp
  module Build
    module Stage
      class Source1 < SourceBase
        def initialize(build, relative_stage)
          @prev_stage = Source1Archive.new(build, self)
          super
        end

        def prev_source_stage
          prev_stage
        end

        protected

        def dependencies_checksum
          hashsum [prev_stage.signature,
                   dependency_file, dependency_file_regex,
                   *build.app_install_checksum]
        end

        private

        def dependency_file
          @dependency_file ||= begin
            file_path = Dir[build.build_path('*')].detect {|x| x =~ dependency_file_regex }
            File.read(file_path) unless file_path.nil?
          end
        end

        def dependency_file?
          !dependency_file.nil?
        end

        def dependency_file_regex
          /.*\/(Gemfile|composer.json|requirement_file.txt)$/
        end
      end # Source1
    end # Stage
  end # Build
end # Dapp
