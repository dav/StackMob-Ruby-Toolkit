# Stack Mob API Ruby Toolkit

## About

A very simple and not very clever set of tools for working with StackMob.

Warning this is something I whipped up for my own use. Use at your own risk.

Currently, this is a set of ruby scripts that allows you to read and delete your StackMob
data from the command line.

To use it, first copy config.json.example to config.json and set your app and key information.

For now, run the script from the source directory (and keep config.json there too)

For now, it only works for one app, the one specified as default in the config file.
I need to add more command line options to allow you to specify the app at runtime.

Eventually I'd like to make this work more like manipulating your ActiveRecord objects from
the rails console, but it still beats doing everything through a browser or iOS app.

## Example

Dump all user instances in the database:

		$ ruby stack_mob.rb --model user --read --all
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


Delete all of the user instances (note, requires confirmation):

		$ ruby stack_mob.rb -m user -d -a
		Are you sure you want to delete all 2 instances of user? (yes|NO)
		yes
		Deleting 4dcd5d4caf985c0c24050345
		Deleting 4dcd5d5b36d9d994dde82efb

Create a new user instance. The file user.json contains {"login": "script_user","password": "password"}:

    $ ruby stack_mob.rb -m user -c user.json 
    {"createddate"=>1305733013837,
     "user_id"=>"4dd3e795af985c0c25050345",
     "lastmoddate"=>1305733013837,
     "password"=>"password",
     "login"=>"script_user"}



## License

Public domain where appropriate; free for everyone, for all usages, elsewhere.
