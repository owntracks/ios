//
//  MQTTCoreDataPersistence.h
//  MQTTClient
//
//  Created by Christoph Krey on 22.03.15.
//  Copyright © 2015-2022 Christoph Krey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <mqttc/MQTTPersistence.h>

@interface MQTTCoreDataPersistence : NSObject <MQTTPersistence>

@end

@interface MQTTFlow : NSManagedObject <MQTTFlow>
@end

@interface MQTTCoreDataFlow : NSObject <MQTTFlow>
@end
