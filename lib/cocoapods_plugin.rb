require "cocoapods-timeconsuming-details/version"

if Pod::VERSION == '1.0.0'
	require 'cocoapods-timeconsuming-details_for1.0.0.rb'
elsif Pod::VERSION == '0.39.0'
	require 'cocoapods-timeconsuming-details_for0.39.0.rb'
elsif Pod::VERSION == '0.35.0'
	require 'cocoapods-timeconsuming-details_for0.35.0.rb'
end

	