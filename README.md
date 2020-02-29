ios
===

# OwnTracks' iPhone App


OwnTracks initially was __MQTTitude__.

# Preparation
## CocoaPods
There are two *non-standard* Pods in use.
Clone these two repositories into the same directory as this repository:
[ABStaticTableViewController](https://github.com/k06a/ABStaticTableViewController.git), and
[mqttc/MinL](https://github.com/ckrey/mqttc.git).
Then re-run `pod`:

        % cd OwnTracks
        % pod install

## Xcode
Staying in the `OwnTracks/` directory,
launch `xcode`:

        % open OwnTracks.xcworkspace

Next, click on the `OwnTacks` project and you will see two targets, `OwnTracks` and `OwnTracksToday`.
For each project, go to the `General` tab.

For the `OwnTracks` target, set the Bundle Identifier accordingly:

        com.example.OwnTracks
        
For the `OwnTracksTofay` target, set the Bundle Identifier accordingly:

        com.example.OwnTracks.OwnTracksToday
        
For the `OwnTracks` project, go to the `Signing and Capabilities` tab and set the appropriate team.
Then scroll down to `App Groups`,
uncheck `group.org.owntracks.OwnTracks`,
and then click on the `+` to create your own group, e.g.,

        group.com.example.OwnTracks

Finally, for the `OwnTracksToday` project, go to the `Signing and Capabilities` tab,
set the appropriate team.
Then scroll down to `App Groups`,
uncheck `group.org.owntracks.OwnTracks`,
and check the group you create for the `OwnTracks` project.

**Note** that most these changes will result in `Xcode` creating provision profiles, repairing things, etc.
Please take your time and be patient!

With these steps complete,
you should be able to compile and run the project.

