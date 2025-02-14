# frozen_string_literal: true

$LOAD_PATH << File.expand_path('../lib', __dir__)

require 'restify'

if ENV['LOGGING']
  Logging.logger.root.add_appenders Logging.appenders.stdout
  Logging.logger.root.level = :debug
end

if (token = ENV.fetch('GITHUB_TOKEN', nil))
  headers['Authorization'] = "Bearer #{token}"
end

gh   = Restify.new('https://api.github.com', headers:).get.value
repo = gh.rel(:repository).get(owner: 'jgraichen', repo: 'restify').value
cmt  = repo.rel(:commits).get.value.first

puts "Last commit: #{cmt['sha']}"
puts "By #{cmt['commit']['author']['name']} <#{cmt['commit']['author']['email']}>"
puts cmt['commit']['message']
