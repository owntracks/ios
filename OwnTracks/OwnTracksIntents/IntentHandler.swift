//
//  IntentHandler.swift
//  OwnTracksIntents
//
//  Created by Christoph Krey on 28.06.20.
//  Copyright © 2020 OwnTracks. All rights reserved.
//

import Intents
class LocationNowResponse: INIntentResponse {

}

class LocationNowHandler: INExtension {
    public func confirm(intent: INIntent,
            completion: @escaping (LocationNowResponse) -> Void) {
        NSLog("confirmLocationNow");
        let response = LocationNowResponse();
        completion(response);
    }


    public func handle(intent: INIntent,
            completion: @escaping (LocationNowResponse) -> Void) {
        NSLog("handleLocationNow");
        let response = LocationNowResponse();
        completion(response);
    }
}

class IntentHandler: INExtension {

    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.
        return LocationNowHandler();
    }
}
