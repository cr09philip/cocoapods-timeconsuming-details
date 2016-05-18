require "cocoapods-timeconsuming-details/version"

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

            puts "=> prepare cost : " + timing(method(:prepare)) + " ms";
            puts "=> resolve_dependencies cost : " + timing(method(:resolve_dependencies)) + " ms";
            puts "=> download_dependencies cost : " + timing(method(:download_dependencies)) + " ms";
            puts "=> generate_pods_project cost : " + timing(method(:generate_pods_project)) + " ms";
            puts "=> integrate_user_project cost : " + timing(method(:integrate_user_project)) + " ms" if config.integrate_targets?
            puts "=> perform_post_install_actions cost : " + timing(method(:perform_post_install_actions)) + " ms";

            cost_time = (Time.new.to_f - start_time.to_f)*1000;
            puts "\e[32m Total cost : #{cost_time.to_i.to_s} ms \e[0m" ;
        end

        def resolve_dependencies
          UI.section 'Analyzing dependencies' do
            puts "===> analyze cost : " + timing(method(:analyze)) +" ms";
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
            puts "===> prepare_pods_project cost : " + timing(method(:prepare_pods_project)) + " ms";
            puts "===> install_file_references cost : " + timing(method(:install_file_references)) + " ms";
            puts "===> install_libraries cost : " + timing(method(:install_libraries)) + " ms";
            puts "===> set_target_dependencies cost : " + timing(method(:set_target_dependencies)) + " ms";
            puts "===> run_podfile_post_install_hooks cost : " + timing(method(:run_podfile_post_install_hooks)) + " ms";
            puts "===> write_pod_project cost : " + timing(method(:write_pod_project)) + " ms";
            puts "===> write_lockfiles cost : " + timing(method(:write_lockfiles)) + " ms";
          end
        end


        #-------------------------------------------------------------------------#

        private

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
                # install_source_of_pod(spec.name)
                puts "===> Installing #{spec.name} cost :" + timing(method(:install_source_of_pod), spec.name) + " ms";
              end
            else
              UI.titled_section("Using #{spec}", title_options)
            end
          end
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
              puts "===> install pod target #{target_installer.name} cost : " + timing(target_installer.method(:install!)) + " ms";
            end

            aggregate_targets.sort_by(&:name).each do |target|
              next if target.target_definition.dependencies.empty?
              target_installer = AggregateTargetInstaller.new(sandbox, target)
              puts "===> install aggregate target #{target_installer.name} cost : " + timing(target_installer.method(:install!)) + " ms";
              # target_installer.install!
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