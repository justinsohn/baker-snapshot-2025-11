public with sharing class UserAvailabilityController {
    @AuraEnabled(cacheable=true)
    public static List<User> getActiveUsersByPracticeArea() {
        List<User> users = [
            SELECT Id, FirstName, LastName, SmallPhotoUrl, Practice_Area__c, Weekly_Availability__c
            FROM User
            WHERE IsActive = true
            AND Weekly_Availability__c != null
            ORDER BY LastName, FirstName
        ];
        
        return sortUsersByAvailability(users);
    }
    
    @AuraEnabled
    public static List<User> getActiveUsersRefresh() {
        // Non-cacheable version for refresh functionality
        List<User> users = [
            SELECT Id, FirstName, LastName, SmallPhotoUrl, Practice_Area__c, Weekly_Availability__c
            FROM User
            WHERE IsActive = true
            AND Weekly_Availability__c != null
            ORDER BY LastName, FirstName
        ];
        
        return sortUsersByAvailability(users);
    }
    
    private static List<User> sortUsersByAvailability(List<User> users) {
        List<User> greenUsers = new List<User>();
        List<User> yellowUsers = new List<User>();
        List<User> redUsers = new List<User>();
        List<User> otherUsers = new List<User>();
        
        for (User user : users) {
            String availability = user.Weekly_Availability__c;
            if (availability == 'Green') {
                greenUsers.add(user);
            } else if (availability == 'Yellow') {
                yellowUsers.add(user);
            } else if (availability == 'Red') {
                redUsers.add(user);
            } else {
                otherUsers.add(user);
            }
        }
        
        List<User> sortedUsers = new List<User>();
        sortedUsers.addAll(greenUsers);
        sortedUsers.addAll(yellowUsers);
        sortedUsers.addAll(redUsers);
        sortedUsers.addAll(otherUsers);
        
        return sortedUsers;
    }
}