# frozen_string_literal: true

$LOAD_PATH << File.expand_path('../lib', __dir__)

require 'restify'
require 'base64'

require 'pry'

headers = {}

if ENV['LOGGING']
  Logging.logger.root.add_appenders Logging.appenders.stdout
  Logging.logger.root.level = :debug
end

if (token = ENV.fetch('GITHUB_TOKEN', nil))
  headers['Authorization'] = "Bearer #{token}"
end

# Do not use deprecated indifferent access
Restify::Processors::Json.indifferent_access = false

gh    = Restify.new('https://api.github.com', headers: headers).get.value!
user  = gh.rel(:user).get(user: 'jgraichen').value!
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
