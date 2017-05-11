# frozen_string_literal: true

$LOAD_PATH << File.expand_path('../../lib', __FILE__)

require 'restify'
require 'pry'

gh   = Restify.new('https://api.github.com').get.value
repo = gh.rel(:repository).get(owner: 'jgraichen', repo: 'restify').value
cmt  = repo.rel(:commits).get.value.first

puts "Last commit: #{cmt[:sha]}"
puts "By #{cmt[:commit][:author][:name]} <#{cmt[:commit][:author][:email]}>"
puts cmt[:commit][:message].to_s
