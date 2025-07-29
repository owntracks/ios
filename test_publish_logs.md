# Testing the publishLogs Command

## Implementation Summary

I've successfully implemented the remote `publishLogs` command for OwnTracks iOS. Here's what was added:

### 1. Command Handler
- Added `publishLogs` action to the command handling in `OwnTracksAppDelegate.m`
- Added method declaration to `OwnTracksAppDelegate.h`

### 2. Implementation
- Created `publishLogs` method that:
  - Reads the latest log file using `DDFileLogger`
  - Limits output to last 100 lines to prevent spam
  - Creates a JSON payload with log metadata and content
  - Publishes to `{baseTopic}/log` topic

### 3. Schema Updates
- Added `"logs"` to the `_type` enum in `message.json`
- Added `"publishLogs"` to the `action` enum in `message.json`
- Added validation schema for logs message type

## How to Test

### 1. Send Command via MQTT
Publish this JSON message to your device's command topic:

```json
{
  "_type": "cmd",
  "action": "publishLogs"
}
```

### 2. Expected Response
The device will respond with a logs message on `{baseTopic}/log`:

```json
{
  "_type": "logs",
  "tst": 1720780800,
  "filename": "OwnTracks-2024-07-11.log",
  "fileSize": 1024,
  "totalLines": 150,
  "publishedLines": 100,
  "lines": [
    "2024-07-11 12:00:01 [INFO] App started",
    "2024-07-11 12:00:02 [INFO] Location updated",
    "..."
  ]
}
```

### 3. Topic Structure
- Command: `owntracks/{user}/{device}/cmd`
- Response: `owntracks/{user}/{device}/log`

## Features

✅ **Safe Implementation**: Limits to 100 lines to prevent spam  
✅ **Metadata Included**: File info, line counts, timestamps  
✅ **Error Handling**: Graceful handling of missing log files  
✅ **Schema Validation**: Proper JSON schema validation  
✅ **Topic Alias**: Uses topic alias 9 for efficiency  

## Usage Examples

### Basic Command
```bash
mosquitto_pub -h your-broker -t "owntracks/user/device/cmd" -m '{"_type":"cmd","action":"publishLogs"}'
```

### Monitor Response
```bash
mosquitto_sub -h your-broker -t "owntracks/user/device/log"
```

The implementation is complete and ready for testing! 