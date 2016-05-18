module Pod
    class Installer
		    def timing (method, *argv) #method(:method_name)
            
            start_time = Time.new

            if argv and (argv.length != 0)
               	method.call(*argv)
            else
            	method.call
            end
            	
            cost_time = (Time.new.to_f - start_time.to_f)*1000

            return cost_time.to_i.to_s
        end

        #-------------------------------------------------------------------------#
        
        # Installs the Pods.
        #
        # The installation process is mostly linear with a few minor complications
        # to keep in mind:
        #
        # - The stored podspecs need to be cleaned before the resolution step
        #   otherwise the sandbox might return an old podspec and not download
        #   the new one from an external source.
        # - The resolver might trigger the download of Pods from external sources
        #   necessary to retrieve their podspec (unless it is instructed not to
        #   do it).
        #
        # @return [void]
        #
        def install!
            start_time = Time.new  

            puts "=> prepare cost : " + timing(method(:prepare)) + "ms";
            puts "=> resolve_dependencies cost : " + timing(method(:resolve_dependencies)) + "ms";
            puts "=> download_dependencies cost : " + timing(method(:download_dependencies)) + "ms";
            puts "=> generate_pods_project cost : " + timing(method(:generate_pods_project)) + "ms";
            puts "=> integrate_user_project cost : " + timing(method(:integrate_user_project)) + "ms"; if config.integrate_targets?
            puts "=> perform_post_install_actions cost : " + timing(method(:perform_post_install_actions)) + "ms";

            cost_time = (Time.new.to_f - start_time.to_f)*1000
            puts "\e[32m Total cost : #{cost_time.to_i.to_s} ms \e[0m"  
        end

        def resolve_dependencies
          UI.section 'Analyzing dependencies' do
            analyze
            validate_build_configurations
            prepare_for_legacy_compatibility
            clean_sandbox
          end
        end

        def download_dependencies
          UI.section 'Downloading dependencies' do
            create_file_accessors
            install_pod_sources
            run_pre_install_hooks
            clean_pod_sources
          end
        end

        def generate_pods_project
          UI.section 'Generating Pods project' do
            prepare_pods_project
            install_file_references
            install_libraries
            set_target_dependencies
            run_podfile_post_install_hooks
            write_pod_project
            write_lockfiles
          end
        end

        #-------------------------------------------------------------------------#

        private

        # @!group Installation steps

        # @return [void]
        #
        # @note   The warning about the version of the Lockfile doesn't use the
        #         `UI.warn` method because it prints the output only at the end
        #         of the installation. At that time CocoaPods could have crashed.
        #
        def analyze
          if lockfile && lockfile.cocoapods_version > Version.new(VERSION)
            STDERR.puts '[!] The version of CocoaPods used to generate ' \
              "the lockfile (#{lockfile.cocoapods_version}) is "\
              "higher than the version of the current executable (#{VERSION}). " \
              'Incompatibility issues may arise.'.yellow
          end

          analyzer = Analyzer.new(sandbox, podfile, lockfile)
          analyzer.update = update
          @analysis_result = analyzer.analyze
          @aggregate_targets = analyzer.result.targets
        end

        # Downloads, installs the documentation and cleans the sources of the Pods
        # which need to be installed.
        #
        # @return [void]
        #
        def install_pod_sources
          @installed_specs = []
          pods_to_install = sandbox_state.added | sandbox_state.changed
          title_options = { :verbose_prefix => '-> '.green }
          root_specs.sort_by(&:name).each do |spec|
            if pods_to_install.include?(spec.name)
              if sandbox_state.changed.include?(spec.name) && sandbox.manifest
                previous = sandbox.manifest.version(spec.name)
                title = "Installing #{spec.name} #{spec.version} (was #{previous})"
              else
                title = "Installing #{spec}"
              end
              UI.titled_section(title.green, title_options) do
                install_source_of_pod(spec.name)
              end
            else
              UI.titled_section("Using #{spec}", title_options)
            end
          end
        end

        # Install the Pods. If the resolver indicated that a Pod should be
        # installed and it exits, it is removed an then reinstalled. In any case if
        # the Pod doesn't exits it is installed.
        #
        # @return [void]
        #
        def install_source_of_pod(pod_name)
          specs_by_platform = {}
          pod_targets.each do |pod_target|
            if pod_target.root_spec.name == pod_name
              specs_by_platform[pod_target.platform] ||= []
              specs_by_platform[pod_target.platform].concat(pod_target.specs)
            end
          end

          @pod_installers ||= []
          pod_installer = PodSourceInstaller.new(sandbox, specs_by_platform)
          pod_installer.install!
          @pod_installers << pod_installer
          @installed_specs.concat(specs_by_platform.values.flatten.uniq)
        end

        # Cleans the sources of the Pods if the config instructs to do so.
        #
        # @todo Why the @pod_installers might be empty?
        #
        def clean_pod_sources
          return unless config.clean?
          return unless @pod_installers
          @pod_installers.each(&:clean!)
        end

        # Performs any post-installation actions
        #
        # @return [void]
        #
        def perform_post_install_actions
          run_plugins_post_install_hooks
          warn_for_deprecations
        end

        # Runs the registered callbacks for the plugins post install hooks.
        #
        def run_plugins_post_install_hooks
          context = HooksContext.generate(sandbox, aggregate_targets)
          HooksManager.run(:post_install, context)
        end

        # Creates the Pods project from scratch if it doesn't exists.
        #
        # @return [void]
        #
        # @todo   Clean and modify the project if it exists.
        #
        def prepare_pods_project
          UI.message '- Creating Pods project' do
            @pods_project = Pod::Project.new(sandbox.project_path)

            analysis_result.all_user_build_configurations.each do |name, type|
              @pods_project.add_build_configuration(name, type)
            end

            pod_names = pod_targets.map(&:pod_name).uniq
            pod_names.each do |pod_name|
              local = sandbox.local?(pod_name)
              path = sandbox.pod_dir(pod_name)
              was_absolute = sandbox.local_path_was_absolute?(pod_name)
              @pods_project.add_pod_group(pod_name, path, local, was_absolute)
            end

            if config.podfile_path
              @pods_project.add_podfile(config.podfile_path)
            end

            sandbox.project = @pods_project
            platforms = aggregate_targets.map(&:platform)
            osx_deployment_target = platforms.select { |p| p.name == :osx }.map(&:deployment_target).min
            ios_deployment_target = platforms.select { |p| p.name == :ios }.map(&:deployment_target).min
            @pods_project.build_configurations.each do |build_configuration|
              build_configuration.build_settings['MACOSX_DEPLOYMENT_TARGET'] = osx_deployment_target.to_s if osx_deployment_target
              build_configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = ios_deployment_target.to_s if ios_deployment_target
              build_configuration.build_settings['STRIP_INSTALLED_PRODUCT'] = 'NO'
              build_configuration.build_settings['CLANG_ENABLE_OBJC_ARC'] = 'YES'
            end
          end
        end

        # Installs the file references in the Pods project. This is done once per
        # Pod as the same file reference might be shared by multiple aggregate
        # targets.
        #
        # @return [void]
        #
        def install_file_references
          installer = FileReferencesInstaller.new(sandbox, pod_targets, pods_project)
          installer.install!
        end

        # Installs the aggregate targets of the Pods projects and generates their
        # support files.
        #
        # @return [void]
        #
        def install_libraries
          UI.message '- Installing targets' do
            pod_targets.sort_by(&:name).each do |pod_target|
              next if pod_target.target_definition.dependencies.empty?
              target_installer = PodTargetInstaller.new(sandbox, pod_target)
              target_installer.install!
            end

            aggregate_targets.sort_by(&:name).each do |target|
              next if target.target_definition.dependencies.empty?
              target_installer = AggregateTargetInstaller.new(sandbox, target)
              target_installer.install!
            end

            # TODO
            # Move and add specs
            pod_targets.sort_by(&:name).each do |pod_target|
              pod_target.file_accessors.each do |file_accessor|
                file_accessor.spec_consumer.frameworks.each do |framework|
                  pod_target.native_target.add_system_framework(framework)
                end
              end
            end
          end
        end

        def set_target_dependencies
          aggregate_targets.each do |aggregate_target|
            aggregate_target.pod_targets.each do |pod_target|
              aggregate_target.native_target.add_dependency(pod_target.native_target)
              pod_target.dependencies.each do |dep|

                unless dep == pod_target.pod_name
                  pod_dependency_target = aggregate_target.pod_targets.find { |target| target.pod_name == dep }
                  # TODO remove me
                  unless pod_dependency_target
                    puts "[BUG] DEP: #{dep}"
                  end
                  pod_target.native_target.add_dependency(pod_dependency_target.native_target)
                end
              end
            end
          end
        end

        #-------------------------------------------------------------------------#

    end
end