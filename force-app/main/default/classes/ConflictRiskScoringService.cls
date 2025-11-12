/**
 * @description Service class for calculating conflict risk scores
 * Scores range from 0-100 with risk levels: Critical (80+), High (60-79), Medium (40-59), Low (<40)
 */
public with sharing class ConflictRiskScoringService {

    /**
     * @description Calculates risk score for a potential conflict match
     * @param matchType Type of match (Name, Email, Phone, Business, Matter Relationship)
     * @param recordType Type of record matched (Lead, Contact, Account, Matter__c, etc.)
     * @param matterStatus Status of related matter if applicable (Open, Closed, Pending, etc.)
     * @param isMultipleMatch Whether this entity has multiple matches
     * @return Integer risk score 0-100
     */
    public static Integer calculateScore(String matchType, String recordType, String matterStatus, Boolean isMultipleMatch) {
        Integer score = 0;

        // Base score by match type
        if (matchType == 'Email') {
            score = 90; // Exact email match is very high confidence
        } else if (matchType == 'Phone') {
            score = 85; // Exact phone match is high confidence
        } else if (matchType == 'Name') {
            score = 80; // Name match is strong but could have duplicates
        } else if (matchType == 'Business') {
            score = 75; // Business name match is moderately strong
        } else if (matchType == 'Matter Relationship') {
            score = 60; // Related through matter connection
        }

        // Adjust based on record type
        if (recordType == 'Matter__c') {
            score += 10; // Matters are higher risk
        } else if (recordType == 'Contact') {
            score += 5; // Contacts are established relationships
        } else if (recordType == 'Account') {
            score += 5; // Accounts (businesses) are established relationships
        }

        // Adjust based on matter status
        if (String.isNotBlank(matterStatus)) {
            if (matterStatus.equalsIgnoreCase('Open') || matterStatus.equalsIgnoreCase('Active')) {
                score += 20; // Active matter is very high risk
            } else if (matterStatus.equalsIgnoreCase('Pending')) {
                score += 10; // Pending matter is moderate risk
            } else if (matterStatus.equalsIgnoreCase('Closed')) {
                score += 5; // Even closed matters present some risk
            }
        }

        // Adjust for multiple matches
        if (isMultipleMatch) {
            score += 10; // Multiple connections increase risk
        }

        // Cap at 100
        if (score > 100) {
            score = 100;
        }

        return score;
    }

    /**
     * @description Converts numeric risk score to risk level label
     * @param score Risk score 0-100
     * @return String risk level (Critical, High, Medium, Low)
     */
    public static String getRiskLevel(Integer score) {
        if (score >= 80) {
            return 'Critical';
        } else if (score >= 60) {
            return 'High';
        } else if (score >= 40) {
            return 'Medium';
        } else {
            return 'Low';
        }
    }

    /**
     * @description Wrapper class for conflict match results with risk scoring
     */
    public class ConflictMatch {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String recordType { get; set; }
        @AuraEnabled public String matchType { get; set; }
        @AuraEnabled public String matchReason { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public String matterId { get; set; }
        @AuraEnabled public String matterStatus { get; set; }
        @AuraEnabled public Integer riskScore { get; set; }
        @AuraEnabled public String riskLevel { get; set; }
        @AuraEnabled public String nameUrl { get; set; }

        public ConflictMatch() {
            this.riskScore = 0;
            this.riskLevel = 'Low';
        }
    }
}