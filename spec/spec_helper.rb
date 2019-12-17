# encoding: UTF-8

require 'rspec'
require 'adyen'
require 'adyen/matchers'
require 'pry'

RSpec.configure do |config|
  config.include Adyen::Matchers
end
