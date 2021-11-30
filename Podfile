workspace 'StrongBox'

abstract_target 'common-mac' do
    project 'macbox/MacBox.xcodeproj'
    platform :osx, '10.11'
    use_frameworks!

    pod 'libsodium'
    pod 'Down'

    target 'Strongbox' do
    end

    target 'Strongbox-Pro' do
    end

    target 'Strongbox-AutoFill' do
    end

    target 'Strongbox-Pro-AutoFill' do
    end
end

abstract_target 'common-ios' do
    project 'Strongbox.xcodeproj'
    platform :ios, '9.3'
    use_frameworks!

    pod 'libsodium'    
    pod 'Down'
    
    target 'Strongbox-iOS' do
        use_frameworks!

        pod 'ISMessages'
        pod 'MTBBarcodeScanner'
        pod 'ObjectiveDropboxOfficial'
        pod 'OneDriveSDK'
        pod 'GoogleAPIClientForREST/Drive'
        pod 'GoogleSignIn', '5.0.2'
    end

    target 'Strongbox-iOS-Pro' do
        use_frameworks!

        pod 'ISMessages'
        pod 'MTBBarcodeScanner'
        pod 'ObjectiveDropboxOfficial'
        pod 'OneDriveSDK'
        pod 'GoogleAPIClientForREST/Drive'
        pod 'GoogleSignIn', '5.0.2'
    end    

    target 'Strongbox-iOS-SCOTUS' do
        use_frameworks!

        pod 'ISMessages'        
    end    

    target 'Strongbox-iOS-Graphene' do
        use_frameworks!

        pod 'MTBBarcodeScanner'
        pod 'ISMessages'
    end  

    target 'Strongbox-Auto-Fill' do

    end

    target 'Strongbox-Auto-Fill-Pro' do

    end

    target 'Strongbox-Auto-Fill-SCOTUS' do 

    end

    target 'Strongbox-Auto-Fill-Graphene' do 
    
    end
end

