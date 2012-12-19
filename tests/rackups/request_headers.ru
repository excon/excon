require 'sinatra'

class App < Sinatra::Base
  post '/' do
    h = ""
    env.each { |k,v| h << "#{$1.downcase}: #{v}\n" if k =~ /http_(.*)/i }
    h
  end
end

run App
