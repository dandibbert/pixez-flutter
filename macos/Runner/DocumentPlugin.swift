//
//  DocumentPlugin.swift
//  Runner
//
//  Created by Perol Notsf on 2023/7/28.
//

import Foundation
import Photos
import FlutterMacOS
import IOKit.ps

struct DocumentPlugin {
    static func bind(controller : FlutterViewController){
        let channel = FlutterMethodChannel(name: "com.perol.dev/save",
                                           binaryMessenger: controller.engine.binaryMessenger)
        channel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if call.method == "save"  {
                guard let args = call.arguments as? [String: Any],
                      let data = args["data"] as? FlutterStandardTypedData,
                      let name = args["name"] as? String else {
                    result(FlutterError(
                        code: "invalid_arguments",
                        message: "save requires binary data and a file name",
                        details: nil
                    ))
                    return
                }
                let sData = Data(data.data)
                save(sData, name: name, in: name.contains("sanity") ? "pxez_sanity" : "pxez") { success, error in
                    DispatchQueue.main.async {
                        if let error {
                            result(FlutterError(
                                code: "save_failed",
                                message: error.localizedDescription,
                                details: nil
                            ))
                        } else {
                            result(success)
                        }
                    }
                }
                return
            } else if call.method == "permissionStatus" {
                if #available(macOS 11.0, *) {
                    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                    result(status == .authorized || status == .limited)
                } else {
                    result(PHPhotoLibrary.authorizationStatus() == .authorized)
                }
                return
            } else if call.method == "requestPermission" {
                if #available(macOS 11.0, *) {
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                        DispatchQueue.main.async {
                            result(status == .authorized || status == .limited)
                        }
                    }
                } else {
                    PHPhotoLibrary.requestAuthorization { status in
                        DispatchQueue.main.async {
                            result(status == .authorized)
                        }
                    }
                }
                return
            }
            result(false)
        })
    }
    
    static var picCacheDir: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Pic", isDirectory: true)

    private static func error(_ message: String) -> Error {
        NSError(
            domain: "com.perol.dev.pixez.photos",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
    
    static func save(
        _ data: Data,
        name: String,
        in dir: String,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        let saveToAlbum = {
            createAlbum(albumName: dir, completion: { assetCollection, albumError in
                guard let assetCollection else {
                    completion(false, albumError ?? error("Unable to create the Photos album."))
                    return
                }
                self.save(
                    data: data,
                    name: name,
                    assetCollection: assetCollection,
                    completion: completion
                )
            })
        }

        if #available(macOS 11.0, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if status == .authorized || status == .limited {
                saveToAlbum()
            } else {
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                    guard status == .authorized || status == .limited else {
                        completion(false, error("Photo library access was denied."))
                        return
                    }
                    saveToAlbum()
                }
            }
        } else {
            if PHPhotoLibrary.authorizationStatus() == .authorized {
                saveToAlbum()
            } else {
                PHPhotoLibrary.requestAuthorization { status in
                    guard status == .authorized else {
                        completion(false, error("Photo library access was denied."))
                        return
                    }
                    saveToAlbum()
                }
            }
        }
    }
    
    static func createAlbum(
        albumName: String,
        completion: @escaping (PHAssetCollection?, Error?) -> Void
    ) {
        if let assetCollection = self.findAlbum(name: albumName) {
            completion(assetCollection, nil)
            return
        }
        PHPhotoLibrary.shared().performChanges({
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
        }){ success, error in
            if success, let assetCollection = self.findAlbum(name: albumName) {
                completion(assetCollection, nil)
            } else {
                completion(nil, error ?? self.error("Unable to create the Photos album."))
            }
        }
    }
    
    static func findAlbum(name: String) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", name)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        return collection.firstObject
    }
    
    static func save(
        data: Data,
        name: String,
        assetCollection: PHAssetCollection,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        if !FileManager.default.fileExists(atPath: picCacheDir.path) {
            do{
                try FileManager.default.createDirectory(at: picCacheDir, withIntermediateDirectories: true)
            } catch {
                print("create dir failed => \(picCacheDir.path)")
                completion(false, error)
                return
            }
        }
        
        guard let fileName = name.split(separator: " ").last else {
            completion(false, error("Invalid image file name."))
            return
        }
        print("fileName = \(fileName)")
        
        let fileUrl = picCacheDir.appendingPathComponent("\(fileName)")
        
        do {
            try data.write(to: fileUrl)
            
        } catch {
            completion(false, error)
            return
        }
        
        var preparedAsset = false
        PHPhotoLibrary.shared().performChanges({
            guard let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileUrl) else {
                return
            }
            preparedAsset = true
            let assetPlaceHolder = assetChangeRequest.placeholderForCreatedAsset
            let albumChangeRequest = PHAssetCollectionChangeRequest(for: assetCollection)
            let enumeration: NSArray = assetPlaceHolder == nil ? [] : [assetPlaceHolder!]
            albumChangeRequest?.addAssets(enumeration)
        }, completionHandler: { (success, error) -> Void in
            print("success \(success)")
            do {
                try FileManager.default.removeItem(at: fileUrl)
            } catch {
            }
            if success && preparedAsset {
                completion(true, nil)
            } else {
                completion(false, error ?? self.error("Unable to add the image to Photos."))
            }
        })
    }
}
