# frozen_string_literal: true

$LOAD_PATH << File.expand_path('../lib', __dir__)

require 'logger'
require 'restify'

Restify.logger = Logger.new($stdout, level: :debug) if ENV['LOGGING']

if (token = ENV.fetch('GITHUB_TOKEN', nil))
  headers['Authorization'] = "Bearer #{token}"
end

gh   = Restify.new('https://api.github.com', headers:).get.value
repo = gh.rel(:repository).get({owner: 'jgraichen', repo: 'restify'}).value
cmt  = repo.rel(:commits).get.value.first

puts "Last commit: #{cmt['sha']}"
puts "By #{cmt['commit']['author']['name']} <#{cmt['commit']['author']['email']}>"
puts cmt['commit']['message']
