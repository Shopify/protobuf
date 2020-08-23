This is a fork of `google-protobuf` in order to fix some things that don't work on TruffleRuby's LLVM interpreter.

However! The `google-protobuf` repo needs to be set up before the gem is compiled! And RubyGems's mechanism to install a gem from source doesn't do this! We have therefore committed the result of running:

```
% ./autogen.sh
% ./configure
% make
% cd ruby
% chruby 2.7.1
% bundle install
% rake
% git add -f lib/google/protobuf/*.rb
```
