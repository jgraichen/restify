# frozen_string_literal: true

$LOAD_PATH << File.expand_path('../../lib', __FILE__)

require 'restify'
require 'pry'

if ENV['LOGGING']
  ::Logging.logger.root.add_appenders Logging.appenders.stdout
  ::Logging.logger.root.level = :debug
end

gh   = Restify.new('https://api.github.com').get.value
repo = gh.rel(:repository).get(owner: 'jgraichen', repo: 'restify').value
cmt  = repo.rel(:commits).get.value.first

puts "Last commit: #{cmt[:sha]}"
puts "By #{cmt[:commit][:author][:name]} <#{cmt[:commit][:author][:email]}>"
puts cmt[:commit][:message].to_s
