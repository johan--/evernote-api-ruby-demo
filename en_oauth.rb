##
# Copyright 2012 Evernote Corporation. All rights reserved.
##

require 'sinatra'
require 'sinatra/content_for'
require 'action_view'

include ActionView::Helpers::JavaScriptHelper

if development?
  require "sinatra/reloader"
  # require 'pry'
end
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

  def username
    @username ||= en_user.username
  end

  def authorized
    !!session[:access_token]
  end

  def find_notebook
    note_store.getNotebook(params[:notebook_id])
  end

  def find_note
    note_store.getNote(params[:id], true, true, false, false)
  end

  def get_note_content(note)
    escape_javascript(note_store.getNote(note.guid, true, true, false, false).content) rescue 'Get note content error'
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
# notebook CRUD start
##
get '/notebooks' do
  begin
    if authorized
      # Get total notes count
      @total_notes_count = total_note_count
    end

    erb "notebooks/index".to_sym
  rescue => e
    @last_error = "Error listing notebooks: #{e.message}"
    erb :error
  end
end

get '/notebooks/new' do
  erb "notebooks/new".to_sym
end

post '/notebooks/create' do
  if !params[:notebook_name].empty?
    notebook = Evernote::EDAM::Type::Notebook.new
    notebook.name = params[:notebook_name]
    note_store.createNotebook(notebook)
    redirect '/notebooks'
  else
    @notice = 'Notebook name cannot be empty.'
    erb "notebooks/new".to_sym
  end
end

get '/notebooks/:notebook_id/edit' do
  @notebook = find_notebook
  erb "notebooks/edit".to_sym
end

put '/notebooks/:notebook_id' do
  @notebook = find_notebook
  if !params[:notebook_name].empty?
    @notebook.name = params[:notebook_name]
    note_store.updateNotebook(@notebook)
    redirect '/notebooks'
  else
    @notice = 'Notebook name cannot be empty.'
    erb "notebooks/edit".to_sym
  end
end

# Evernote API does not support deleting notebook, even under full access.
delete '/notebooks/:notebook_id' do
end

##
# note CRUD start
##
get '/notebooks/:notebook_id/notes' do
  @notebook = find_notebook
  filter = Evernote::EDAM::NoteStore::NoteFilter.new
  filter.notebookGuid = @notebook.guid
  @notes = note_store.findNotes(filter, 0, 100).notes

  erb "notebooks/notes/index".to_sym
end

get '/notebooks/:notebook_id/notes/new' do
  erb "notebooks/notes/new".to_sym
end

post '/notebooks/:notebook_id/notes/create' do
  notebook = find_notebook

  if !params[:note_title].empty?
    note = Evernote::EDAM::Type::Note.new
    note.title = params[:note_title]

    n_body = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    n_body += "<!DOCTYPE en-note SYSTEM \"http://xml.evernote.com/pub/enml2.dtd\">"
    n_body += "<en-note>#{params[:note_content]}</en-note>"
    note.content = n_body

    note.notebookGuid = notebook.guid

    ## Attempt to create note in Evernote account
    begin
      note = note_store.createNote(note)
      redirect "/notebooks/#{params[:notebook_id]}/notes/#{note.guid}"
    rescue Evernote::EDAM::Error::EDAMUserException => edue
      ## Something was wrong with the note data
      ## See EDAMErrorCode enumeration for error code explanation
      ## http://dev.evernote.com/documentation/reference/Errors.html#Enum_EDAMErrorCode
      @notice = "EDAMUserException: #{edue}"
      erb "notebooks/notes/new".to_sym
    rescue Evernote::EDAM::Error::EDAMNotFoundException
      ## Parent Notebook GUID doesn't correspond to an actual notebook
      @notice = "EDAMNotFoundException: Invalid parent notebook GUID"
      erb "notebooks/notes/new".to_sym
    end

  else
    @notice = 'Note title cannot be empty.'
    erb "notebooks/notes/new".to_sym
  end
end

get '/notebooks/:notebook_id/notes/:id/edit' do
  @note = find_note
  erb "notebooks/notes/edit".to_sym
end

put '/notebooks/:notebook_id/notes/:id/update' do
  @note = find_note

  if !params[:note_title].empty?
    @note.title = params[:note_title]

    n_body = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    n_body += "<!DOCTYPE en-note SYSTEM \"http://xml.evernote.com/pub/enml2.dtd\">"
    n_body += "<en-note>#{params[:note_content]}</en-note>"
    @note.content = n_body

    ## Attempt to create note in Evernote account
    begin
      note_store.updateNote(@note)
      redirect "/notebooks/#{params[:notebook_id]}/notes/#{params[:id]}"
    rescue Evernote::EDAM::Error::EDAMUserException => edue
      ## Something was wrong with the note data
      ## See EDAMErrorCode enumeration for error code explanation
      ## http://dev.evernote.com/documentation/reference/Errors.html#Enum_EDAMErrorCode
      @notice = "EDAMUserException: #{edue}"
      erb "notebooks/notes/new".to_sym
    rescue Evernote::EDAM::Error::EDAMNotFoundException
      ## Parent Notebook GUID doesn't correspond to an actual notebook
      @notice = "EDAMNotFoundException: Invalid parent notebook GUID"
      erb "notebooks/notes/edit".to_sym
    end

  else
    @notice = 'Note title cannot be empty.'
    erb "notebooks/notes/edit".to_sym
  end
end

get '/notebooks/:notebook_id/notes/:id' do
  @note = find_note
  @content = get_note_content(@note)
  erb "notebooks/notes/show".to_sym
end

delete '/notebooks/:notebook_id/notes/:id' do
  @note = find_note
  begin
    note_store.deleteNote(@note.guid)
    @notice = "Successfully delete note."
  rescue => e
    @notice = "Error deleting note: #{e.message}"
  end

  # Need to redirect with flash
  redirect "/notebooks/#{params[:notebook_id]}/notes"
end
