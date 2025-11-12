public with sharing class ClioDataRetrieveService {

    public static final Set<String> MATTER_CUSTOM_FIELDS = New Set<String>{'16042193','16201822','16200232','16200247','16200277','16200292','16265617','16368382','16368397','16262707','16770053'};

    public static void syncUsers(String lastSyncTime) {
        try {
            Map<String, String> params = new Map<String, String>();
            if (String.isNotBlank(lastSyncTime)) {
                params.put('updated_since', lastSyncTime);
            } else{
                String lasTSyncTime1 = ClioIntegrationServiceQueueable.getLastSyncTime('User');
                if(!String.isBlank(lasTSyncTime1)) params.put('updated_since', lasTSyncTime1);
            }
            params.put('fields', 'id,name,first_name,last_name,email,enabled,updated_at');           
            System.enqueueJob(new ClioIntegrationServiceQueueable('/users', params, null));
        } catch (Exception e) {
            System.debug('Error syncing users: ' + e.getMessage());
            throw e;
        }
    }

    public static void syncContacts(String lastSyncTime) {
        try {
            Map<String, String> params = new Map<String, String>();
            if (String.isNotBlank(lastSyncTime)) {
                params.put('updated_since', lastSyncTime);
            } else{
                String lasTSyncTime1 = ClioIntegrationServiceQueueable.getLastSyncTime('Contact');
                if(!String.isBlank(lasTSyncTime1)) params.put('updated_since', lasTSyncTime1);
            }
            params.put('fields', 'id,name,type,first_name,last_name,title,company,primary_email_address,primary_phone_number,created_at,updated_at');           
            System.enqueueJob(new ClioIntegrationServiceQueueable('/contacts', params, null));
        } catch (Exception e) {
            System.debug('Error syncing contacts: ' + e.getMessage());
            throw e;
        }
    }

    public static void syncMatters(String lastSyncTime) {
        try {
            Map<String, String> params = new Map<String, String>();
            String stringParams = '';
            for(String customId : MATTER_CUSTOM_FIELDS){
                if(String.isBlank(stringParams)) {
                    stringParams += 'custom_field_ids[]='+customId;
                } else {
                    stringParams += '&custom_field_ids[]='+customId; 
                }
                //params.put('custom_field_ids[]',customId);
            }
            if (!String.isBlank(stringParams)) params.put('stringParams',stringParams);
            if (String.isNotBlank(lastSyncTime)) {
                params.put('updated_since', lastSyncTime);
            }else{
                String lasTSyncTime1 = ClioIntegrationServiceQueueable.getLastSyncTime('Matter');
                if(!String.isBlank(lasTSyncTime1)) params.put('updated_since', lasTSyncTime1);
            }
            params.put('fields', 'id,display_number,description,status,location,client{id,name},client_reference,responsible_attorney{id,name},open_date,close_date,pending_date,practice_area{name},billable,updated_at,custom_field_values{field_name,value,picklist_option}');
            System.enqueueJob(new ClioIntegrationServiceQueueable('/matters', params, null));
        } catch (Exception e) {
            System.debug('Error syncing matters: ' + e.getMessage());
            throw e;
        }
    }

    public static void syncRelationships(String lastSyncTime) {
        try {
            Map<String, String> params = new Map<String, String>();
            if (String.isNotBlank(lastSyncTime)) {
                params.put('updated_since', lastSyncTime);
            } else{
                String lasTSyncTime1 = ClioIntegrationServiceQueueable.getLastSyncTime('MatterContact');
                if(!String.isBlank(lasTSyncTime1)) params.put('updated_since', lasTSyncTime1);
            }
            params.put('fields', 'id, matter{id},contact{id}');           
            System.enqueueJob(new ClioIntegrationServiceQueueable('/relationships', params, null));
        } catch (Exception e) {
            System.debug('Error syncing mattercontacts: ' + e.getMessage());
            throw e;
        }
    }

    public static void syncTimeEntries(String lastSyncTime) {
        try {
            Map<String, String> params = new Map<String, String>();
            if (String.isNotBlank(lastSyncTime)) {
                params.put('updated_since', lastSyncTime);
            }else{
                String lasTSyncTime1 = ClioIntegrationServiceQueueable.getLastSyncTime('TimeEntry');
                if(!String.isBlank(lasTSyncTime1)) params.put('updated_since', lasTSyncTime1);
            }
            params.put('type', 'TimeEntry');
            params.put('fields', 'id,quantity,price,total,note,date,matter{id,display_number},user{id,name},non_billable,type,created_at,updated_at');
            System.enqueueJob(new ClioIntegrationServiceQueueable('/activities', params, null));
        } catch (Exception e) {
            System.debug('Error syncing time entries: ' + e.getMessage());
            throw e;
        }
    }

    public static void syncBills(String lastSyncTime) {
        try {
            Map<String, String> params = new Map<String, String>();
            if (String.isNotBlank(lastSyncTime)) {
                params.put('updated_since', lastSyncTime);
            }else{
                String lasTSyncTime1 = ClioIntegrationServiceQueueable.getLastSyncTime('Bill');
                if(!String.isBlank(lasTSyncTime1)) params.put('updated_since', lasTSyncTime1);
            }
            params.put('fields', 'id,number,issued_at,due_at,sub_total,total,balance,state,client{id,name},matters{id,display_number},updated_at,kind');
            System.enqueueJob(new ClioIntegrationServiceQueueable('/bills', params, null));
        } catch (Exception e) {
            System.debug('Error syncing bills: ' + e.getMessage());
            throw e;
        }
    }

    public static void syncCalendarEntries(String lastSyncTime) {
        try {
            Map<String, String> params = new Map<String, String>();
            if (String.isNotBlank(lastSyncTime)) {
                params.put('updated_since', lastSyncTime);
            }else{
                String lasTSyncTime1 = ClioIntegrationServiceQueueable.getLastSyncTime('Calendar');
                if(!String.isBlank(lasTSyncTime1)) params.put('updated_since', lasTSyncTime1);
            }
            params.put('fields', 'id,summary,description,start_at,end_at,location,matter{id,display_number},calendar_owner_id,attendees,updated_at');
            System.enqueueJob(new ClioIntegrationServiceQueueable('/calendar_entries', params, null));
        } catch (Exception e) {
            System.debug('Error syncing calendar entries: ' + e.getMessage());
            throw e;
        }
    }

    public static void syncCalendarEntries(String lastSyncTime, String fromDate, String toDate) {
        try {
            Map<String, String> params = new Map<String, String>();
            if (String.isNotBlank(lastSyncTime)) {
                params.put('updated_since', lastSyncTime);
            }
            if (String.isNotBlank(fromDate)) {
                params.put('from',fromDate);
            }
            if (String.isNotBlank(toDate)) {
                params.put('to',toDate);
            }
            params.put('fields', 'id,summary,description,start_at,end_at,location,matter{id,display_number},calendar_owner_id,attendees,updated_at');
            System.enqueueJob(new ClioIntegrationServiceQueueable('/calendar_entries', params, null));
        } catch (Exception e) {
            System.debug('Error syncing calendar entries: ' + e.getMessage());
            throw e;
        }
    }

    public static void syncPayments(String lastSyncTime) {
        try {
            Map<String, String> params = new Map<String, String>();
            if (String.isNotBlank(lastSyncTime)) {
                params.put('updated_since', lastSyncTime);
            }else{
                String lasTSyncTime1 = ClioIntegrationServiceQueueable.getLastSyncTime('Payment');
                if(!String.isBlank(lasTSyncTime1)) params.put('updated_since', lasTSyncTime1);
            }
            params.put('fields', 'id,type,date,amount,description,client{id,name},matter{id,display_number},bill{id,number},allocation,updated_at,source');
            System.enqueueJob(new ClioIntegrationServiceQueueable('/bank_transactions', params, null));
        } catch (Exception e) {
            System.debug('Error syncing payments: ' + e.getMessage());
            throw e;
        }
    }

    public static void syncNotes(String lastSyncTime, String noteType) {
        try {
            Map<String, String> params = new Map<String, String>();
            if (String.isNotBlank(lastSyncTime)) {
                params.put('updated_since', lastSyncTime);
            }else{
                String lasTSyncTime1 = '';
                if(noteType == 'contact'){
                    lasTSyncTime1 = ClioIntegrationServiceQueueable.getLastSyncTime('ContactNotes');
                } else if(noteType == 'matter'){
                    lasTSyncTime1 = ClioIntegrationServiceQueueable.getLastSyncTime('MatterNotes');
                }
                if(!String.isBlank(lasTSyncTime1)) params.put('updated_since', lasTSyncTime1);
            }
            params.put('type',noteType);
            params.put('fields', 'id, subject, detail, date, type, contact{id}, matter{id}');
            System.enqueueJob(new ClioIntegrationServiceQueueable('/notes', params, null));
        } catch (Exception e) {
            System.debug('Error syncing payments: ' + e.getMessage());
            throw e;
        }
    }
}