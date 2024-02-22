//
//  MQTTInMemoryPersistence.h
//  MQTTClient
//
//  Created by Christoph Krey on 22.03.15.
//  Copyright © 2015-2022 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mqttc/MQTTPersistence.h>

@interface MQTTInMemoryPersistence : NSObject <MQTTPersistence>
@end

@interface MQTTInMemoryFlow : NSObject <MQTTFlow>
@end
