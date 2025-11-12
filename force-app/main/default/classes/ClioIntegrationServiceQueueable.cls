public class ClioIntegrationServiceQueueable implements Queueable, Database.AllowsCallouts{
    private static final String NAMED_CREDENTIAL = 'callout:ClioAPI';
    private static final Integer DEFAULT_PAGE_SIZE = 200;
    private static final Integer SIZE_OF_LISTS_TO_PARSE = 10000;
    private static final Integer BATCH_SIZE = 2000;

    private String endpoint;
    private Map<String, String> params;
    private Map<String,List<List<Object>>> data;

    public ClioIntegrationServiceQueueable(String endpoint, Map<String, String> params, Map<String,List<List<Object>>> data) {
        this.endpoint = endpoint;
        this.params = params;
        this.data = data;
    }

    public class ClioException extends Exception {}
    
    public class ClioApiResponse {
        public List<Object> data { get; set; }
        public Meta meta { get; set; }
    }
    
    public class Meta {
        public Paging paging { get; set; }
        public Integer records { get; set; }
    }
    
    public class Paging {
        public String previous { get; set; }
        public String next { get; set; }
    }

    
    
    public void execute(QueueableContext context) {
        Map<String,List<List<Object>>> allRecordsMap = this.data == null? new Map<String,List<List<Object>>>() : this.data;
        if(!allRecordsMap.containsKey(this.endpoint)){
            allRecordsMap.put(this.endpoint, new List<List<Object>>{new List<Object>()});
        }
        
        if (this.params == null) {
            this.params = new Map<String, String>();
        }
        
        this.params.put('order', 'id(asc)');
        this.params.put('limit', String.valueOf(DEFAULT_PAGE_SIZE));
        String queryString = buildQueryString(this.params);
        String fullEndpoint = this.endpoint + (queryString.length() > 0 ? '?' + queryString : '');
        
        System.debug('fullEndpoint: ' + fullEndpoint);
        
        HttpResponse res = makeCallout(fullEndpoint, 'GET', null);
        ClioApiResponse apiResponse = parseResponse(res.getBody());
        
        if (apiResponse.data != null) {
            Integer listIndex = allRecordsMap.get(this.endpoint).size() - 1;
            if(allRecordsMap.get(this.endpoint)[listIndex].size() >= SIZE_OF_LISTS_TO_PARSE){
                allRecordsMap.get(this.endpoint).add(new List<Object>());
                listIndex++;
            }
            allRecordsMap.get(this.endpoint)[listIndex].addAll(apiResponse.data);
        }
        
        if (apiResponse.meta != null && apiResponse.meta.paging != null && apiResponse.meta.paging.next != null) { // there are more records to be retrieved
            system.debug('next page: '+apiResponse.meta.paging.next);
            String token = apiResponse.meta.paging.next.substringAfter('page_token=').substringBefore('&');
            System.debug('page_token: '+token);
            this.params.put('page_token', token);
            System.debug('nextEndpoint: '+this.endpoint);
            System.debug('nextParams: '+this.params);
            if(!test.isRunningTest()){
                System.enqueueJob(new ClioIntegrationServiceQueueable(this.endpoint, this.params, allRecordsMap));
            }            
        } else { // there are no more records to retrieve. Now we can process the list of records.
            switch on this.endpoint.removeStart('/').toLowerCase(){
                when 'users'{
                    Integer recordsToparse = 0;
                    for(List<Object> usersList : allRecordsMap.get('/users')){
                        recordsToparse += usersList.size();
                    }
                    system.debug('recordsToparse: '+recordsToparse);
                    Database.executeBatch(new ClioDataSyncService(allRecordsMap.get('/users'), 'users'),BATCH_SIZE);
                }
                when 'contacts'{
                    Integer recordsToparse = 0;
                    for(List<Object> contactList : allRecordsMap.get('/contacts')){
                        recordsToparse += contactList.size();
                    }
                    system.debug('recordsToparse: '+recordsToparse);
                    Database.executeBatch(new ClioDataSyncService(allRecordsMap.get('/contacts'), 'contacts'),BATCH_SIZE);
                }
                when 'matters'{
                    Integer recordsToparse = 0;
                    for(List<Object> recordsList : allRecordsMap.get('/matters')){
                        recordsToparse += recordsList.size();
                    }
                    system.debug('recordsToparse: '+recordsToparse);
                    Database.executeBatch(new ClioDataSyncService(allRecordsMap.get('/matters'), 'matters'),BATCH_SIZE);
                }
                when 'relationships'{
                    Integer recordsToparse = 0;
                    for(List<Object> recordsList : allRecordsMap.get('/relationships')){
                        recordsToparse += recordsList.size();
                    }
                    system.debug('recordsToparse: '+recordsToparse);
                    Database.executeBatch(new ClioDataSyncService(allRecordsMap.get('/relationships'), 'relationships'),BATCH_SIZE);
                }
                when 'activities'{
                    Integer recordsToparse = 0;
                    for(List<Object> recordsList : allRecordsMap.get('/activities')){
                        recordsToparse += recordsList.size();
                    }
                    system.debug('recordsToparse: '+recordsToparse);
                    Database.executeBatch(new ClioDataSyncService(allRecordsMap.get('/activities'), 'activities'),BATCH_SIZE);
                }
                when 'bills'{
                    Integer recordsToparse = 0;
                    for(List<Object> recordsList : allRecordsMap.get('/bills')){
                        recordsToparse += recordsList.size();
                    }
                    system.debug('recordsToparse: '+recordsToparse);
                    Database.executeBatch(new ClioDataSyncService(allRecordsMap.get('/bills'),'bills'),BATCH_SIZE);
                }
                when 'calendar_entries'{
                    Integer recordsToparse = 0;
                    for(List<Object> recordsList : allRecordsMap.get('/calendar_entries')){
                        recordsToparse += recordsList.size();
                    }
                    system.debug('recordsToparse: '+recordsToparse);

                    Database.executeBatch(new ClioDataSyncService(allRecordsMap.get('/calendar_entries'), 'calendar_entries'),BATCH_SIZE);
                }
                when 'bank_transactions'{
                    Integer recordsToparse = 0;
                    for(List<Object> recordsList : allRecordsMap.get('/bank_transactions')){
                        recordsToparse += recordsList.size();
                    }
                    system.debug('recordsToparse: '+recordsToparse);
                    Database.executeBatch(new ClioDataSyncService(allRecordsMap.get('/bank_transactions'),'bank_transactions'),BATCH_SIZE);
                }
                when 'notes'{
                    Integer recordsToparse = 0;
                    for(List<Object> recordsList : allRecordsMap.get('/notes')){
                        recordsToparse += recordsList.size();
                    }
                    system.debug('recordsToparse: '+recordsToparse);
                    if(this.params.get('type') != null){
                        if(this.params.get('type') == 'contact'){
                            Database.executeBatch(new ClioDataSyncService(allRecordsMap.get('/notes'),'contactNotes'),BATCH_SIZE);
                        } else if(this.params.get('type') == 'matter'){
                            Database.executeBatch(new ClioDataSyncService(allRecordsMap.get('/notes'),'matterNotes'),BATCH_SIZE);
                        } 
                    }
                }
            }
        }
        
    }

    public static ClioApiResponse parseResponse(String jsonResponse) {
        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
            ClioApiResponse response = new ClioApiResponse();

            System.debug('responseMap: ' + responseMap);
            
            // Parse data array
            if (responseMap.containsKey('data')) {
                response.data = (List<Object>) responseMap.get('data');
            }
            
            // Parse meta object
            if (responseMap.containsKey('meta')) {
                Map<String, Object> metaMap = (Map<String, Object>) responseMap.get('meta');
                system.debug('responseMeta: '+metaMap);
                response.meta = new Meta();
                
                if (metaMap.containsKey('records')) {
                    response.meta.records = (Integer) metaMap.get('records');
                }               
                // Parse paging object if it exists
                if (metaMap.containsKey('paging')) {
                    Map<String, Object> pagingMap = (Map<String, Object>) metaMap.get('paging');
                    response.meta.paging = new Paging();
                    
                    if (pagingMap.containsKey('next')) {
                        response.meta.paging.next = (String) pagingMap.get('next');
                    }
                    if (pagingMap.containsKey('previous')) {
                        response.meta.paging.previous = (String) pagingMap.get('previous');
                    }
                }
            }
            
            return response;
        } catch (Exception e) {
            throw new ClioException('Failed to parse API response: ' + e.getMessage());
        }
    }

    public static String buildQueryString(Map<String, String> params) {
        List<String> paramList = new List<String>();
        for (String key : params.keySet()) {
            if(key == 'page_token'){
                paramList.add(key + '=' +params.get(key));
            } else if(key == 'stringParams'){
                paramList.add(params.get(key));
            }else {
                paramList.add(key + '=' + EncodingUtil.urlEncode(params.get(key), 'UTF-8'));
            }
        }
        return String.join(paramList, '&');
    }

    public static HttpResponse makeCallout(String endpoint, String method, String body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + endpoint);
        req.setMethod(method);
        req.setTimeout(120000);
        
        if (String.isNotBlank(body)) {
            req.setBody(body);
            req.setHeader('Content-Type', 'application/json');
        }
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 429) {
            throw new ClioException('Rate limit exceeded. Please try again later.');
        } else if (res.getStatusCode() >= 400) {
            throw new ClioException('API Error: ' + res.getStatusCode() + ' - ' + res.getBody());
        }
        
        return res;
    }

    public static String getLastSyncTime(String objectType) {
        return ClioSyncTimestampManager.getLastSyncTimeFormattedFromSetting(objectType);
    }
}