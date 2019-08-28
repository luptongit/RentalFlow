public class clsAssetAvailability {

    
    @future
    public static void InsertAvailability(){

		List<Asset> assets = new List<Asset>();
		assets = [SELECT id, Name FROM Asset LIMIT 100] ;       
        
        for(Asset asset: assets)
        {
           
            date startDate = GetOperationalWindowStart();
            date endDate = GetOperationalWindowEnd();            
            date currCalcDate = startDate;
            
            while(currCalcDate < endDate)
            {
                
                AssetAvailability__b aa =  new AssetAvailability__b();
                // Key
            	aa.Asset__c = asset.id;
                aa.Date__c = currCalcDate;
                
                // Fields
                aa.Initial_Availability__c = GetInitialAvailability(asset.id, currCalcDate);
                aa.DailyDrawDown__c = GetDailyDrawDown(asset.id, currCalcDate);
                aa.DailyAddition__c = GetDailyAddition(asset.id, currCalcDate);
                aa.Daily_Final__c = GetFinalAvailability(asset.id, currCalcDate);
                
                database.insertImmediate(aa);
                
                currCalcDate = currCalcDate.addDays(1);
            }
        }
        
    }
    
    public static date GetOperationalWindowStart(){return system.today();}
    public static date GetOperationalWindowEnd(){return system.today().addDays(365);}
    
    
    public static double GetInitialAvailability(id assetId, date dateInQuestion){
        
        return 333;
    }
    
    public static double GetDailyDrawDown(id asset_id, date dateInQuestion){
        return 4444;
    }
    
    public static double GetDailyAddition(id asset_id, date dateInQuestion){
        return 88888;
    }
    
    public static double GetFinalAvailability(id assetId, date dateInQuestion)
    {
        return 55555;
    }
        
    
    public static List<AssetAvailability__b> GetAssetAvailability()
    {
        List<AssetAvailability__b> aa = [SELECT Asset__c, Date__c, Initial_Availability__c, DailyDrawDown__c, DailyAddition__c, Daily_Final__c FROM AssetAvailability__b];
    	return aa;
    }
    
}