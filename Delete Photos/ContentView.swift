//
//  ContentView.swift
//  photoDeleter
//
//  Created by Haley Bedford on 2026-01-01.
//

//TODO: be able to select where to begin deleting photos --> oldest/newest
//TODO: add video player so users can view video before deletion and not just first frame
//TODO: make pretttyyyy adn kawaiii
//TODO: add fav/heart button. so users can like photos/videos that will get added to favourites album in phone
//TODO: dark mode version only viewable in light mode currently hehe
//TODO: make a proper menu page or something
//TODO: make app icon

import SwiftUI
import Photos

struct ContentView: View {
    
    //Menu for FAQ
    @State private var showFAQ = false
    
    //Button icons
    @State var undoButton = Image(systemName:"arrow.counterclockwise.circle")
    @State var deleteButton = Image(systemName: "xmark.circle")
    @State var massDelete = Image(systemName: "trash.circle")
    @State var keepButton = Image(systemName:"checkmark.circle")
    @State var heartButton = Image(systemName: "heart.circle")
    
    //photo library data (PHPhotoLibrary)
    
    //all photos/videos being cycled through --> assets
    @State private var assets: [PHAsset] = []
    //current displayed assest in frame
    @State private var currentImage: UIImage?
    //index of assest being showd
    @State private var currentIndex: Int = 0
    //all photos and videos marked to be deleted
    @State private var toDelete: [PHAsset] = []
    //stack to undo --> stores assest that waas removed and its index
    @State private var undoStack: [(asset: PHAsset, index: Int)] = []
    
    //Gestures for SWIPIGN
    
    //how far the card is getting moved
    @State private var offset: CGSize = .zero
    //rotation effect for card
    @State private var rotation: Double = 0
    //how far assest must be dragged to count as deleted or keep
    private let swipeThreshold: CGFloat = 100
    
    //get permissions from user to access photo library (either denied/full/limited access)
    func requestPhotoAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Photo permission status: authorized")
                    loadPhotos()
                case .limited:
                    print("Photo permission status: limited")
                    loadPhotos()
                case .denied:
                    print("Photo permission status: denied")
                case .restricted:
                    print("Photo permission status: restricted")
                case .notDetermined:
                    print("Photo permission status: notDetermined")
                @unknown default:
                    print("Photo permission status: unknown")
                }
            }
        }
    }
    
    //Get all assessts (photos and videos) from photo library
    //sorts from newest to oldest automatically
    func loadPhotos() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        //fetches both photo and video
        let result = PHAsset.fetchAssets(with: options)
        
        //convert into array
        var temp: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            temp.append(asset)
        }
        
        assets = temp
        print("Fetched assets count:", assets.count)
        
        //load first assest into frame
        loadCurrentImage()
    }
    
    //load the current image into the frame
    func loadCurrentImage() {
        //error check
        guard !assets.isEmpty else {
            print("No photos found")
            currentImage = nil
            return
        }
        
        //keep index in bounds of array
        if currentIndex >= assets.count {
            currentIndex = 0
        }
        if currentIndex < 0 {
            currentIndex = 0
        }

        let asset = assets[currentIndex]
        
        //get image for this assest (photo for photo or first frame photo for videeo)
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 1200, height: 1200),
            contentMode: .aspectFit,
            options: nil
        ) { image, _ in
            DispatchQueue.main.async{
                self.currentImage = image
                
                //update card frame for next image to default/neutral
                self.offset = .zero
                self.rotation = 0
            }
        }
    }
    
    //get next assest in array
    func nextPhoto() {
        guard !assets.isEmpty else {return}
        currentIndex += 1
        loadCurrentImage()
    }
    
    //marks the current assest for deletion
        //adds it to toDelete
        //push onto stack incase of undo
        //removes it from assets so no longer in array deck
    func toDeleteQueue() {
        guard !assets.isEmpty else {return}
        
        let asset = assets[currentIndex]
        
        //add to be deleted
        toDelete.append(asset)
        
        //save for undo
        undoStack.append((asset: asset, index: currentIndex))
        
        //remove from deck
        assets.remove(at: currentIndex)
        
        //update indexes
        if currentIndex >= assets.count{
            currentIndex = max(assets.count - 1, 0)
        }
        
        loadCurrentImage()

    }
    
    //actually deleted all assets marked in toDelete
    func massDeleteQueue(){
        //error check
        guard !toDelete.isEmpty else {
            print("Nothing queued to delete")
            return
        }
        
        let batch = toDelete
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(batch as NSArray)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    print("Deleted queued photos:", batch.count)
                    //clear toDelete after successful deletion
                    toDelete.removeAll()
                } else {
                    print("Batch delete failed:", error?.localizedDescription ?? "unknown error")
                }
            }
        })
    }
    
    //undo the most recent delete
    //puts the assest back into the deck adn shows it into the frame
    func undoDelete(){
        guard let last = undoStack.popLast() else { return }

        //put photo back where it was in assests
        let insertIndex = min(last.index, assets.count)
        assets.insert(last.asset, at: insertIndex)
        
        toDelete.removeLast()

        // show the restored photo
        currentIndex = insertIndex
        loadCurrentImage()
    }
    
    
    //swipe handling
        //left -> delete
        //right -> keep
    func swipe(){
        if offset.width <= swipeThreshold {
            //left swipe == delete
            toDeleteQueue()
        } else if offset.width >= swipeThreshold {
            //right swipe == keep
            nextPhoto()
        }
        //reset ccard position
        offset = .zero
        rotation = 0
    }
    
        //UI
        var body: some View {
            Spacer()
            //top menu FAQ
            Menu {
                Button("FAQ"){
                   showFAQ = true
                }
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.title)
            }
            VStack {
                Spacer()
                //card frame
                VStack(alignment: .leading, spacing: 20.0){
                    if (assets.count == 0){
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 440)
                            .cornerRadius(15.0)
                            .overlay(Text("No more photos to delete..."))
                    }
                    //adds assest image here
                    else if let img = currentImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 440)
                            .cornerRadius(15.0)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 440)
                            .cornerRadius(15.0)
                            .overlay(Text("Loading photo/video..."))
                    }
                }
                .padding()
                .background(Rectangle()
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .shadow(radius: 15))
                .padding()
                .offset(x: offset.width, y: 0)
                .rotationEffect(.degrees(rotation))
                .gesture(
                    DragGesture()
                        .onChanged {value in
                            //update card position while beinf swiped
                            offset = value.translation
                            rotation = Double(value.translation.width / 15)
                        }
                        .onEnded { _ in
                            //decides keep vs delete based on users swipe
                            swipe()
                        }
                )
                .animation(.spring(), value: offset)
                
                HStack{
                    Spacer()
                    
                    deleteButton
                        .font(.largeTitle)
                        .onTapGesture {
                            print("Deleted tapped on index: ", currentIndex)
                            toDeleteQueue()
                        }
                    Spacer()
                    undoButton
                        .onTapGesture {
                            undoDelete()
                        }
                    Spacer()
                    keepButton
                        .font(.largeTitle)
                        .onTapGesture {
                        print("Keep tapped on index: ", currentIndex)
                        nextPhoto()
                    }
                    Spacer()
                }
                .foregroundColor(.black)
                .font(.title)
                Spacer()
                massDelete
                    .font(.system(size: 50))
                    .onTapGesture {
                    massDeleteQueue()
                }
                    
                Spacer()
            }
            .onAppear(){
                requestPhotoAccess()
            }
            .alert("How it works", isPresented: $showFAQ){
                Button("OK", role: .cancel){ }
            } message: {
                Text("""
                    Swipe right or tap ✓ to keep a photo.
                    Swipe left or tap ✕ to mark it for deletion.
                    Marked photos are NOT deleted right away.
                    Tap the trash button to actually delete all marked photos. 
                    (You will get a confirmation pop up)
                    Use ↩︎ to undo mark for deletion.
                    """)
            }
        }
    }

#Preview {
    ContentView()
}


