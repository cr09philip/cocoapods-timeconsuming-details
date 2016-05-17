require "cocoapods/timeconsuming/details/version"

if Pod::VERSION == '0.39.0'
	module Pod
		class Installer
						
			def timing (method，*args) #method(:method_name)
                
                start_time = Time.new

                method.call(args)

                cost_time = (Time.new.to_f - start_time.to_f)*1000

                return cost_time.to_i.to_s
        	end

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
      			puts 'prepare cost : ' + timing(method(:prepare)) + ' ms';
      			puts 'resolve_dependencies cost : ' + timing(method(:resolve_dependencies)) + ' ms';
      			puts 'download_dependencies cost : ' + timing(method(:download_dependencies)) + ' ms';
      			puts 'determine_dependency_product_types cost : ' + timing(method(:determine_dependency_product_types)) + ' ms';
      			puts 'verify_no_duplicate_framework_names cost : ' + timing(method(:verify_no_duplicate_framework_names)) + ' ms';
      			puts 'verify_no_static_framework_transitive_dependencies cost : ' + timing(method(:verify_no_static_framework_transitive_dependencies)) + ' ms';
      			puts 'verify_framework_usage cost : ' + timing(method(:verify_framework_usage)) + ' ms';
      			puts 'generate_pods_project cost : ' + timing(method(:generate_pods_project)) + ' ms';
      			puts 'integrate_user_project cost : ' + timing(method(:integrate_user_project)) + ' ms' if config.integrate_targets?
      			puts 'perform_post_install_actions cost : ' + timing(method(:perform_post_install_actions)) + ' ms';
    		end
			
    		def prepare
      			UI.message 'Preparing' do
        			sandbox.prepare
        			ensure_plugins_are_installed!
        			Migrator.migrate(sandbox)
        			run_plugins_pre_install_hooks
      			end
    		end

    		def resolve_dependencies
      			analyzer = create_analyzer

      			plugin_sources = run_source_provider_hooks
      			analyzer.sources.insert(0, *plugin_sources)

      			UI.section 'Updating local specs repositories' do
      				analyzer.update_repositories
      			end unless config.skip_repo_update?

      			UI.section 'Analyzing dependencies' do
        			analyze(analyzer)
        			validate_build_configurations
        			prepare_for_legacy_compatibility
        			clean_sandbox
      			end
    		end

    		def download_dependencies
      			UI.section 'Downloading dependencies' do
        			create_file_accessors
        			install_pod_sources
        			run_podfile_pre_install_hooks
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
			        share_development_pod_schemes
			        write_lockfiles
		      	end
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
			          	UI.titled_section("Using #{spec}", title_options) do
			            	create_pod_installer(spec.name)
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
			          	target_installer.method(:install!)
			        end

			        aggregate_targets.sort_by(&:name).each do |target|
			          	next if target.target_definition.dependencies.empty?
			          	target_installer = AggregateTargetInstaller.new(sandbox, target)
			          	target_installer.install!
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
		end #of class 
	end #of module
end #of if 
