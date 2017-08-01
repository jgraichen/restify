# frozen_string_literal: true

$LOAD_PATH << File.expand_path('../../lib', __FILE__)

require 'restify'
require 'base64'

require 'pry'

Restify.logger.level = :debug

headers = {}

if ENV['AUTH']
  auth = Base64.encode64(ENV['AUTH']).gsub(/\s+/, '').strip
  headers['Authorization'] = "Basic #{auth}"
end

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
  puts "Last commit: #{head[:sha]}"
  puts "By #{head[:commit][:author][:name]} <#{head[:commit][:author][:email]}>"
  puts head[:commit][:message].to_s
  puts
end
