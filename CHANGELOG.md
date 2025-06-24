OwnTracks iOS App Release Notes
===================================

## OwnTracks 18.4.4 iOS/ipadOS
* Release Date 2025-06-24

** Enhancements, bugfixes, and performance optimizations

    [NEW] Automatically "adapt" to changes in movement #843
    [NEW] offline mode #722
    [FIX] Incorrect log message (cmd is handled elsewhere) #841
    [FIX] Processing duplicate (same tst and createdAt) location messages results in @(null) timestamps #840
    [NEW]  Add motion state detection #846
    [FIX] remove abandoned Czech language
    [NEW] add Romanian and Russian (placeholder)
    [FIX] Language cleanup
    [FIX] cleanup

## OwnTracks 18.3.5 iOS/ipadOS
* Release Date 2025-03-11

** Bugfixes and performance optimizations
    [FIX] App killed due to overrun background time #836
    [NEW] show warning message after app swipe out #832
    remove sharedFriends only used by obsolete today widget
    processing messages Streamline logging #835
    [FIX] CoreData synching fixes
    [FIX] UI transparency for background processing

## OwnTracks 18.3.2 iOS/ipadOS
* Release Date 2025-02-19

** UI fixes
    [FIX] warn and correct negative or zero position max
    [FIX] Can't post POI with image #834
    [NEW] add section index to history for easy naviagation
    [FIX] History tab shown although disabled by default #833

## OwnTracks 18.3.1 iOS/ipadOS
* Release Date 2025-01-06

** UI enhancements
    [NEW] Display region on Friends' details page? #831
    [FIX] speedup old waypoints deletion
    [NEW] Navigate to Region / POI #829
    [NEW] add optional image and imagename properties to location message JSON schema

## OwnTracks 18.1.0 iOS/ipadOS
* Release Date 2024-12-14

** UI enhancements
    [NEW] POI with photos (tagging) #824

## OwnTracks 18.0.4 iOS/ipadOS
* Release Date 2024-09-26

** Some UI enhancements, French, and Galician Language
    [NEW] Galician Language #671
    [NEW] French Language #671
    [NEW] keep user location available even in no-map mode #809

## OwnTracks 18.0.1 iOS/ipadOS
* Release Date 2024-09-17

** iOS 18 ready, cleanup, and bug fixes

    [NEW] iOS 18 ready (with Xcode 16), minimum supported iOS/ipadOS version 16.0
    [NEW] upgrade libsodium
    [FIX] tentative fix for not being able to upgrade monitoring mode in background
    [FIX] Swedish Language #671
    [FIX] rename "Publish" in Settings #803
    [FIX] +follow region is too small #797
    [FIX] tentative fix for OwnTracks publishing invalid coordinates #668
    [FIX] reportLocation command triggering in Manual mode #800
    [NEW] remove deprecated Featured Content #802
    [NEW] Bye bye OwnTracksToday widget (Deprecated API) #812	

## OwnTracks 17.3.0 iOS/ipadOS/macOS
* Release Date 2024-05-06

** UI Improvements and Bug Fixes

    [NEW] osmTemplate / osmCopyright optional parameters #794
    [NEW] OSM map tiles #794
    [NEW] force MQTT cleanSession after configaration change #792
    [NEW] cleanSession automatically after config change or kill app #792
    [FIX] API Usage Documentation #787

## OwnTracks 17.2.5 iOS/ipadOS/macOS
* Release Date 2024-03-19

** UI Improvements and Bug Fixes

    [FIX] timer triggered locations updates use fresh GPS fix #781
    [NEW] Fully reset configuration when changing mode and/or host/port #771
    [FIX] "Change Monitoring Mode" doesn't work if the app is on the settings page #768
    [FIX] Make encryptionKey for payload encryption configurable over .otrc  #774
    [FIX] Robustness of settings and configuration messages #775
    [FIX] use defaults for imported regions/waypoints where possible
    [NEW] use publish topic, qos for MQTT will. willRetainflag always false #780
    [NEW] add test for NSMeasurement / NSUnitPressure
    [NEW] status message #778
    [FIX] OwnTracks crashes with _type:location containing batt:null #775
    [FIX] robust waypoints processing
    [FIX] clarify nullable parameters
    [FIX] remove special handling for deviceid
    [FIX] remove unused settings parameter re TLS
    [FIX] robustness for incoming messages
    [FIX] handle nil data in json validation
    [NEW] json validity tests
    [FIX] speed validity test
    [FIX] card message errors and defaults
    [FIX] processTransitionMessage errors and defaults
    [FIX] region tab disappeares but not re-appears when toggling locked setting fast
    [FIX] avoid not necessary error messages if no waypoints in configuration
    [FIX] error handling and defaults for incoming messages
    [FIX] config changes
    [FIX] include all pods in the project repo
    [FIX] final Marker layouts
    [FIX] Launchscreen Attribute #783
    [FIX] Remove AbsoluteAltitude for compatibility

## OwnTracks 17.1.3 iOS/ipadOS/macOS
* Release Date 2024-01-30

** UI Improvements and Bug Fixes

    [FIX] reconnect after config load from URL inline #770
    [FIX] use NSReletiveDateTimeFormatter for timestamp age display
    [NEW] hide Pin Marker for '+follow'  regions

## OwnTracks 17.1.1 iOS/ipadOS/macOS
* Release Date 2024-01-15

** UI Improvements, Localized Units, Custom HTTP Headers and Bug Fixes

    [NEW] Show POIs
    [NEW] Show Regions as Markers instead of deprecated Pins
    [NEW] httpHeaders added #761
    [FIX] allowInvaidCerts setting only in MQTT mode
    [FIX] default POI to empty string (not transmitted) closes #763
    [NEW] hide all MQTT related parameters in HTTP mode on settings screen #759
    [NEW] add pressure reading to status view
    [NEW] use NSMeasurementFormatter for localized units #765

## OwnTracks 17.0.5 iOS/ipadOS/macOS
* Release Date 2023-12-16

** Bug fixes avoiding crash in some environments

    [FIX] process both encrypted and non-encrypted messages avoiding crash #755
    [FIX] Credit Texts

## OwnTracks 17.0.4 iOS/ipadOS/macOS
* Release Date 2023-12-14

** Bug fixes

    [FIX] crash when receiving illegal json closes #755

## OwnTracks 17.0.3 iOS/ipadOS/macOS
* Release Date 2023-12-11

** JSON Schema Validation and Accessible Logs

    [NEW] Accessible Logs and JSON Schema Validation
    [NEW] ISO timestamps in log
    [NEW] Export functionality for Mac Catalyst
    [FIX] move "Logs" button to status view
    [FIX] missing "response" cmd (for tours)
    [FIX] position of share menu on iPad
    [FIX] cleanup client certificate selection
    [FIX] use UTF-8 for .strings files consistently

## OwnTracks 16.4.3 iOS/ipadOS/macOS
* Release Date 2023-09-26

** Remote command extensions and bug fixes

    [NEW] add clearWaypoints command #745
    [FIX] reconnect after config load via URL #743
    [FIX] crash on MQTT negative PUBACK

## OwnTracks 16.4.1 iOS/ipadOS/macOS
* Release Date 2023-02-27

** Homescreen quick actions and bug fixes

    [NEW] Homescreen quick actions for monitoring change #737
    [FIX] Shortcuts no longer switching mode when phone is locked #740
    [FIX] Shortcuts in background mode #740

## OwnTracks 16.3.2 iOS/ipadOS/macOS
* Release Date 2022-12-01

** Tags, POI Marker  and bug fixes

    [NEW] add scale to map view #721
    [NEW] tag and POI #705
    [NEW] Cleanup the info screen (a bit like android) #726
    [FIX] English Translation "You did disable background fetch" closes #727
    [FIX] Crash when saving card with no image #723

## OwnTracks 16.3.0 iOS/ipadOS/macOS
* Release Date 2022-09-08

** Danish (Dansk) Translation and bug fixes

    [NEW] Danish Translation
    [FIX] mark positions triggered by "visits" correctly

## OwnTracks 16.2.5 iOS/ipadOS/macOS
* Release Date 2022-08-08

** Sharing with non-OwnTracks users, Card editing

    [NEW] lock all changes to configuration with by 'locked' setting #707
    [NEW] create/list/delete tours in collaboration with ot-recorder
    [NEW] Edit card info and photo

## OwnTracks 16.1.3 iOS/ipadOS/macOS
* Release Date 2022-02-17

** Turkish translation, small enhancements, and bug fixes

    [NEW] App does now adjust `locatorInterval` changes immediately, no need to kill and restart. #634
    [NEW] How to remove a client certificate? #648
    [NEW] Turkish translation #671
    [NEW] Copy Topic to clipboard on click/tap? #692
    [NEW] Region Monitoring +follow flexible duration #675
    [NEW] Feature request: Add the battery property to the friend view (Android #1015) #681
    [NEW] add distance to Friend Screen
    [NEW] Notification sound when friend leaving or entering region #690
    [NEW] Change tracking mode enter/leave region #683
    [NEW] Feature Request: Publish current monitoring mode on location updates #694
    [NEW] Change tracking mode enter/leave region #683
    [NEW] Ask for permission to use Apple's reverse geocoder and map #696
    [NEW] Change to move mode automatically when phone is charged. #436
    [NEW] Notification message "Friend enters/leaves Region" cannot be translated #672
    [NEW] History Sections cannot be translated (Notification/Friend/Region) #673
    [NEW] Automatic switch on battery
    [NEW] Change to move mode automatically when phone is charged. #436

    [FIX] Dark Mode Navigation and Tab Bars

## OwnTracks 14.2.1/2 iOS/ipadOS/macOS
* Release Date 2021-04-20

** New languages Dutch and Swedish, bug fix

    [NEW] Swedish
    [NEW] Dutch
    [FIX] send 'location' as '_type'  for 'steps' #674

## OwnTracks 14.2.0 iOS/ipadOS/macOS
* Release Date 2021-03-31

** Bug fix and Completed Translations to German and Polish

    [NEW] translations with POEdit
    [FIX] multiple alert messages
    [FIX]  App crashes on swipe-out-friend #666
    [NEW] Consider informing user and/or dropping HTTP POSTs on 4xx errors closes #665
    [FIX] replace UIPickerView by UISegmented Control for mode #664
    [FIX] UIPickerView hides part of the text in iOS 14 #664
    [FIX] display processing message only once
    [FIX] decimals in JSON
    [FIX] App crashes on swipe-out-friend #666

## OwnTracks 14.0.4 iOS/ipadOS/macOS
* Release Date 2021-01-27

** Bug fix

    [FIX] Version 14.0.2/3 crashes on MacOS Catalina 10.15 closes #661

## OwnTracks 14.0.3 iOS/ipadOS/macOS
* Release Date 2021-01-25

** Bug fixes and small enhancements

    [NEW] add pitch control for map on MacOS
    [FIX] Steps reporting topic changed? closes #660

## OwnTracks 14.0.2 iOS/ipadOS/macOS
* Release Date 2021-01-18

** Bug fixes and small enhancements

    [FIX] url query parsing
    [NEW] increase details for error messages on inline config
    [NEW] add rid to /beacon url path
    [FIX] show processingMessage on Mac
    [FIX] wait for new location in background refresh ´"t":"p"'
    [NEW] support owntracks:///config?inline= inline url config processing
    [NEW] Regions with "identifier" 
    [FIX] cleanup "created_at"
    [NEW] Add `created_at` timestamp if relevant #650
    [FIX] always report integer value for "acc" accuracy
    [FIX] OwnTracks on macOS too quickly creates location pins on map #649

## OwnTracks 13.1.4 iOS/ipadOS 13.1.7 macOS
* Release Date 2019-11-19

** iOS Version ported to macOS (via Catalyst), different map view modes, MQTTv5

    [NEW] Allow map to be switched between map view and satellite view #606
    [NEW] support MQTTv5 (no local, topic aliases in = 10, topic aliases out, session Expiry=indefinetely)

    [FIX] lwt-message: Parameter "tst" is of type string. #604
    [FIX] end user whose Regions disappear #608

    [FIX] more info on error
    [NEW] MQTTV5 Session Expiry Interval
    [FIX] don't use NO_LOCAL in MQTT subscription when not using MQTTV5
    [FIX] skip info messages for Mac Catalyst
    [NEW] re-connect after laptop sleep
    [NEW] clarification of Addressbook usage
    [FIX] remove BarButton for Addressbook if Addressbook access is not granted
    [NEW] indicate empty tables in UI
    [FIX] remove QR reader and associated camera access requirements - use external QR reader
    [FIX] sub preference key
    [FIX] Mac Catalyst does not implement left swipes in TableViews. Added Edit/Done Button in each editing TableView
    [FIX] special Map Zoom handling for Mac Catalyst
    [FIX] UIAlert cannot be automatically dismissed in Mac Catalyst
    [NEW] use local pods for Socketrockt and ABStaticTableViewController
    [FIX] remove unsupported statusbarstyle in Mac Catalyst
    [FIX] exclude missing APIs for Mac Catalyst
    [FIX] migrate initWithProximityUUID to iOS13 version
    [FIX] remove deprecated networkActivityIndicator
    [FIX] remove unused and using deprecated functions WebVC
    [FIX] Correct URL for .plist files in different environments
    [FIX] Do not replace patterns if no substitute is availalbe (crash)
    [FIX] Tableview background colors for Catalyst
    [FIX] Dark Mode for Licenses Screen
    [FIX] Dark Colors for Modes Screen


## OwnTracks 13.0.2
* Release Date 2019-09-25

** A few bugfixes and enhancements 

    [NEW] Dark Mode support in iOS 13
    [NEW] Review colors for Dark/Light Mode #600
    [NEW] Review Layout of "Friends" History messages #601

## OwnTracks 12.0.9
* Relase Date 2019-09-14

** A few bug fixes and enhancements

    [NEW] Copy location coordinates to clipboard #597
    [FIX] Dark Mode iOS 13 fixes
    [FIX] Location report "inregions" inconsistent with "transition" messages #598

## OwnTracks 12.0.8
* Relase Date 2019-09-04

** A few bug fixes and enhancements

    [NEW] History Tab
    [NEW] Battery State
    [NEW] Update mode UI element #583
    [FIX] lost and missing links to status screen
    [FIX] WebView is not correctly sized on devices larger than iPhoneSE #596
    [FIX] Remove Geohashing Code
    [FIX] Initial size of Today Widget

## OwnTracks 12.0.3
* Relase Date 2019-04-10

** A few bug fixes and enhancements

    [FIX] setWaypoints crashes owntracks when removing waypoints #570
    [FIX] Configuration of Username/Password for HTTP Mode #566

## OwnTracks 12.0.2
* Release date 2018-12-16

** A few bug fixes and enhances

    [FIX] Reconnect Problem after changing 4G/WLAN or other way #525
    [NEW] Allow authentication without password #559
    [NEW] Add X-Limit-U and X-Limit-D to HTTP mode headers #560
    [FIX] a number of crashes
    [NEW] Use "following" region get more position updates in Significant Changes mode


## OwnTracks 9.9.3
* Release date 2018-05-30

** Cleanup Modes, remove Public Mode due to privacy considerations

    [FIX] Drop Copy Mode
    [FIX] Remove "shared" attribute for Regions / Waypoints
    [FIX] Drop Public Mode #536
    [FIX] Rename Private Mode MQTT Mode
    [FIX] suppress "inregions" if empty

## OwnTracks 9.8.12
* Release date 2018-05-16

** Crash Fixes, a few new Things, and drop AppleWatch support

    [NEW] Include current regions in "location" payload #523
    [NEW] use MQTT V5 library
    [NEW] Include desc in _type=beacon messages #521
    [NEW] translation (PL) update

    [FIX] re-enable Altimeter/pressure reporting
    [FIX] not updating when app is in the background #498
    [FIX] Requesting StepCount via HTTP-Connection seems not to work #535
    [FIX] Drop AppleWatch support because Apple stops Watchkit 1 support
    [FIX] Drop Support for iOS < 11.0, older iOS versions use old version
    [FIX] Drop Addressbook links via Relation "owntracks" / "updateaddressbook" 
    [FIX] Replace deprecated UIAlertView
    [FIX] Replace deprecated UIWebWiew
    [FIX] Replace deprecated UILocalNotification
    [FIX] Replace deprecated AddressBook interface
    [FIX] show matching files when selecting certificates only
    [FIX] Crash in TodayViewController on iOS 9.3.5 iPhone4S #528
    [FIX] Crash when accessing Address Book #529
    [FIX] Crash when requesting reportLocation #527 
    [FIX] Crash in ConnectionType #526
    [FIX] update lastUsedLocation immediately

## OwnTracks 9.8.3/4
* Release date 2018-01-06

** Urgent fixes

    [FIX] OwnTracks 9.8.3 not start on iOS 10 #504
    [FIX] HTTP: app sending GET requests instead of POST #503

## OwnTracks 9.7.8
* Release date 2017-12-21

** Internationalization and Crash Fixes**

    [NEW] Polish text version
    [FIX] Starting map position #496
    [NEW] Apple watch: mode change #434
    [FIX] Watch and TodayWidget do not honor ignoreStaleLocations setting #493

## OwnTracks 9.7.2
* Release date 2017-09-30

**iOS11 location fixes**

    [FIX] OwnTracks locationsettings are wrong #483

## OwnTracks 9.6.4/9.7.1
* Release date 2017-09-27

**iOS11 fixes**

    [FIX] Empty Nicknames shown instead of Full Name in iOS11 #481
    [NEW] updated pods
    [NEW] style updates

## OwnTracks 9.6.3
* Release date 2017-08-20

**Watson regression fixes**

    [FIX] No connect in Watson Quickstart mode #476
    [FIX] Cannot edit MQTT protocol level in Settings screen #475

## OwnTracks 9.6.2
* Release date 2017-07-26

**Setup Bug Fixes**

    [NEW] iOS QR Configuration #443
    [FIX] incorrect defaults used for Private mode - Waypoints/shared location with ibeacon #472

## OwnTracks 9.6.1
* Release date 2017-07-12

**minor bug fixes**

    [NEW] Add link to "Talk" page #468
    [FIX] respect auth setting for HTTP mode
    [FIX] remove reporting visits

## OwnTracks 9.5.8
* Release date 2017-06-23

**iPhone6s/7s compatibility issues solved**

[FIX] Missing t:p on iPhone 6 and higher? #462
[NEW] Background Fetch check code #462

## OwnTracks 9.5.7
*Release date 2017-06-17*

**native traccar interface [booklet](http://owntracks.org/booklet/features/traccar/)**<br> 
**bug fixes**

* [FIX] Friends show "Resolving..." #440#
* [FIX] Beta - app crash when deleting friends #460
* [FIX] extend %d and %u substitution logic to willTopic and subscriptions
* [FIX] use monitoring Visits in Significant mode only
* [FIX] use HTTP basic auth if AUTH is true
* [FIX] correct user in HTTP "topic"
* [NEW] topic in HTTP json payload
* [FIX] Entering/Leaving triggers location update even in Quiet mode #459
* [FIX]  substitutions is pubTopicBase #458
* [NEW] extended expert mode settings
* [FIX] immediate effect of remote config changes #457 #456
* [FIX] Hide experimental "Green Boxes" feature #454

## OwnTracks 9.5.3 
*Release date 2017-05-31*

**mosquitto 1.4.12 compatible clientIDs**<br>
**Copy attribute**<br>
**pubTopicBase parameter expansion**<br>
**HTTP Basic Authentication**

* [FIX] Restrict clientId to minimum MQTT 3.1.1 requirements
* [NEW] copy attribute in payload controlled by UI #449
* [NEW] MQTT 3.1.1 support #444
* [NEW] pubTopicBase may contain %u or %d to be replaced with UserID / DeviceID #445
* [FIX] Change setConfiguration and setWaypoints payloads to match Android #437
* [NEW] Added HTTP Basic Authentication




## OwnTracks 9.3.0
*Release date 2016-10-18*

* [NEW] Add Websockets Transport closes #428
* [NEW] connection type as extended attribute closes #427

## OwnTracks 9.2.8
*Release date 2016-10-15*

* [NEW] Enable Remote Commands closes #411
* [NEW] add Wifi status
* [FIX] Location stops updating in iOS 9.3 in background closes #399

## OwnTracks 9.2.7
*Release date 2016-10-04*

* [FIX] Background location updates not enabled in iOS 10
* [NEW] add "_wifi":true if connected to Wifi when location is published

## OwnTracks 9.2.6
*Release date 2016-09-29*

* [FIX] Latest code crash in TLS settings. closes #423
* [FIX] Mode 5: Watson Quickstart shows Publish Settings option closes #425
* [FIX] App crashes when asking for Steps closes #424
* [FIX] Location permissions disabled under iOS10 closes #417
* [FIX] iOS 10 issues? closes #416

## OwnTracks 9.2.5
*Release date 2016-09-27*

* [FIX] incorrect accuracy = 0 send in location messages triggered by backgroundFetch closes #419
* [FIX] App rejected closes #421
* [FIX] Today widget size too small to show 3 lines in iOS10 closes #418
* [FIX] Location permissions disabled under iOS10 closes #417

## OwnTracks 9.1.7/9.2.4
*Release date 2016-09-24*

* [NEW] Modes for WatsonIoT
* [NEW] Ignore _old_ location pubs closes #410
* [NEW] Minimum requirements iOS 8.0
* [NEW] Again new App icon requirements by XCode8 and iOS10
* [FIX] No images on map with XCode8 / iOS10 #414
* [FIX] Add privacy description for camera use
* [FIX] Crash on response in HTTP mode
* [FIX] null values in configuration JSON
* [FIX] reload map / friends list after config change
* [FIX] Today widget size too small to show 3 lines in iOS10 #418
* [FIX] Location permissions disabled under iOS10 #417

## OwnTracks 9.1.6
*Release date 2016-04-23*

* [FIX] CoreData settings data not available after restart closes #403

*Release date 2016-04-23*
* [NEW] Customizable Texts closes #401
* [FIX] Loss of data when changing mode or reopening app after crash closes #387
* [FIX] Crash if importing invalid JSON closes #398
* [FIX] Crash on null url for Featured closes #402
* [FIX] Multi language issue in Today widget (skmec instead of km) displayed closes #396
* [FIX] Radius display in waypoint closes #395

## OwnTracks 9.1.1
*Release date: 2016-03-17*

* [NEW] Localization support
* [FIX] Font issue on Friends geo-locator closes #391
* [FIX] Transition event without desc displays (null) closes #390

## OwnTracks 9.1.0
*Release date: 2016-03-03*

* [NEW] call Private mode MQTT mode from now on
* [REVERT] Loss of data when changing mode or reopening app after crash closes #387

## OwnTracks 9.0.8/9
*Release date: 2016-03-02*

* [FIX] Loss of data when changing mode or reopening app after crash closes #387

## OwnTracks 9.0.7
*Release date: 2016-03-01 to alpha testers*

* [FIX] ignore size of HTTP offline queue in non-HTTP modes
* [FIX] centered time/date stamp

## OwnTracks 9.0.6
*Release date: 2016-02-29 to alpha testers*

* [FIX] Reset offline queue for HTTP mode when switching modes closes #386
* [NEW] Addresses returned from reverse geocoding more compact closes #385
* [NEW] Featured content tab needs marker on new / updated content/url closes #384
* [FIX] Toggle "Featured" tab sometimes works only halfway closes #382
* [FIX] Latitude and Longitude get rounded when regions are modified closes #376
* [NEW] increase precision or transmitted accuracy in beacon messages closes #371
* [NEW] Little cosmetic issue in Friends tab, finally closes #314

## OwnTracks 9.0.5
*Release date: 2016-02-24 to alpha testers*

* [FIX] fix decryption issues

## OwnTracks 9.0.4
*Release date: 2016-02-23 to alpha testers*

* [NEW] removed Hosted from UI
* [NEW] simplified Settings UI (values are effective when leaving screen)
* [NEW] HTTP mode processes returned messages or array of messages (messages are JSON dictionaries with `_type`:)

## OwnTracks 9.0.3
*Release date: 2016-02-21 to alpha testers*

* [FIX] use secret key for encryption in HTTP mode

## OwnTracks 9.0.2
*Release date: 2016-02-20 to alpha testers*

* [NEW] removed in-app purchase preparations
* [NEW] added HTTP mode
* [NEW] removed Messaging (msg)

## OwnTracks 8.6.7
*Release date: 2016-02-16 to alpha testers*

* [FIX] Featured content web view refresh closes #383
* [FIX] Toggle "Featured" tab sometimes works only halfway closes #382
* [FIX] Crash on (I) closes #381

## OwnTracks 8.6.5
*Release date: 2016-02-13 to alpha *

* [NEW] Featured content Tab closes #380

## OwnTracks 8.6.0/2
*Release date: 2016-02-11 to alpha and beta testers*

* [NEW] raise space to 100k offline locations closes #378
* [FIX] Certificate error connecting to broker - peer did not return a certificate closes #379

## OwnTracks 8.5.5
*Release date: open*

* [FIX] Credits need cutting closes #374

## OwnTracks 8.5.4
*Release date: 2016-02-02 to alpha and beta testers*

* [FIX] remove fabric/crashlytics
* [FIX] increase precision of 'acc' in 'beacon' payload (int -> double)
* [FIX] send 'acc' only if changed by > 20%

## OwnTracks 8.5.1,2,3
*Release date: 2016-01-26 for alpha testers*

* [FIX] limit time of beacon ranging in background closes #370
* [FIX] in locked mode, disable editing of secret key closes #369
* [NEW] optional payload encrpytion closes #368
* [NEW] Featured content tab (moves settings tab under (i)) 

## OwnTracks 8.5.0
*Release date: 2016-01-14 for alpha testers*

new test version and:

* [FIX] tid in beacon message closes #366

## OwnTracks 8.4.91
*Release date: 2015-11-14 for alpha testers*

Fix delayed publish problem

* [FIX] Delayed publish of enter/leave events closes #357
* [FIX] UI Label length issue To... (Topic) closes #358
* [NEW] In-app purchases renewal detection / display of purchased/expiry/checked timestamps

## OwnTracks 8.4.9
*Release date: 2015-11-11 for alpha testers*

Fixing OpenSSL Bitcode distribution problem

* [NEW] MQTTClient with threading fixes
* [NEW] OpenSSL to do local receipt validation for in-app purchases closes #356

## OwnTracks 8.4.8
*Release date: 2015-11-08 for alpha testers*

in-app purchases with local validation

* [NEW] local receipt validation via PKCS7, ASN1 (openssl)

## OwnTracks 8.4.6
*Release date: 2015-10-23 for alpha testers*

in-app purchase continued

* [NEW] Subscription status subscreen

## OwnTracks 8.4.5
*Release date: 2015-10-22 for alpha testers*

in-app purchase cleaning

* [FIX] in-app login only requested in hosted mode
* [NEW] Subscription status in (i) info
* [HINT] https://developer.apple.com/library/ios/documentation/LanguagesUtilities/Conceptual/iTunesConnectInAppPurchase_Guide/Chapters/TestingInAppPurchases.html
	`s/Connect your device to your Mac/Install from Testflight/`

## OwnTracks 8.4.4
*Release date: 2015-10-22 for alpha testers*

Crashing on first time use on new device

* [FIX] Initialization problem first use of in-app purchases on device

## OwnTracks 8.4.3
*Release date: 2015-10-22 for alpha testers*

Missing Enter/Leave events and Hosted recording

* [FIX] OwnTracks stops when crossing borders? closes #114
* [NEW] Hosted recording (OwnTracks Premium)
* [OLD] Removed premature fix for False Positives #76

## OwnTracks 8.3.2
*Release date: 2015-10-19 for alpha testers and app store*

Oops

* [FIX] velocity -1 is suppressed closes #347
* [NEW] republish waypoints closes #346

## OwnTracks 8.3.1
*Release date: 2015-10-17 for alpha testers and app store*

Oops

* [FIX] velocity in km/h instead of m/s closes #345
* [NEW] updated frameworks

## OwnTracks 8.3.0
*Release date: 2015-10-06 for alpha testers and app store*

A few fixes for Move Mode and iOS9

* [FIX] Null locations send in Move mode sporadically closes #339 again

## OwnTracks 8.2.22/23
*Release date: 2015-10-01 for alpha testers*

A few fixes for Move Mode and iOS9

* [FIX] Background location monitoring iOS9 closes #340
* [FIX] Null locations send in Move mode sporadically closes #339
* [FIX] Missing waypoint reports closes #331
* [FIX] crash - OwnTracksAppDelegate.m line 233 closes #330

## OwnTracks 8.2.20/21
*Release date: 2015-09-30 for alpha testers*

A few fixes for Move Mode 

* [FIX] Missing lat,lon whilst in Move Mode closes #338
* [FIX] activity timer is not re-activated at wakeup in Move mode closes #336

## OwnTracks 8.2.19
*Release date: 2015-09-29 for alpha testers*

iOS issues in entry screen

* [FIX] OT crashes when scanning QR-code iOS9 closes #335
* [FIX] login credentials hidden by keyboard on iPhone4 #334

## OwnTracks 8.2.18
*Release date: 2015-09-27 for alpha testers*

Missing "wtst"

* [FIX] missing wtst element in JSON of waypoints closes #332

## OwnTracks 8.2.17
*Release date: 2015-09-27 for alpha testers*

Problem in "waypoint" payload

* [FIX] remove trailing ":" in waypoint description in playload closes #329

## OwnTracks 8.2.16
*Release date: 2015-09-24 for alpha testers*

iOS9 and Altimeter

* [FIX] temptative fix for missing Barometric pressure values in iOS9 #328

## OwnTracks 8.2.15
*Release date: 2015-09-21 for alpha testers*

A few fixes

* [FIX] iBeacon setup UI closes #326
* [FIX] Limit TID entry to 2 alphanumeric characters closes #320
* [NEW] iOS9 and Xcode7 compatibility

## OwnTracks 8.2.14
*Release date: 2015-08-27 for alpha testers*

Again false positives on leaving region

* [FIX] false positives for Geofence closes #76


## OwnTracks 8.2.13
*Release date: 2015-08-22 for alpha testers*

A few fixes

* [NEW] new locked settings mode closes #309
* [FIX] crash when opening messages tab closes #311
* [FIX] precise feedback message closes #308
* [FIX] deferred reverse geo lookups closes #302
* [FIX] false positives for Geofence closes #76

## OwnTracks 8.2.12
*Release date: 2015-08-16 alpha testers*

A few fixes

* [NEW] consolidate MQTT Sessions to one closes #293
* [FIX] clean subscribtions when changing modes closes #296
* [FIX] avoid opening links within message window closes #298
* [FIX] incomplete FontAwesome closes #297

## OwnTracks 8.2.11
*Release date: 2015-08-01 release candidate*

A new UI and fine new features

* [NEW] render HTML in Messages and use fixed table row sizes closes #290
* [NEW] use new Public and Hosted mode broker addresses
* [FIX] missing update of iBeacon position

## OwnTracks 8.2.10
*Release date: 2015-07-27 for alpha-testers only*

A few fixes and enhancements

* [FIX] crash when receiving message closes #282
* [NEW] include enter/leave events in messages and messages in notifications closes #283

## OwnTracks 8.2.9
*Release date: 2015-07-23 for alpha-testers only*

A few fixes and enhancements

* [FIX] Change message while resolving reverse geo
* [FIX] Bug in MQTTClient blocking File Persistence might relate to #141
* [FIX] phrasing update closes #279
* [NEW] Delete Message data when switching modes for privacy closes #281
* [NEW] Adding waypoints from regions tab closes #280

## OwnTracks 8.2.8
*Release date: 2015-07-22 for alpha-testers only*

A few fixes and enhancements

* [NEW] Allow multiple selection for pinned certificates in UI and settings closes #277
* [NEW] UI: use Disclosure Indicator chevron (>) an Detail Disclosure (i) consistently closes #276
* [NEW] Add new Quiet monitoring mode to Manual, Significant Changes and Move mode closes #274
* [NEW] Disable irrelevant fields in TLS settings UI closes #273
* [NEW] use 'untrusted' rather than 'invalid' for self signed certs in settings UI closes #269
* [FIX] change .otre (.der) public mime type to application/binary to avoid clutter in mail display
* [FIX] subscribes to message topics with QOS0 only closes #272

## OwnTracks 8.2.7
*Release date: 2015-07-20 for alpha-testers only*

A few fixes

* [FIX] message badge value not updated when deleting single message closes #268
* [FIX] use 'Authentication' rather than 'Authorize' closes #267
* [FIX] show correct TID for self and friends closes #265

## OwnTracks 8.2.6
*Release date: 2015-07-20 for alpha-testers only*

A few fixes and a new reduced UI for settings

* [NEW] reduced settings UI closes #263
* [FIX] trackerID settings were not used closes #264
* [NEW] show coordinates and geohash in info screen closes #261
* [FIX] incorrect link to Documentation closes #260
* [NEW] updated first login screen

## OwnTracks 8.2.5
*Release date: 2015-07-18 for alpha-testers only*

A bigger thing, threading issues accessing the Address Book
And the missing database migration from 8.0.32 for waypoints

* [FIX] crashes fixed closes #259
* [FIX] crashes fixed closes #258
* [FIX] crashes fixed closes #257
* [FIX] crashes fixed closes #256
* [FIX] crashes fixed closes #254
* [NEW] migration from 8.0.32 database closes #248

## OwnTracks 8.2.4
*Release date: 2015-07-18 for alpha-testers only*

Just a small fix, but I will help to test messaging

* [FIX] navigations bars don't work on main screen
* [FIX] messages should not expire it ttl = 0

## OwnTracks 8.2.3
*Release date: 2015-07-14 for alpha-testers only*

A few bug fixes and UI enhancements

* [FIX] regions not visible after import closes #253
* [FIX] display contact name with priority to face name or topic
* [NEW] shortcut to connection info in all navigation bars closes #252
* [NEW] login screen with QR reader 
* [NEW] all navigation bars can be hidden via swipe up/down


## OwnTracks 8.2.2
*Release date: 2015-07-13 for alpha-testers only*

A few bug fixes and UI enhancements

* [FIX] crash deleting a waypoint closes #219
* [FIX] crash when entering region before first location publish closes #220
* [FIX] crash if incorrect face data received closes #246
* [NEW] Use more general tab bar icon for regions (regions are both geofences and beacons) closes #249
* [NEW] Add numbers to QoS Levels closes #250
* [NEW] Quickly show a message explaining what has been enabled when clicking on top bar buttons closes #251


## OwnTracks 8.2.1
*Release date: 2015-07-12 for alpha-testers only*

A few bug fixes

* [FIX] correct display of message count #244
* [FIX] correct updating of beacon regions #241
* [FIX] crash if incorrect face data received #240


## OwnTracks 8.2.0
*Release date: 2015-07-06 for alpha-testers only*

* [NEW] new colors 
* [NEW] new images
* [NEW] show tracks of selected friend on map
* [NEW] show variable sized table rows with revgeo locations on friends table
* [NEW] common iPad and iPhone UI (to be further improved)
* [NEW] client certificate support (load .p12 as .otrp to iOS)
* [NEW] pinned server certificate support (load .cer as .otre to iOS)
* [FIX] waypoints with (null) description #236
* [FIX] crash when requesting refresh from friend #232

## OwnTracks 8.1.3
*Release date: 2015-06-27 for alpha-testers only*

* [FIX] use "tst" from message instead of now for message timestamp
* [NEW] expire message according to "tst" and "ttl"
* [FIX] reduce CPU/battery usage for background connections
* [FIX] message tableview: open url on tap (i) only, no message selection
* [FIX] message tableview: use absolute timestamps in display
* [FIX] message tableview: use darker "yellow" for prio 1 icons

## OwnTracks 8.1.2
*Release date: 2015-06-26 for alpha-testers only*

* [NEW] rename lbs to msg
* [NEW] msg/system topic and <basetopic>/msg
* [NEW] FontAwesome for message icons

## OwnTracks 8.1.1
*Release date: 2015-06-22 for alpha-testers only*

* [NEW] optional Location Based Service subscriptions
* [NEW] barometric pressure in extended location data if available

## OwnTracks 8.1.0
*Release date: 2015-06-21 for alpha-testers only*

* [FIX] dynamic coloring of iBeacon indicators on map
* [NEW] iBeacon images v2

## OwnTracks 8.0.39
*Release date: 2015-06-21 for alpha-testers only*

* [NEW] show cold and hot Circular and iBeacon regions in Friend Tab / Location list
* [NEW] show cold and hot iBeacon regions on map
* [NEW] process and show dynamic Location Based Service info

## OwnTracks 8.0.36
*Release date: 2015-06-17 for alpha-testers only - resubmitted b/c apparent app store problems*

* [NEW] use real timestamp in "t":"p" location messages #197
* [NEW] enable Hosted mode and Beacon parameters via URL, external QR reader or app internal QR scan 

## OwnTracks 8.0.35
*Release date: 2015-06-17 for alpha-testers only*

* [NEW] use real timestamp in "t":"p" location messages #197
* [NEW] enable Hosted mode and Beacon parameters via URL, external QR reader or app internal QR scan 

## OwnTracks 8.0.34
*Release date: 2015-06-13 for alpha-testers only*

* [NEW] Minimum iOS Version 7.0 (b/c QR reader)
* [NEW] QR reader for iBeacon labels 
* [NEW] QR reader for Hosted mode labels
* [NEW] Auto-updating iBeacon locations and indicators (when entering iBeacon region, waypoint is updated)
* [NEW] iBeacon images on map

## OwnTracks 8.0.33
*Release date: 2015-06-13 for alpha-testers only*

* [FIX] crash when accessing addressbook with leading `@` in names #115, #202
* [FIX] typo in .otrc/.otrw processing message #203
* [FIX] empty tid in transition event #205
* [FIX] enable host name verification (MQTT-Client-Framework 0.1.6)
* [FIX] added userinfo to processing error messages #206
* [NEW] add type to transition messages and suppress beacon notifications #199
* [NEW] optimize beacon ranging result messages based on proximity #204
* [NEW] show location accuracy in details screen #208
* [FIX] suppress publish on beacon enter/leave when monitoring == manual #209
* [FIX] crash if address book relationships corrupt #207
* [FIX] crash if unexpected short topic received #210
* [NEW] MQTT-Client-Framework 0.2.0
* [NEW] fabric.io/crashlytics 3.0.9
* [FIX] if no deviceid is specified, it doesn't publish #211
* [NEW] setWaypoints command
* [FIX] crash when location.timestamp is nil #217
* [FIX] crash remove observer in status.tvc #215
* [FIX] crash manually delete location #200
* [FIX] crash upgrading db on iPhone4S #214

## OwnTracks 8.0.32
*Release date: 2015-05-22 for beta testing*

Bug fixes and small enhancements

* [NEW] add export of waypoints only
* [NEW] direct link to hosted from settings (called Manage Tracking)
* [FIX] clean database only if .otrc file received (not for .otrw)
* [FIX] correct beacon region indicator when all beacons reset

## OwnTracks 8.0.31
*Release date: 2015-05-21 for alpha testers only*

Beacon related bug fixes

* [FIX] waypoints were deleted after being imported
* [FIX] correct beacon region indicator when using multiple beacons

## OwnTracks 8.0.30
*Release date: 2015-05-?? for alpha testers only*

Public Mode UI Clarity

* [NEW] show base topic in location details screen #198
* [NEW] disable forced crash button
* [NEW] implement new .otrc format // unfortunately Safari on iOS does not support direct download and open in app

## OwnTracks 8.0.29
*Release date: 2015-05-17 for alpha testers only*

App crashing Down Under

* [FIX] crash when linking to address book entry w/o contact image #196

## OwnTracks 8.0.28
*Release date: 2015-05-09 for alpha testers only*

Bug fixing and avoiding

* [FIX] avoid iPad CLLocationManager reports <nil> location #192
* [FIX] fixed iPad export settings popup location #187

## OwnTracks 8.0.27
*Release date: 2015-05-08 for alpha testers only*

Preparing for launch 3

* [NEW] user warning when no location is available

## OwnTracks 8.0.26
*Release date: 2015-05-08 (skipped)*

Preparing for launch 2

* [FIX] correct link to registration site

## OwnTracks 8.0.25
*Release date: 2015-05-08 for alpha testers only*

Preparing for launch

* [NEW] Update Public and Hosted Mode settings
* [NEW] Upgrade to CocoaPods 0.37
* [NEW] Upgrade to fabric.io 1.2.5

## OwnTracks 8.0.24
*Release date: 2015-05-07 for alpha testers only*

Bugfix continued

* [FIX] Fixed crash when exporting settings in Hosted Mode #184
* [NEW] Implement forced crash button for iPad too #185
* [NEW] Warning when switching between Modes #182
                    	
## OwnTracks 8.0.23
*Release date: 2015-05-06 for alpha testers only*

Bugfix for Hosted Mode

* [FIX] Anonymous location publishes before entering user credentials are suppressed #180
* [FIX] Enabled response to 'reportLocation' command in hosted mode #179
                    	
## OwnTracks 8.0.22
*Release date: 2015-05-03 for alpha testers only*

Bugfix message processing

* [FIX] db updates are saved to "disk" after processing incoming messages  #176
                    	
## OwnTracks 8.0.21
*Release date: 2015-05-02 for alpha testers only*

Bugfix for short lived connections

* [FIX] Messages queued and not delivered although in Wifi environment #173
                    	
## OwnTracks 8.0.20
*Release date: 2015-05-01 for alpha testers only*

Hunting bugs still

* [FIX] Today widget paging on last page causes crash #169
* [FIX] Freeze screen after reconnect and a bunch of queued messages #175
                    	
## OwnTracks 8.0.19
*Release date: 2015-05-01 for alpha testers only*

Tracing down some bugs

* [NEW] A few connection details are logged to fabrics.io which are transferred when a crash happens or is forced #173
* [NEW] You may force a crash using a button next to the version display on the Settings tab
* [FIX] duplicate publish of current location when tapping long with 3 fingers on iPad #168
* [FIX] User feedback is now more direct when long tapping with 3 fingers #173
* [FIX] Freeze of screen is eliminated by avoiding unnecessary UI re-draws #174

## OwnTracks 8.0.18
*Release date: 2015-04-27 for alpha testers only (8.0.17 skipped)*

And here it comes: Apple Watch --- Wrist ready
as well as fixes and enhancements to a number of UI issues

* [NEW] Apple Watch shows your closes friends (all friends linked to address book) same as Today widget #113
* [NEW] New more intuitive action sheets for Follow icon, Mode icon, and Ranging icon #119 #164 #165 #166
* [NEW] Entering or leaving a region triggers location publish again (was lost when we moved events to subtopic) #159
* [NEW] Authorisation settings in Hosted mode are picked up immediately after hitting return #157
* [NEW] Editing/Adding waypoint is now possible by long-pressing on map and by dragging waypoints #156 #155
* [FIX] Coloring of regions on map corresponds now to enter/leave events #123
* [FIX] Connection idle (blue indicator) after startup is eliminated #109

## OwnTracks 8.0.16
*Release date: 2015-04-23 for alpha testers only*

Elaborated on iPad and Hosted Mode

* [NEW] Separate settings for user, device and token in Hosted mode #154
* [FIX] Fix missing link on iPad from settings to effective settings display #153
* [FIX] Fix missing display on iPad for effective subscriptions #152

## OwnTracks 8.0.15
*Release date: 2015-04-20 for alpha testers only (8.0.14 skipped)*

Found a number of bugs while testing in different environments

* [NEW] Clearer UI in settings tab for Check and Mode #145
* [FIX] Hitting Annotation Info in map before hiding Navigation Bar opened Status view without possibility to return #147
* [NEW] On reconnect (or when switching Modes) a location update is published #148
* [FIX] correct default subscriptions for non-standard topic settings #149
* [FIX] notifications in-app and in iOS Notification Center when entering/leaving regions #150

## OwnTracks 8.0.13
*Release date: 2015-04-19 for alpha testers only*

Testing in different private environments

* [FIX] process incoming topics with leading slash correctly #143
* [NEW] Rename Mode Own to Private #144

## OwnTracks 8.0.12
*Release date: 2015-04-18 for alpha testers only*

UI feedback said the settings tab is confusing when switching between modes

* [NEW] Dynamic field selection in settings tab depending on Mode

## OwnTracks 8.0.11
*Release date: 2015-04-16 for alpha testers only*

Extending Public Mode

* [NEW] Public, Hosted, and Own modes
* [FIX] Load correct image format for assigned friends without image in address book

## OwnTracks 8.0.10
*Release date: 2015-04-13 for alpha testers only*

You were having problems bootstrapping a new install with the help of a saved config file.

* [FIX] loading config (.otrc) while settings tab was open did not update values #140

## OwnTracks 8.0.9
*Release date: 2015-04-12 for alpha testers only*

You experienced crashes, missed faces on the map, missed enter/leave notifications.

* [FIX] fixes a crash happening when a face is available for a user, but no locations
	have been recorded yet #137
* [FIX] makes sure a face is shown on the map even when face is processed after
	initial display of the map point #138
* [FIX] processes face for own device (formerly faces were processed for other devices only)
* [FIX] re-enabled local notification for own enter/leave events #139

## OwnTracks 8.0.8
*Release date: 2015-04-11 for alpha testers only*

You always missed the possibility to hide the keyboard in settings.
You wondered which updates OwnTracks is doing in the background.
You experienced crashes when inserting new waypoints or watched incorrect list display in location view.

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
*Release date: 2015-04-08 for alpha testers only*

* [FIX] re-subscribe to correct topics after change Public Mode
* [FIX] import config new format (numbers and booleans instead of strings)
* [FIX] auto enabling Public Mode only if first install

## OwnTracks 8.0.6
*Release date: 2015-04-08 for beta testers - laster revoked due to stability issues*

* [NEW] display images from address book or MQTT (face) on Today widget or Watch
* [NEW] receive faces and names via MQTT and store in local db
* [NEW] public mode as initial setting. Public mode connects to predifined broker, hiding
	all other configuration fields
* [FIX] no subscription to `cmd` subtopic

