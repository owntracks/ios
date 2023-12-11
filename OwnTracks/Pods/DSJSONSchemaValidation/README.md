# DSJSONSchemaValidation

**JSON Schema draft 4, draft 6 and draft 7 parsing and validation library written in Objective-C.**

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) [![CocoaPods](https://img.shields.io/cocoapods/v/DSJSONSchemaValidation.svg?maxAge=604800)]() [![CocoaPods](https://img.shields.io/cocoapods/p/DSJSONSchemaValidation.svg?maxAge=2592000)]() [![CocoaPods](https://img.shields.io/cocoapods/l/DSJSONSchemaValidation.svg?maxAge=2592000)]()

`DSJSONSchemaValidation` is a library that provides a set of classes for parsing [JSON Schema](http://json-schema.org/documentation.html) documents into native Objective-C objects and subsequently using them to validate JSON documents.

The main feature of the library is an ability to "compile" the schema into a network of objects that describe that schema, so that it could be cached and reused for validation of multiple JSON documents in a performant manner, similar to the way `NSRegularExpression` and `NSDateFormatter` classes are used. One of the possible use cases of this library could be early validation of JSON response received from a web service, based on expectations described within the app in a form of JSON Schema.

`DSJSONSchemaValidation` supports all validation keywords of JSON Schema draft 4, 6 and 7. It is also possible to extend the functionality of the library by defining custom keywords to be used with specific metaschema URIs and custom formats for the `format` validation keyword. Note that JSON Schema draft 3 is not supported at the moment. There are also a few important limitations, including usage of external schema references, listed under [Caveats and limitations](#caveats-and-limitations).

Based on https://github.com/vlas-voloshin/JSONSchemaValidation

## Requirements

`DSJSONSchemaValidation` currently supports building in Xcode 7.0 or later with ARC enabled. Minimum supported target platform versions are iOS 7.0, tvOS 9.0 and OS X 10.9. Library can be linked to Objective-C and Swift targets.

## Installation

### Carthage

1. Add the following line to your `Cartfile`:

    ```
    github "dashevo/JSONSchemaValidation"
    ```
    
2. Follow the instructions outlined in [Carthage documentation](https://github.com/Carthage/Carthage/blob/master/README.md) to build and integrate the library into your app.
3. Import library header in your source files:
	* Objective-C: `#import <DSJSONSchemaValidation/DSJSONSchemaValidation.h>`
	* Swift: `import DSJSONSchemaValidation`

### CocoaPods

1. Add the following line to your `Podfile`:

	```
	pod 'DSJSONSchemaValidation'
	```
	
2. Import library header in your source files:
	* Objective-C: `#import <DSJSONSchemaValidation/DSJSONSchema.h>`
	* Swift: `import DSJSONSchemaValidation`

### Framework (iOS 8.0+, tvOS and OS X)

1. Download and copy the repository source files into your project, or add it as a submodule to your git repository.
2. Drag&drop `DSJSONSchemaValidation.xcodeproj` into your project or workspace in Xcode.
3. In "General" tab of Project Settings → `Your Target`, you might find that Xcode has added a missing framework item in "Embedded Binaries". Delete it for now.
4. Still in "General" tab, add `DSJSONSchemaValidation.framework` from `DSJSONSchemaValidation-iOS`, `DSJSONSchemaValidation-tvOS` or `DSJSONSchemaValidation-OSX` target (depending on your target platform) to "Embedded Binaries". This should also add it to "Linked Frameworks and Libraries". 
5. Import library header in your source files:
	* Objective-C: `#import <DSJSONSchemaValidation/DSJSONSchemaValidation.h>`
	* Swift: `import DSJSONSchemaValidation`

### Static library (iOS)

1. Download and copy the repository source files into your project, or add it as a submodule to your git repository.
2. Drag&drop `DSJSONSchemaValidation.xcodeproj` into your project or workspace in Xcode.
3. In "General" section of Project Settings → `Your Target`, you might find that Xcode has added a missing framework item in "Embedded Binaries". Delete it for now.
4. Still in "General" tab, add `libDSJSONSchemaValidation.a` to "Linked Frameworks and Libraries".
5. Add project path to `Your Target` → Build Settings → Header Search Paths (e.g. `"$(SRCROOT)/MyAwesomeProject/Vendor/DSJSONSchemaValidation/"`).
6. Add `-ObjC` flag to `Your Target` → Build Settings → Other Linker Flags to ensure that categories defined in the static library are loaded.
7. Import library header in your source files:
	* Objective-C: `#import <DSJSONSchemaValidation/DSJSONSchema.h>`
	* Swift: `import DSJSONSchemaValidation`

### Source files

1. Download and copy the repository source files into your project, or add it as a submodule to your git repository.
2. Add the contents of `DSJSONSchemaValidation` directory into your project in Xcode.
3. Import library header: `#import "DSJSONSchema.h"`.

## Usage

After importing the library header/module, use `DSJSONSchema` class to construct schema objects from `NSData` instances:

``` objective-c
NSData *schemaData = [NSData dataWithContentsOfURL:mySchemaURL];
NSError *error = nil;
DSJSONSchema *schema = [DSJSONSchema schemaWithData:schemaData baseURI:nil referenceStorage:nil specification:[DSJSONSchemaSpecification draft4] error:&error];
```
``` swift
if let schemaData = NSData(contentsOfURL: mySchemaURL) {
    let schema = try? DSJSONSchema(data: schemaData, baseURI: nil, referenceStorage: nil, specification:DSJSONSchemaSpecification.draft4())
}
```

or from parsed JSON instances:

``` objective-c
NSData *schemaData = [NSData dataWithContentsOfURL:mySchemaURL];
// note that this object might be not an NSDictionary if schema JSON is invalid
NSDictionary *schemaJSON = [NSJSONSerialization JSONObjectWithData:schemaData options:0 error:NULL];
NSError *error = nil;
DSJSONSchema *schema = [DSJSONSchema schemaWithObject:schemaJSON baseURI:nil referenceStorage:nil specification:[DSJSONSchemaSpecification draft4] error:&error];
```
``` swift
if let schemaData = NSData(contentsOfURL: mySchemaURL),
    schemaJSON = try? NSJSONSerialization.JSONObjectWithData(schemaData, options: [ ]),
    schemaDictionary = schemaJSON as? [String : AnyObject] {
    let schema = try? DSJSONSchema(object: schemaDictionary, baseURI: nil, referenceStorage: nil, specification: DSJSONSchemaSpecification.draft4())
}
```

Optional `baseURI` parameter specifies the base scope resolution URI of the constructed schema. Default scope resolution URI is empty.
Optional `referenceStorage` parameter specifies a `DSJSONSchemaStorage` object that should contain "remote" schemas referenced in the instantiated schema. See [Schema storage and external references](#schema-storage-and-external-references) for more details.

After constructing a schema object, you can use it to validate JSON instances. Again, these instances could be provided either as `NSData` objects:

``` objective-c
NSData *jsonData = [NSData dataWithContentsOfURL:myJSONURL];
NSError *validationError = nil;
BOOL success = [schema validateObjectWithData:jsonData error:&validationError];
```
``` swift
if let jsonData = NSData(contentsOfURL: myJSONURL) {
    do {
        try schema.validateObjectWithData(jsonData)
        // Success
    } catch let validationError as NSError {
        // Failure
    }
}
```

or parsed JSON instances:

``` objective-c
NSData *jsonData = [NSData dataWithContentsOfURL:myJSONURL];
id json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:NULL];
NSError *validationError = nil;
BOOL success = [schema validateObject:json error:&validationError];
```
``` swift
if let jsonData = NSData(contentsOfURL: myJSONURL),
    json = try? NSJSONSerialization.JSONObjectWithData(jsonData, options: [ ]) {
    do {
        try schema.validateObject(json)
        // Success
    } catch let validationError as NSError {
        // Failure
    }
}
```
In case of a validation failure, the `NSError` object will contain the following keys in its `userInfo` dictionary:

* `DSJSONSchemaErrorFailingObjectKey` (`object`) – contains a JSON representation of the object which failed validation.
* `DSJSONSchemaErrorFailingValidatorKey` (`validator`) – references the failed validator object. Its description contains its class and validation parameters.
* `DSJSONSchemaErrorFailingObjectPathKey` (`path`) – contains the full path to the failed object in a form of JSON Pointer. An empty path means that the root-level object failed validation.

### Schema storage and external references

Resolving external schema references from network locations is deliberately not supported by `DSJSONSchema`. However, these external references can be provided using `DSJSONSchemaStorage` class. For example, if Schema A references Schema B at `http://awesome.org/myHandySchema.json`, the latter can be downloaded in advance and provided during instantiation of Schema A:

``` objective-c
// obviously, in a real application, data from a website must not be loaded synchronously like this
NSURL *schemaBURL = [NSURL URLWithString:@"http://awesome.org/myHandySchema.json"];
NSData *schemaBData = [NSData dataWithContentsOfURL:schemaBURL];
DSJSONSchema *schemaB = [DSJSONSchema schemaWithData:schemaBData baseURI:schemaBURL referenceStorage:nil specification:[DSJSONSchemaSpecification draft4] error:NULL];
DSJSONSchemaStorage *referenceStorage = [DSJSONSchemaStorage storageWithSchema:schemaB];

// ... retrieve schemaAData ...

DSJSONSchema *schemaA = [DSJSONSchema schemaWithData:schemaAData baseURI:nil referenceStorage:referenceStorage specification:[DSJSONSchemaSpecification draft4] error:NULL];
```

`DSJSONSchemaStorage` objects can also be used in general to store schemas and retrieve them by their scope URI. Please refer to the documentation of that class in the source code for more information.

## Performance

Note that constructing a `DSJSONSchema` object from a JSON representation incurs some computational cost in case of complex schemas. For this reason, if a single schema is expected to be used for validation multiple times, make sure you cache and reuse the corresponding `DSJSONSchema` object.

On iPhone 5s, `DSJSONSchema` shows the following performance when instantiating and validating against a medium-complexity schema (see [advanced-example.json](DSJSONSchemaValidationTests/JSON/advanced-example.json)):

| Operation                  | Minimum | Average | Maximum |
|----------------------------|---------|---------|---------|
| Instantiation + validation | 4 ms    | 15 ms   | 24 ms   |
| Instantiation only         | 3 ms    | 12 ms   | 20 ms   |
| Validation only            | 1.2 ms  | 3.5 ms  | 5.8 ms  |

Project uses a major part of [JSON Schema Test Suite](https://github.com/json-schema/JSON-Schema-Test-Suite) to test its functionality. Running this suite on 2.3 GHz Intel Core i7 processor shows the following performance:

| Operation                   | Time    |
|-----------------------------|---------|
| Single suite instantiation  | 16.2 ms |
| Average suite instantiation | 10.9 ms |
| First suite validation      | 3.69 ms |
| Average suite validation    | 3.44 ms |

## Extending

Using `+[DSJSONSchema registerValidatorClass:forMetaschemaURI:withError:]` method, custom JSON Schema keywords can be registered for the specified custom metaschema URI that must be present in the `$schema` property of the instantiated root schemas. Schema keywords are validated using objects conforming to `DSJSONSchemaValidator` protocol. Please refer to `DSJSONSchema` class documentation in the source code for more information.

Using `+[DSJSONSchemaFormatValidator registerFormat:withRegularExpression:error:]` and `+[DSJSONSchemaFormatValidator registerFormat:withBlock:error:]` methods, custom format names can be registered to be used in the built-in `format` keyword validator class to validate custom formats without the need to modify library code. Please refer to `DSJSONSchemaFormatValidator` class documentation in the source code for more information.

## Thread safety

`DSJSONSchema` and all objects it is composed of are immutable after being constructed and thus thread-safe, so a single schema can be used to validate multiple JSON documents in parallel threads. It is also possible to construct multiple `DSJSONSchema` instances in separate threads, as long as no thread attempts to register additional schema keywords in the process.

## Caveats and limitations

- Regular expression patterns are validated using `NSRegularExpression`, which uses ICU implementation, not ECMA 262. Thus, some features like look-behind are not supported.
- Loading schema references from external locations is not supported. See [Schema storage and external references](#schema-storage-and-external-references) for more details.
- Schema keywords defined inside a schema reference (object with "$ref" property) are ignored as per [JSON Reference specification draft](https://tools.ietf.org/html/draft-pbryan-zyp-json-ref-03).
- Validation of following formats is not supported: `"uri-template"`, `"json-pointer"`, `"idn-email"`, `"idn-hostname"`, `"iri"`, `"iri-reference"`, `"relative-json-pointer"`. But they can be used as described in [Extending](##Extending) section

## License

`DSJSONSchemaValidation` is available under the MIT license. See the LICENSE file for more info.
