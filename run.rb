# /home/fairsharing/FAIR-Champion/run.rb
# ensure gems from the Gemfile are activated
require 'bundler/setup'

# load environment variables from .env (dotenv gem)
require 'dotenv/load'

# then load the app
require_relative './app/controllers/application_controller'

Champion::ChampionApp.run!
