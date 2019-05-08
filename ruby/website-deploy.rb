#!/usr/bin/env ruby
require 'bundler/inline'
require 'bundler'
Bundler.configure
gemfile do
  source 'https://rubygems.org'
  gem 'discordrb-webhooks'
  gem 'sinatra'
  gem 'json'
end
set :port, 80443
post '/payload' do
    request.body.rewind
    payload_body = request.body.read
    verify_signature(payload_body)
    push = JSON.parse(params[:payload])
    "I got some JSON: #{push.inspect}"
  end
  
  def verify_signature(payload_body)
    signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['SECRET_TOKEN'], payload_body)
    return halt 500, "Signatures didn't match!" unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
  end
  