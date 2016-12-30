/*
The MIT License

Copyright (c) 2011 lyo.kato@gmail.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

#import <Foundation/Foundation.h>

@interface GHNeighbors : NSObject {
  NSString *north;
  NSString *south;
  NSString *west;
  NSString *east;
  NSString *norrthWest;
  NSString *northEast;
  NSString *southWest;
  NSString *southEast;
}

@property (readonly, strong) NSString *north;
@property (readonly, strong) NSString *south;
@property (readonly, strong) NSString *west;
@property (readonly, strong) NSString *east;
@property (readonly, strong) NSString *northWest;
@property (readonly, strong) NSString *northEast;
@property (readonly, strong) NSString *southWest;
@property (readonly, strong) NSString *southEast;

+ (id)neighborsWithNorth:northHash
                   south:southHash
                    west:westHash
                    east:eastHash
               northWest:northWestHash
               northEast:northEastHash
               southWest:southWestHash
               southEast:southEastHash;

- (id)initWithNorth:northHash
              south:southHash
               west:westHash
               east:eastHash
          northWest:northWestHash
          northEast:northEastHash
          southWest:southWestHash
          southEast:southEastHash;

@end

