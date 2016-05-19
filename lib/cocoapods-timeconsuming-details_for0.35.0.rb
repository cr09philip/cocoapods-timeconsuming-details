require "cocoapods-timeconsuming-details/version"

module Pod
class Installer

        def timing (title, method, *argv) #method(:method_name)
            
            start_time = Time.new

            if argv and (argv.length != 0)
                method.call(*argv)
            else
              method.call
            end
              
            cost_time = (Time.new.to_f - start_time.to_f)*1000

            # return cost_time.to_i.to_s
            puts title + " cost : #{cost_time.to_i} ms";
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

            timing("=> prepare", method(:prepare));
            timing("=> resolve_dependencies", method(:resolve_dependencies));
            timing("=> download_dependencies", method(:download_dependencies));
            timing("=> generate_pods_project", method(:generate_pods_project));
            timing("=> integrate_user_project", method(:integrate_user_project)) if config.integrate_targets?
            timing("=> perform_post_install_actions", method(:perform_post_install_actions));

            cost_time = (Time.new.to_f - start_time.to_f)*1000;
            puts "\e[32m Total cost : #{cost_time.to_i.to_s} ms \e[0m" ;
        end

        def resolve_dependencies
          UI.section 'Analyzing dependencies' do
            timing("===> analyze", method(:analyze));
            timing("===> validate_build_configurations", method(:validate_build_configurations));
            timing("===> prepare_for_legacy_compatibility", method(:prepare_for_legacy_compatibility));
            timing("===> clean_sandbox", method(:clean_sandbox));
          end
        end

        def download_dependencies
          UI.section 'Downloading dependencies' do
            timing("===> create_file_accessors", method(:create_file_accessors));
            timing("===> install_pod_sources", method(:install_pod_sources));
            timing("===> run_pre_install_hooks", method(:run_pre_install_hooks));
            timing("===> clean_pod_sources", method(:clean_pod_sources));
          end
        end

        def generate_pods_project
          UI.section 'Generating Pods project' do
            timing("===> prepare_pods_project", method(:prepare_pods_project));
            timing("===> install_file_references", method(:install_file_references));
            timing("===> install_libraries", method(:install_libraries));
            timing("===> set_target_dependencies", method(:set_target_dependencies));
            timing("===> run_podfile_post_install_hooks", method(:run_podfile_post_install_hooks));
            timing("===> write_pod_project", method(:write_pod_project));
            timing("===> write_lockfiles", method(:write_lockfiles));
          end
        end


        #-------------------------------------------------------------------------#

        private

        # # Downloads, installs the documentation and cleans the sources of the Pods
        # # which need to be installed.
        # #
        # # @return [void]
        # #
        # def install_pod_sources
        #   @installed_specs = []
        #   pods_to_install = sandbox_state.added | sandbox_state.changed
        #   title_options = { :verbose_prefix => '-> '.green }
        #   root_specs.sort_by(&:name).each do |spec|
        #     if pods_to_install.include?(spec.name)
        #       if sandbox_state.changed.include?(spec.name) && sandbox.manifest
        #         previous = sandbox.manifest.version(spec.name)
        #         title = "Installing #{spec.name} #{spec.version} (was #{previous})"
        #       else
        #         title = "Installing #{spec}"
        #       end
        #       UI.titled_section(title.green, title_options) do
        #         # install_source_of_pod(spec.name)
        #         puts "=====> Installing #{spec.name} cost : " + timing(method(:install_source_of_pod), spec.name) + " ms";
        #       end
        #     else
        #       UI.titled_section("Using #{spec}", title_options)
        #     end
        #   end
        # end

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
          timing("=====> install #{pod_name}", pod_installer.method(:install!));
          # pod_installer.install!
          @pod_installers << pod_installer
          @installed_specs.concat(specs_by_platform.values.flatten.uniq)
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
              # target_installer.install!
              timing("=====> install pod target #{pod_target.name}", target_installer.method(:install!));
            end

            aggregate_targets.sort_by(&:name).each do |target|
              next if target.target_definition.dependencies.empty?
              target_installer = AggregateTargetInstaller.new(sandbox, target)
              # target_installer.install!
              timing("=====> install pod target #{target.name}", target_installer.method(:install!));
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
        #-------------------------------------------------------------------------#
    end
end