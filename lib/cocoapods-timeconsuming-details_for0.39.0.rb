
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
  			puts '=> prepare cost : ' + timing(method(:prepare)) + ' ms';
  			puts '=> resolve_dependencies cost : ' + timing(method(:resolve_dependencies)) + ' ms';
  			puts '=> download_dependencies cost : ' + timing(method(:download_dependencies)) + ' ms';
  			puts '=> determine_dependency_product_types cost : ' + timing(method(:determine_dependency_product_types)) + ' ms';
  			puts '=> verify_no_duplicate_framework_names cost : ' + timing(method(:verify_no_duplicate_framework_names)) + ' ms';
  			puts '=> verify_no_static_framework_transitive_dependencies cost : ' + timing(method(:verify_no_static_framework_transitive_dependencies)) + ' ms';
  			puts '=> verify_framework_usage cost : ' + timing(method(:verify_framework_usage)) + ' ms';
  			puts '=> generate_pods_project cost : ' + timing(method(:generate_pods_project)) + ' ms';
  			puts '=> integrate_user_project cost : ' + timing(method(:integrate_user_project)) + ' ms' if config.integrate_targets?
  			puts '=> perform_post_install_actions cost : ' + timing(method(:perform_post_install_actions)) + ' ms';
			
			cost_time = (Time.new.to_f - start_time.to_f)*1000
  			puts "\e[32m Total cost : #{cost_time.to_i.to_s} ms\e[0m"  
	    end

	    def resolve_dependencies
	      analyzer = create_analyzer

	      plugin_sources = run_source_provider_hooks
	      analyzer.sources.insert(0, *plugin_sources)

	      UI.section 'Updating local specs repositories' do
	        puts "===> analyzer.update_repositories cost : " + timing(analyzer.method(:update_repositories)) + " ms";
	      end unless config.skip_repo_update?

	      UI.section 'Analyzing dependencies' do
	        puts '===> analyze(analyzer) cost : ' + timing(method(:analyze), analyzer) + ' ms';
	        puts '===> validate_build_configurations cost : ' + timing(method(:validate_build_configurations)) + ' ms';
	        puts '===> prepare_for_legacy_compatibility cost : ' + timing(method(:prepare_for_legacy_compatibility)) + ' ms';
	        puts '===> clean_sandbox cost : ' + timing(method(:clean_sandbox)) + ' ms';
	      end
	    end

	    def download_dependencies
	      UI.section 'Downloading dependencies' do
	        puts '===> create_file_accessors cost : ' + timing(method(:create_file_accessors)) + ' ms';
	        puts '===> install_pod_sources cost : ' + timing(method(:install_pod_sources)) + ' ms';
	        puts '===> run_podfile_pre_install_hooks cost : ' + timing(method(:run_podfile_pre_install_hooks)) + ' ms';
	        puts '===> clean_pod_sources cost : ' + timing(method(:clean_pod_sources)) + ' ms';
	      end
	    end

	    def generate_pods_project
	      UI.section 'Generating Pods project' do
	        puts '===> prepare_pods_project cost : ' + timing(method(:prepare_pods_project)) + ' ms';
	        puts '===> install_file_references cost : ' + timing(method(:install_file_references)) + ' ms';
	        puts '===> install_libraries cost : ' + timing(method(:install_libraries)) + ' ms';
	        puts '===> set_target_dependencies cost : ' + timing(method(:set_target_dependencies)) + ' ms';
	        puts '===> run_podfile_post_install_hooks cost : ' + timing(method(:run_podfile_post_install_hooks)) + ' ms';
	        puts '===> write_pod_project cost : ' + timing(method(:write_pod_project)) + ' ms';
	        puts '===> share_development_pod_schemes cost : ' + timing(method(:share_development_pod_schemes)) + ' ms';
	        puts '===> write_lockfiles cost : ' + timing(method(:write_lockfiles)) + ' ms';
	      end
	    end

	    #-------------------------------------------------------------------------#

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
	            puts "=====> Install #{spec} cost : " + timing(method(:install_source_of_pod), spec.name) + " ms";
	            # install_source_of_pod(spec.name)
	          end
	        else
	          UI.titled_section("Using #{spec}", title_options) do
	            puts "=====> Using #{spec} cost : " + timing(method(:create_pod_installer), spec.name) + " ms";
	            # create_pod_installer(spec.name)
	          end
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
	          next if pod_target.target_definitions.flat_map(&:dependencies).empty?
	          target_installer = PodTargetInstaller.new(sandbox, pod_target)
	          puts "=====> install pod target #{pod_target.name} cost : " + timing(target_installer.method(:install!)) + " ms";
	        end

	        aggregate_targets.sort_by(&:name).each do |target|
	          next if target.target_definition.dependencies.empty?
	          target_installer = AggregateTargetInstaller.new(sandbox, target)
	          puts "=====> install aggregate target #{target.name} cost : " + timing(target_installer.method(:install!)) + " ms";
	        end

	        # TODO: Move and add specs
	        pod_targets.sort_by(&:name).each do |pod_target|
	          pod_target.file_accessors.each do |file_accessor|
	            file_accessor.spec_consumer.frameworks.each do |framework|
	              if pod_target.should_build?
	                pod_target.native_target.add_system_framework(framework)
	              end
	            end
	          end
	        end
	      end
	    end
	    #-------------------------------------------------------------------------#
	end #of class 
end #of module