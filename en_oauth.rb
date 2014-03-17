##
# Copyright 2012 Evernote Corporation. All rights reserved.
##

require 'sinatra'
require 'sinatra/content_for'
enable :sessions

# Load our dependencies and configuration settings
$LOAD_PATH.push(File.expand_path(File.dirname(__FILE__)))
require "evernote_config.rb"

##
# Verify that you have obtained an Evernote API key
##
before do
  if OAUTH_CONSUMER_KEY.empty? || OAUTH_CONSUMER_SECRET.empty?
    halt '<span style="color:red">Before using this sample code you must edit evernote_config.rb and replace OAUTH_CONSUMER_KEY and OAUTH_CONSUMER_SECRET with the values that you received from Evernote. If you do not have an API key, you can request one from <a href="http://dev.evernote.com/documentation/cloud/">dev.evernote.com/documentation/cloud/</a>.</span>'
  end
end

helpers do
  def auth_token
    session[:access_token].token if session[:access_token]
  end

  def client
    @client ||= EvernoteOAuth::Client.new(token: auth_token, consumer_key:OAUTH_CONSUMER_KEY, consumer_secret:OAUTH_CONSUMER_SECRET, sandbox: SANDBOX)
  end

  def user_store
    @user_store ||= client.user_store
  end

  def note_store
    @note_store ||= client.note_store
  end

  def en_user
    user_store.getUser(auth_token)
  end

  def notebooks
    @notebooks ||= note_store.listNotebooks(auth_token)
  end

  def total_note_count
    filter = Evernote::EDAM::NoteStore::NoteFilter.new
    counts = note_store.findNoteCounts(auth_token, filter, false)
    notebooks.inject(0) do |total_count, notebook|
      total_count + (counts.notebookCounts[notebook.guid] || 0)
    end
  end
end

##
# Index page
##
get '/' do
  erb :index
end

##
# Reset the session
##
get '/reset' do
  session.clear
  redirect '/'
end

##
# Obtain temporary credentials
##
get '/requesttoken' do
  callback_url = request.url.chomp("requesttoken").concat("callback")
  begin
    session[:request_token] = client.request_token(:oauth_callback => callback_url)
    redirect '/authorize'
  rescue => e
    @last_error = "Error obtaining temporary credentials: #{e.message}"
    erb :error
  end
end

##
# Redirect the user to Evernote for authoriation
##
get '/authorize' do
  if session[:request_token]
    redirect session[:request_token].authorize_url
  else
    # You shouldn't be invoking this if you don't have a request token
    @last_error = "Request token not set."
    erb :error
  end
end

##
# Receive callback from the Evernote authorization page
##
get '/callback' do
  unless params['oauth_verifier'] || session['request_token']
    @last_error = "Content owner did not authorize the temporary credentials"
    halt erb :error
  end
  session[:oauth_verifier] = params['oauth_verifier']
  begin
    session[:access_token] = session[:request_token].get_access_token(:oauth_verifier => session[:oauth_verifier])
    redirect '/notebooks'
  rescue => e
    @last_error = 'Error extracting access token'
    erb :error
  end
end


##
# Access the user's Evernote account and display account data
##
get '/list' do
  begin
    # Get notebooks
    session[:notebooks] = notebooks.map(&:name)
    # Get username
    session[:username] = en_user.username
    # Get total note count
    session[:total_notes] = total_note_count
    erb :index
  rescue => e
    @last_error = "Error listing notebooks: #{e.message}"
    erb :error
  end
end

get '/notebooks' do
  begin
    # Get notebooks
    @notebooks_names = notebooks.map(&:name)
    # Get username
    @username = en_user.username
    # Get total note count
    @total_notes = total_note_count

    if !session[:access_token]
      @alert = 'You need to authorize first.'
    end
    erb :notebooks
  rescue => e
    @last_error = "Error listing notebooks: #{e.message}"
    erb :error
  end
end

__END__

@@ layout
<!DOCTYPE html>
<html>
  <head>
    <title><%= yield_content :title %></title>

    <link href="http://cdn.bootcss.com/bootstrap/3.1.1/css/bootstrap.min.css" rel="stylesheet">

    <style>
      body {
        padding-top: 50px;
      }
      .starter-template {
         padding: 40px 0;
         text-align: left;
      }
      .starter-template .container{
        padding-left: 0;
      }
    </style>
  </head>
  <body>
    <div class="navbar navbar-inverse navbar-fixed-top" role="navigation">
      <div class="container">
        <div class="navbar-header">
          <button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-collapse">
            <span class="sr-only">Toggle navigation</span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <!-- <a class="navbar-brand" href="/">Demo</a> -->
        </div>
        <div class="collapse navbar-collapse">
          <ul class="nav navbar-nav">
            <li class="active"><a href="/">Home</a></li>
            <li><a href="/notebooks">Notebooks</a></li>
          </ul>
        </div><!--/.nav-collapse -->
      </div>
    </div>

    <div class="container">
      <div class="starter-template">
        <%= yield %>
      </div>
    </div><!-- /.container -->

    <script src="http://cdn.bootcss.com/jquery/2.0.3/jquery.min.js"></script>
    <script src="http://cdn.bootcss.com/bootstrap/3.1.1/js/bootstrap.min.js"></script>
  </body>
</html>

@@ index
<% content_for(:title) do %>
  Evernote Ruby Example App
<% end %>

<% if session[:access_token] %>
  <a href="/reset" class="btn btn-primary btn-lg" role="button">Reset Token</a>
<% else %>
  <a href="/requesttoken" class="btn btn-primary btn-lg" role="button">Authorize with Evernote</a>
<% end %>

@@ error
<% content_for(:title) do %>
  Evernote Ruby Example App &mdash; Error
<% end %>

<p>An error occurred: <%= @last_error %></p>
<p>Please <a href="/reset">start over</a>.</p>

@@ notebooks
<% if @alert %>
  <div class="alert alert-danger"><%= @alert %></div>
<% else %>
  <div class="alert alert-success">Hi <strong><em><%= @username %></em></strong>, there are <%= @total_notes %> notes in your account</div>
  <div class="panel panel-default panel-info">
    <div class="panel-heading">
      Notebooks
      <a href='/notebooks/new'><span class="glyphicon glyphicon-plus pull-right"></span></a>
    </div>

    <ul class="list-group">
      <% @notebooks_names.each do |notebook| %>
        <li class="list-group-item">
          <%= notebook %>
          <a class='text-right' href='/notebooks/new'><span class="glyphicon glyphicon-remove pull-right"></span></a>
          <a class='text-right' href='/notebooks/new'><span class="glyphicon glyphicon-pencil pull-right"></span></a>
        </li>
      <% end %>
    </ul>
  </div>
<% end %>
