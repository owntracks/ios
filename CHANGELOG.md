OwnTracks iOS App 8.0 Release Notes
===================================

## OwnTracks 8.0.10
>Release date: 2015-04-13 for alpha testers only

You were having problems bootstrapping a new install with the help of a saved config file

* [FIX] loading config (.otrc) while settings tab was open did not update values #140

## OwnTracks 8.0.9
>Release date: 2015-04-12 for alpha testers only

You experienced crashes, missed faces on the map, missed enter/leave notifications

* [FIX] fixes a crash happening when a face is available for a user, but no locations
	have been recorded yet #137
* [FIX] makes sure a face is shown on the map even when face is processed after
	initial display of the map point #138
* [FIX] processes face for own device (formerly faces were processed for other devices only)
* [FIX] re-enabled local notification for own enter/leave events #139

## OwnTracks 8.0.8
>Release date: 2015-04-11 for alpha testers only

You always missed the possibility to hide the keyboard in settings
You wondered which updates OwnTracks is doing in the background
You experienced crashes when inserting new waypoints or watched incorrect list display in location view

* [NEW] hit the return key in text inputs hides the keyboard (implies extended keyboard for numeric inputs)
* [NEW] the number of received but not yet processed updates is displayed as a red badge next to the friends
	tab on iPhone, or next to the friends tab in the master view on the iPad.
	The display of locations to be transmitted next to the connection status indicator was dropped. This
	information is still shown as the badge value on the launcher screen.
* [NEW] drop sections in location view to avoid missing entries. Location updates and Waypoints are now shown
	in a single section, sorted by their timestamp. Waypoints are marked with a blue circle.
* [FIX] correct update table view after multiple changes to database #107, #128, #131, #132
* [FIX] password was not imported from config file
* [FIX] crash when pointing to an invalid address book entry

## OwnTracks 8.0.7
>Release date: 2015-04-08 for alpha testers only

* [FIX] re-subscribe to correct topics after change Public Mode
* [FIX] import config new format (numbers and booleans instead of strings)
* [FIX] auto enabling Public Mode only if first install

## OwnTracks 8.0.6
>Release date: 2015-04-08 for beta testers - laster revoked due to stability issues

* [NEW] display images from address book or MQTT (face) on Today widget or Watch
* [NEW] receive faces and names via MQTT and store in local db
* [NEW] public mode as initial setting. Public mode connects to predifined broker, hiding
	all other configuration fields
* [FIX] no subscription to `cmd` subtopic



Migrating to 8.0 from 7.5.1
===========================

OwnTracks 8.0 is a major release with a number of enhancements.

