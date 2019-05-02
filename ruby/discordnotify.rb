#!/usr/bin/env ruby
require 'bundler/inline'
require 'bundler'
Bundler.configure
gemfile do
  source 'https://rubygems.org'
  gem 'discordrb-webhooks'
end

if ARGV.include?('--help') || ARGV.include?('-h') || ARGV.empty? || (ARGV.length > 2)
  puts 'Usage: notify.rb <message> <username>'
  puts 'Username is optional'
else
  client = Discordrb::Webhooks::Client.new url: 'URL' # Add the webhook URL 
  here
  builder = Discordrb::Webhooks::Builder.new content: ARGV[0], username: ARGV[1]
  client.execute builder
end

