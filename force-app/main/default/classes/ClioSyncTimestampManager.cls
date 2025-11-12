public with sharing class ClioSyncTimestampManager {
    
    // Get the last sync time for a specific object type
    public static DateTime getLastSyncTime(String objectType) {
        List<Clio_Sync_Timestamp__mdt> timestamps = [
            SELECT Last_Sync_Time__c 
            FROM Clio_Sync_Timestamp__mdt 
            WHERE DeveloperName = :objectType 
            LIMIT 1
        ];
        
        if (!timestamps.isEmpty() && timestamps[0].Last_Sync_Time__c != null) {
            return timestamps[0].Last_Sync_Time__c;
        }
        
        return null;
    }
    
    /*
    // Get the last sync time formatted for Clio API
    public static String getLastSyncTimeFormatted(String objectType) {
        DateTime lastSync = getLastSyncTime(objectType);
        if (lastSync != null) {
            return lastSync.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        }
        return null;
    }*/
    
    // Update the last sync time for a specific object type
    // Note: This uses platform events to update Custom Metadata since we can't DML them directly
    public static void updateLastSyncTime(String objectType, DateTime syncTime) {
        // Since we can't update Custom Metadata with DML, we'll use a different approach
        // Store the timestamp in a custom setting instead for real-time updates
        
        Clio_Sync_Settings__c setting = Clio_Sync_Settings__c.getInstance(objectType);
        if (setting == null) {
            setting = new Clio_Sync_Settings__c(
                Name = objectType,
                Last_Sync_Time__c = syncTime
            );
            insert setting;
        } else {
            setting.Last_Sync_Time__c = syncTime;
            update setting;
        }
    }
    
    // Get last sync time from custom setting (fallback to metadata)
    public static DateTime getLastSyncTimeFromSetting(String objectType) {
        Clio_Sync_Settings__c setting = Clio_Sync_Settings__c.getInstance(objectType);
        if (setting != null && setting.Last_Sync_Time__c != null) {
            return setting.Last_Sync_Time__c;
        }
        
        // Fallback to metadata
        return getLastSyncTime(objectType);
    }
    
    // Get formatted sync time from custom setting
    public static String getLastSyncTimeFormattedFromSetting(String objectType) {
        DateTime lastSync = getLastSyncTimeFromSetting(objectType);
        if (lastSync != null) {
            return lastSync.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        }
        return null;
    }
    
    /*
    // Calculate time difference for logging
    public static String getTimeSinceLastSync(String objectType) {
        DateTime lastSync = getLastSyncTimeFromSetting(objectType);
        if (lastSync == null) {
            return 'Never synced';
        }
        
        Long diffMinutes = (DateTime.now().getTime() - lastSync.getTime()) / (1000 * 60);
        
        if (diffMinutes < 60) {
            return diffMinutes + ' minutes ago';
        } else if (diffMinutes < 1440) {
            return (diffMinutes / 60) + ' hours ago';
        } else {
            return (diffMinutes / 1440) + ' days ago';
        }
    }
    
    // Reset all sync times (useful for full resync)
    public static void resetAllSyncTimes() {
        List<String> objectTypes = new List<String>{
            'User', 'Contact', 'Matter', 'TimeEntry', 'Bill', 'Calendar', 'Payment'
        };
        
        List<Clio_Sync_Settings__c> settingsToDelete = new List<Clio_Sync_Settings__c>();
        
        for (String objectType : objectTypes) {
            Clio_Sync_Settings__c setting = Clio_Sync_Settings__c.getInstance(objectType);
            if (setting != null) {
                settingsToDelete.add(setting);
            }
        }
        
        if (!settingsToDelete.isEmpty()) {
            delete settingsToDelete;
        }
        
        System.debug('Reset sync timestamps for all object types');
    }
    
    // Get sync status for all objects
    public static void displaySyncStatus() {
        List<String> objectTypes = new List<String>{
            'User', 'Contact', 'Matter', 'TimeEntry', 'Bill', 'Calendar', 'Payment'
        };
        
        System.debug('\n========== SYNC STATUS REPORT ==========\n');
        
        for (String objectType : objectTypes) {
            DateTime lastSync = getLastSyncTimeFromSetting(objectType);
            String timeSince = getTimeSinceLastSync(objectType);
            
            System.debug(objectType + ': ' + 
                (lastSync != null ? lastSync.formatGMT('yyyy-MM-dd HH:mm:ss') + ' GMT (' + timeSince + ')' : 'Never synced'));
        }
        
        System.debug('\n========================================\n');
    }*/
}