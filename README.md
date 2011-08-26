# Stack Mob API Ruby Toolkit

## About

A not very clever set of tools for working with StackMob.

_Warning: this is something I whipped up for my own use. Use at your own risk._

Currently, this is a set of ruby scripts that allows you to create, read and delete your 
StackMob data from the command line.

To use it, first copy config.json.example to config.json and set your StackMob information.

You should have a different config file for each StackMob application. By default the
script looks for ./config.json but you can specify a specific one using the --config option.

By default the script uses your sandbox credentials and api version 0. You can use 
the --production option to switch to production keys and api version 1. The --version
option lets you specify different production versions.

Eventually I'd like to make this work more like manipulating your ActiveRecord objects from
the rails console, but it still beats doing everything through a browser or iOS app.

Note: for json files used to specify parameters, they can contain embedded ruby if
they end in .erb:

    $ cat user.json.erb
    {
      "login": "script_user_<%= Time.now.to_i-1305800000 %>",
      "password": "password"
    }

The --json options also takes inline json:

    $ ruby stack_mob.rb -m user -c --json '{"login":"alice","password","s3cr3t"}'

## Requires

Ruby gems: json, oauth

## Optional

The term-ansicolor gem allows colored output.

http://flori.github.com/term-ansicolor/

## Example

Show options:

$ ruby stack_mob.rb -h

Dump app api:

		$ ruby stack_mob.rb --listapi
    {"user"=>
      {"id"=>"user",
       "type"=>"object",
       "properties"=>
        {"profile"=>{"optional"=>true, "type"=>"string", "$ref"=>"profile"},
         "createddate"=>
          {"format"=>"utcmillisec",
           "title"=>"Created Timestamp",
           "indexed"=>true,
           "readonly"=>true,
           "type"=>"integer",
           "description"=>"UTC time when the entity was created"},
           ....

Dump all user instances in the database sorted by lastmoddate:

		$ ruby stack_mob.rb --model user --read --all --sort-by lastmoddate
		[{"createddate"=>1305304396910,
		  "user_id"=>"4dcd5d4caf985c0c24050345",
		  "lastmoddate"=>1305304396910,
		  "password"=>"rosebud",
		  "login"=>"dav"},
		 {"createddate"=>1305304411882,
		  "user_id"=>"4dcd5d5b36d9d994dde82efb",
		  "lastmoddate"=>1305304411882,
		  "password"=>"tokyo",
		  "login"=>"mie"}]

Read a specific user instance in the database:

		$ ruby stack_mob.rb --model user --r -i 4dcd5d4caf985c0c24050345

Delete all of the user instances (note, requires confirmation):

		$ ruby stack_mob.rb -m user -d -a
		Are you sure you want to delete all 2 instances of user? (yes|NO)
		yes
		Deleting 4dcd5d4caf985c0c24050345
		Deleting 4dcd5d5b36d9d994dde82efb

Create a new user instance. The file user.json contains {"login": "script_user","password": "password"}:

    $ ruby stack_mob.rb -m user --create --json user.json 

Hit a custom method. The file custom_1.json contains the necessary params for that method:

      $ ruby stack_mob.rb --method my_method --json custom_1.json 

## License

Public domain where appropriate; free for everyone, for all usages, elsewhere.
