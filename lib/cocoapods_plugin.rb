
if Pod::VERSION == '1.0.0'

	puts "\033[32m hello world 1.0.0 \033[0m"  
	require 'cocoapods_1.0.0-timeconsuming-details.rb'
elsif Pod::VERSION == '0.39.0'

	puts "\033[32m hello world 0.39.0 \033[0m"  
	require 'cocoapods-timeconsuming-details_for0.39.0.rb'
elsif Pod::VERSION == '0.35.0'

	puts "\033[32m hello world 0.35 \033[0m"  
	require 'cocoapods_0.35.0-timeconsuming-details.rb'
end

	