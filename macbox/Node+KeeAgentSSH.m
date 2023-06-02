//
//  Node+KeeAgentSSH.m
//  MacBox
//
//  Created by Strongbox on 26/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import "Node+KeeAgentSSH.h"
#import "Constants.h"

#if TARGET_OS_IPHONE

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

#else

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_AutoFill-Swift.h"
#endif

#endif

@implementation Node (KeeAgentSSH)

- (BOOL)hasEnabledKeeAgentSshPrivateKey {
    KeeAgentSettings* settings = [self getValidatedKeeAgentSettings:nil];
    
    return settings.enabled;
}

- (NSString *)keeAgentSshKeyAttachmentName {
    KeeAgentSettings* settings = [self getValidatedKeeAgentSettings:nil];
    
    return settings.attachmentName;
}

- (BOOL)hasKeeAgentSshPrivateKey {
    KeeAgentSettings* settings = [self getValidatedKeeAgentSettings:nil];
    
    return settings != nil;
}

- (NSData *)keeAgentSshPrivateKeyData {
    return [self getKeeAgentSshPrivateKeyData:NO];
}

- (NSData *)keeAgentEnabledSshPrivateKeyData {
    return [self getKeeAgentSshPrivateKeyData:YES];
}

- (NSData *)getKeeAgentSshPrivateKeyData:(BOOL)onlyIfEnabled {
    KeeAgentSettings* settings = [self getValidatedKeeAgentSettings:nil];
    
    if ( !settings ) {
        NSLog(@"🔴 Node::keeAgentSshPrivateKeyData: Could not get KeeAgentSettings");
        return nil;
    }
    
    if ( onlyIfEnabled && !settings.enabled ) {
        return nil;
    }
    
    KeePassAttachmentAbstractionLayer *attachment = self.fields.attachments[settings.attachmentName];
    if ( attachment == nil ) {
        NSLog(@"🔴 Node::keeAgentSshPrivateKeyData: Could not get KeeAgentSettings");
        return nil;
    }

    return attachment.nonPerformantFullData;
}

- (KeeAgentSettings*)getValidatedKeeAgentSettings:(NSError**)error {
    KeePassAttachmentAbstractionLayer *attachment = self.fields.attachments[kKeeAgentSettingsAttachmentName];
    if ( attachment == nil ) {
        return nil;
    }
    
    NSData* data = attachment.nonPerformantFullData;
    if ( !data ) {
        NSLog(@"🔴 Could not get KeeAgent.settings attachment data!");
        return nil;
    }
    
    NSError* err;
    KeeAgentSettings* settings = [KeeAgentSettings fromData:data error:&err];
    
    if ( settings == nil || err != nil ) {
        NSLog(@"🔴 Could not parse KeeAgent.settings! [%@]", err);
        
        if ( error ) {
            *error = err;
        }
        
        return nil;
    }
    
    if ( settings.attachmentName.length == 0 ) {
        NSLog(@"⚠️ KeeAgent.settings attachment name null or empty. Invalid for Strongbox.");
        return nil;
    }
    
    KeePassAttachmentAbstractionLayer *theKey = self.fields.attachments[settings.attachmentName];
    if ( theKey == nil ) {
        NSLog(@"🔴 Could not find the referenced private key in attachments! Invalid..");
        return nil;
    }
    
    return settings;
}

- (void)removeKeeAgentSshKey {
    if ( self.keeAgentSshKeyAttachmentName ) {
        [self.fields.attachments removeObjectForKey:self.keeAgentSshKeyAttachmentName];
    }
    
    [self.fields.attachments removeObjectForKey:kKeeAgentSettingsAttachmentName];
}

- (void)addKey:(NSString *)filename
   keyFileBlob:(NSData *)keyFileBlob
       enabled:(BOOL)enabled {
    if ( self.fields.attachments[filename] ) { 
        NSLog(@"⚠️ Could not add key - attachment with this name already exists!");
        return;
    }
    
    NSData* keeAgentSettingsData = [self createNewKeeAgentSettingsXml:filename enabled:enabled];
    
    self.fields.attachments[kKeeAgentSettingsAttachmentName] = [[KeePassAttachmentAbstractionLayer alloc] initNonPerformantWithData:keeAgentSettingsData compressed:YES protectedInMemory:YES];
    
    self.fields.attachments[filename] = [[KeePassAttachmentAbstractionLayer alloc] initNonPerformantWithData:keyFileBlob compressed:YES protectedInMemory:YES];
}

- (NSData*)createNewKeeAgentSettingsXml:(NSString*)filename enabled:(BOOL)enabled {
    KeeAgentSettings *settings = [KeeAgentSettings settingsWithAttachmentName:filename enabled:enabled];
    
    return [settings toXmlData];
}

- (void)setKeeAgentSshPrivateKeyEnabled:(BOOL)enabled {
    if ( !self.hasKeeAgentSshPrivateKey ) {
        NSLog(@"🔴 setKeeAgentSshPrivateKeyEnabled called with NO key set!");
        return;
    }
    
    if ( self.hasEnabledKeeAgentSshPrivateKey == enabled ) {
        NSLog(@"⚠️ setKeeAgentSshPrivateKeyEnabled called with same enabled state. NOP.");
        return;
    }
    
    KeeAgentSettings* settings = [self getValidatedKeeAgentSettings:nil];

    settings.enabled = enabled;
    
    NSData* xmlData = [settings toXmlData];
    
    self.fields.attachments[kKeeAgentSettingsAttachmentName] = [[KeePassAttachmentAbstractionLayer alloc] initNonPerformantWithData:xmlData compressed:YES protectedInMemory:YES];
}

@end
