You can use this Geotix App template code as a foundation to create any Geotix App you'd like. 
You can learn how to configure a template Geotix App by following 
the "[Setting up your development environment](https://geotix-developer.github.io/apps/)" quickstart guide on geotix-developer.github.io.

## Install

To run the code, make sure you have [Bundler](http://gembundler.com/) installed; then enter `bundle install` on the command line.

## Set environment variables

1. Create a copy of the `.env-example` file called `.env`.
2. Add your Geotix App's webhook secret to the `.env` file.

## Run the server

1. Run `bundle exec shotgun` on the command line.
1. View the default Sinatra app at `localhost:9393`. 
Note you should see a `Signatures don't match.` error if its working as expected.

