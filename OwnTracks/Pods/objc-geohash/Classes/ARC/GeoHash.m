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

#import "GeoHash.h"
#import "GHArea.h"
#import "GHRange.h"
#import "cgeohash.h"

@interface GeoHash()
+ (GEOHASH_direction)convertDirectionType:(GHDirection)dir;
@end

@implementation GeoHash

+(BOOL)verifyHash:(NSString *)hash
{
    return (BOOL)GEOHASH_verify_hash([hash cStringUsingEncoding:NSASCIIStringEncoding]);
}

+(GEOHASH_direction)convertDirectionType:(GHDirection)dir
{
    GEOHASH_direction converted;
    switch (dir) {
        case GHDirectionNorth:
            converted = GEOHASH_NORTH;
            break;
        case GHDirectionSouth:
            converted = GEOHASH_SOUTH;
            break;
        case GHDirectionEast:
            converted = GEOHASH_EAST;
            break;
        case GHDirectionWest:
            converted = GEOHASH_WEST;
            break;
        default:
            break;
    }
    return converted;
}


+ (NSString *)hashForLatitude:(double)lat
                   longitude:(double)lon
                       length:(unsigned int)length 
{
    NSAssert(lat <=   90.0, @"latitude should be under 90");
    NSAssert(lat >=  -90.0, @"latitude should be over -90");
    NSAssert(lon <=  180.0, @"longtitue should be under 180");
    NSAssert(lon >= -180.0, @"longitude should be over -180");
    NSAssert(length <=  22, @"length should be under 22");

    char *raw_hash;
    raw_hash = GEOHASH_encode(lat, lon, length);
    if (raw_hash == NULL) {
        return nil;
        // return [NSString stringWithFormat:@""];
    }
    NSString *hash = [NSString stringWithCString:raw_hash 
                                        encoding:NSASCIIStringEncoding];
    free(raw_hash);
    return hash;
}

+ (GHArea *)areaForHash:(NSString *)hash
{
    GEOHASH_area *raw_area;
    raw_area = GEOHASH_decode([hash cStringUsingEncoding:NSASCIIStringEncoding]);
    if (raw_area == NULL)
        return nil;

    NSNumber *latMax = [[NSNumber alloc] initWithDouble: raw_area->latitude.max];
    NSNumber *latMin = [[NSNumber alloc] initWithDouble: raw_area->latitude.min];

    GHRange *latitude = [[GHRange alloc] initWithMax: latMax
                                                 min: latMin];
    NSNumber *lonMax = [[NSNumber alloc] initWithDouble: raw_area->longitude.max];
    NSNumber *lonMin = [[NSNumber alloc] initWithDouble: raw_area->longitude.min];

    GHRange *longitude = [[GHRange alloc] initWithMax: lonMax
                                                   min: lonMin];
    GHArea *area = [GHArea areaWithLatitude:latitude
                                 longitude:longitude];

    GEOHASH_free_area(raw_area);

    return area;
}

+ (NSString *)adjacentForHash:(NSString *)hash
                    direction:(GHDirection)dir
{
    char *raw_hash;
    GEOHASH_direction raw_dir = [GeoHash convertDirectionType:dir];
    raw_hash = GEOHASH_get_adjacent([hash cStringUsingEncoding:NSASCIIStringEncoding], raw_dir);
    if (raw_hash == NULL)
        return nil;
    NSString *adjacent = [NSString stringWithCString:raw_hash 
                                            encoding:NSASCIIStringEncoding];
    free(raw_hash);
    return adjacent;
}

+ (GHNeighbors *)neighborsForHash:(NSString *)hash
{
    GEOHASH_neighbors *raw_neighbors;
    raw_neighbors = GEOHASH_get_neighbors([hash cStringUsingEncoding:NSASCIIStringEncoding]);
    if (raw_neighbors == NULL)
        return nil;

    NSString *north = [[NSString alloc] initWithCString:raw_neighbors->north 
                                               encoding:NSASCIIStringEncoding];

    NSString *east = [[NSString alloc] initWithCString:raw_neighbors->east 
                                               encoding:NSASCIIStringEncoding];

    NSString *west = [[NSString alloc] initWithCString:raw_neighbors->west 
                                               encoding:NSASCIIStringEncoding];

    NSString *south = [[NSString alloc] initWithCString:raw_neighbors->south 
                                               encoding:NSASCIIStringEncoding];

    NSString *northEast = [[NSString alloc] initWithCString:raw_neighbors->north_east 
                                                   encoding:NSASCIIStringEncoding];

    NSString *northWest = [[NSString alloc] initWithCString:raw_neighbors->north_west 
                                                   encoding:NSASCIIStringEncoding];

    NSString *southEast = [[NSString alloc] initWithCString:raw_neighbors->south_east 
                                                   encoding:NSASCIIStringEncoding];

    NSString *southWest = [[NSString alloc] initWithCString:raw_neighbors->south_west 
                                                   encoding:NSASCIIStringEncoding];

    GHNeighbors *neighbors = [GHNeighbors neighborsWithNorth:north 
                                                       south:south
                                                        west:west
                                                        east:east
                                                   northWest:northWest
                                                   northEast:northEast
                                                   southWest:southWest
                                                   southEast:southEast];

    GEOHASH_free_neighbors(raw_neighbors);

    return neighbors;
}

@end

