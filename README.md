# Evernote API ruby demo

Devrived from [simple-api-client-example-ruby](https://github.com/evernote/simple-api-client-example-ruby), which includes:

+ evernote oauth
+ a set of helper methods, like `client`, `user_store`, `note_store`, etc.

This demo adds:

+ notebook CRUD
+ note CRUD
+ [ENML](http://dev.evernote.com/doc/articles/enml.php) display


## Usage

+ `$ bundle install`
+ Update oauth consumer key and secret in `evernote_config.rb`.
+ Start up sinatra, `ruby en_oauth.rb`.
+ Check it on `localhost:4567`.

## Reference

+ [Evernote Developer Guide](http://dev.evernote.com/doc/start/ruby.php)
+ [Evernote API: All declarations](http://dev.evernote.com/doc/reference/)
+ [enml-js](https://github.com/wanasit/enml-js)

## Contributing

1. Fork it ( https://github.com/ifyouseewendy/evernote-api-ruby-demo/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
