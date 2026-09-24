# frozen_string_literal: true

$LOAD_PATH << File.expand_path('../lib', __dir__)

require 'logger'
require 'restify'
require 'base64'

headers = {}

Restify.logger = Logger.new($stdout, level: :debug) if ENV['LOGGING']

if (token = ENV.fetch('GITHUB_TOKEN', nil))
  headers['Authorization'] = "Bearer #{token}"
end

gh    = Restify.new('https://api.github.com', headers:).get.value!
user  = gh.rel(:user).get({user: 'jgraichen'}).value!
repos = user.rel(:repos).get.value!

commits = repos.map do |repo|
  [repo, repo.rel(:commits).get]
end

commits.map! do |repo, cmts|
  [repo, cmts.value!]
end

commits.each do |repo, cmts|
  head = cmts.first

  puts "==== #{repo['name']} ===="
  puts "Last commit: #{head['sha']}"
  puts "By #{head['commit']['author']['name']} <#{head['commit']['author']['email']}>"
  puts head['commit']['message']
  puts
end
