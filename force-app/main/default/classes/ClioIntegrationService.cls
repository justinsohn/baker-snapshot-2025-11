public with sharing class ClioIntegrationService {
    private static final String NAMED_CREDENTIAL = 'callout:ClioAPI';
    private static final String BASE_PATH = '';
    private static final Integer DEFAULT_PAGE_SIZE = 300;
    private static final Integer RATE_LIMIT_PER_MINUTE = 50;
    private static final Integer RATE_LIMIT_PER_HOUR = 1000;
    
    public class ClioException extends Exception {}
    
    public class ClioApiResponse {
        public List<Object> data { get; set; }
        public Meta meta { get; set; }
    }
    
    public class Meta {
        public Paging paging { get; set; }
        public Integer records { get; set; }
        public Boolean has_more { get; set; }
        public String cursor { get; set; }
    }
    
    public class Paging {
        public Integer current { get; set; }
        public Integer total { get; set; }
        public String next { get; set; }
        public String previous { get; set; }
    }
    
    public static HttpResponse makeCallout(String endpoint, String method, String body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + BASE_PATH + endpoint);
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
                response.meta = new Meta();
                
                if (metaMap.containsKey('records')) {
                    response.meta.records = (Integer) metaMap.get('records');
                }
                if (metaMap.containsKey('has_more')) {
                    response.meta.has_more = (Boolean) metaMap.get('has_more');
                }
                if (metaMap.containsKey('cursor')) {
                    response.meta.cursor = (String) metaMap.get('cursor');
                }
                
                // Parse paging object if it exists
                if (metaMap.containsKey('paging')) {
                    Map<String, Object> pagingMap = (Map<String, Object>) metaMap.get('paging');
                    response.meta.paging = new Paging();
                    
                    if (pagingMap.containsKey('current')) {
                        response.meta.paging.current = (Integer) pagingMap.get('current');
                    }
                    if (pagingMap.containsKey('total')) {
                        response.meta.paging.total = (Integer) pagingMap.get('total');
                    }
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
    
    public static List<Object> getAllRecords(String endpoint, Map<String, String> params) {
        List<Object> allRecords = new List<Object>();
        String cursor = null;
        Boolean hasMore = true;
        
        if (params == null) {
            params = new Map<String, String>();
        }
        
        params.put('order', 'id(asc)');
        params.put('limit', String.valueOf(DEFAULT_PAGE_SIZE));
        String fullEndpoint = null;
        
        while (hasMore) {
            if (cursor != null) {
                params.put('cursor', cursor);
            }
            
            String queryString = buildQueryString(params);
            if (fullEndpoint == null) {
                fullEndpoint = endpoint + (queryString.length() > 0 ? '?' + queryString : '');
            }
            System.debug('fullEndpoint: ' + fullEndpoint);
            
            HttpResponse res = makeCallout(fullEndpoint, 'GET', null);
            ClioApiResponse apiResponse = parseResponse(res.getBody());
            
            if (apiResponse.data != null) {
                allRecords.addAll(apiResponse.data);
            }
            
            if (apiResponse.meta != null && apiResponse.meta.has_more != null) {
                hasMore = apiResponse.meta.has_more;
                cursor = apiResponse.meta.cursor;
            } else if (apiResponse.meta != null && apiResponse.meta.paging.next != null) {
                fullEndpoint = apiResponse.meta.paging.next.substring(27);
                cursor = apiResponse.meta.cursor;
            } else {
                hasMore = false;
            }
            
            if (Limits.getCallouts() >= Limits.getLimitCallouts() - 1) {
                throw new ClioException('Callout limit reached. Process incomplete.');
            }
        }
        
        return allRecords;
    }
    
    public static String buildQueryString(Map<String, String> params) {
        List<String> paramList = new List<String>();
        for (String key : params.keySet()) {
            if(key == 'page_token'){
                paramList.add(key + '=' +params.get(key));
            } else {
                paramList.add(key + '=' + EncodingUtil.urlEncode(params.get(key), 'UTF-8'));
            }
        }
        return String.join(paramList, '&');
    }
    
    public static String getLastSyncTime(String objectType) {
        return ClioSyncTimestampManager.getLastSyncTimeFormattedFromSetting(objectType);
    }
    
    // Get a single record from the API (for specific resources like balances)
    public static Map<String, Object> getSingleRecord(String endpoint, Map<String, String> params) {
        String queryString = buildQueryString(params != null ? params : new Map<String, String>());
        String fullEndpoint = endpoint + (queryString.length() > 0 ? '?' + queryString : '');
        
        HttpResponse res = makeCallout(fullEndpoint, 'GET', null);
        
        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            
            // For single record endpoints, the data is usually directly in the response or under 'data'
            if (responseMap.containsKey('data')) {
                Object dataObj = responseMap.get('data');
                if (dataObj instanceof Map<String, Object>) {
                    return (Map<String, Object>) dataObj;
                } else if (dataObj instanceof List<Object>) {
                    List<Object> dataList = (List<Object>) dataObj;
                    if (!dataList.isEmpty() && dataList[0] instanceof Map<String, Object>) {
                        return (Map<String, Object>) dataList[0];
                    }
                }
            }
            
            // If no 'data' key, return the whole response
            return responseMap;
        } catch (Exception e) {
            throw new ClioException('Failed to parse single record response: ' + e.getMessage());
        }
    }
}