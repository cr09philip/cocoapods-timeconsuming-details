
if Pod::Version == '1.0.0'
	require 'cocoapods_1.0.0-timeconsuming-details.rb'
elsif Pod::Version == '0.39.0'
	require 'cocoapods_0.39.0-timeconsuming-details.rb'
elsif Pod::Version == '0.35.0'
	require 'cocoapods_0.35.0-timeconsuming-details.rb'
end

	