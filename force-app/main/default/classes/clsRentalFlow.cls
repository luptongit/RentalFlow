public class clsRentalFlow implements Queueable{

    public final Integer NUMBER_OF_DAYS_TO_CALC = 365;
	// Class Level Variables    
	public id c_assetId;
    public double quantityAvailable;
    public List<AssetAvailability__b> c_assetAvailabilityList;
    public List<Rental__c> c_rentalDetails;
    public Map<date, double> c_rentalByIdAndStartDate;
    public Map<date, double> c_rentalByIdAndEndDate;
    public date c_startDate;
    public date c_endDate;    
    
    // Constructor
    public clsRentalFlow(List<Rental__c> rentals){
        c_rentalDetails = rentals;
        // InitializeClassVariables();
        
    }
    
    public void execute(QueueableContext context) { CalculateAndSaveAssetAvailability(c_rentalDetails); }
    
    // Init
    private void InitializeClassVariables(){
        quantityAvailable = -1;
        c_assetAvailabilityList = new List<AssetAvailability__b>();
        c_rentalDetails = new List<Rental__c>();
        c_rentalByIdAndStartDate = new Map<date, double>();
    	c_rentalByIdAndEndDate = new Map<date, double>();
        c_startDate = GetOperationalWindowStart();
        c_endDate = GetOperationalWindowEnd();   
    }
    
    // Single Asset Calculation
    // To be called by Unit test etc
    public void CalculateAndSaveAssetAvailability(id assetId){
       
        List<Rental__c> rentals = new List<Rental__c>();
        Rental__c rental = new Rental__c();
        rental.Id = assetId;
        rentals.Add(rental);
        CalculateAndSaveAssetAvailability(rentals);
    }
    
    // Takes the list of Rentals that changed (Like from a trigger)
    // Loops through to get the affected Assets so time series calculations
    //  can be done that will store daily availability of each asset
    public void CalculateAndSaveAssetAvailability(List<Rental__c> rentals){
        
        for(Rental__c rental: rentals){
            c_assetId = rental.Rental_Asset__c;
            InitializeClassVariables();
            // Logic
            GetAssetRentals();
            CalculateAssetAvailability();
            // DeleteOldAvailability();
            SaveAssetsToDatabase();
        }
    }
    
    
    
    // Adding Asset Details to Memory so we don't have to query over and over
    //  * Really it's just an array of Dates and Quantities for a particular asset
    //  * Put into a Map Object for easy retrieval and use in memory
    //  Start Date Quantities are how much to draw down the inventory
    //  End Date Quantities are how much inventory is getting added back
    private void GetAssetRentals(){
        c_rentalDetails = [SELECT id, Rental_Asset__c, Quantity__c, Start_Date__c , End_Date__c	  
                           FROM Rental__c  
                           WHERE Rental_Asset__c = :c_assetId 
                            AND (
                           		(Start_Date__c >= :c_startDate 
                                    AND Start_Date__c <= :c_endDate)
                                OR
                                (End_Date__c >= :c_startDate 
                                    AND End_Date__c <= :c_endDate)
                            	)
                          
                          ];
        
         for(Rental__c rentalDetail: c_rentalDetails)
         {
                        
             double startDateQuantity = c_rentalByIdAndStartDate.get(rentalDetail.Start_Date__c);
             if(startDateQuantity == null)
             {
                 c_rentalByIdAndStartDate.put(rentalDetail.Start_Date__c, rentalDetail.Quantity__c);
             }
             else
             {
                 c_rentalByIdAndStartDate.put(rentalDetail.Start_Date__c, rentalDetail.Quantity__c + startDateQuantity);
             }
             
             double endDateQuantity = c_rentalByIdAndEndDate.get(rentalDetail.End_Date__c);
             if(startDateQuantity == null)
             {
                 c_rentalByIdAndEndDate.put(rentalDetail.End_Date__c, rentalDetail.Quantity__c);
             }
             else
             {
                 c_rentalByIdAndEndDate.put(rentalDetail.End_Date__c, rentalDetail.Quantity__c + endDateQuantity);
             }
             
			            
         }
        
        
    }
    
    // Take the cached data and figure out for each date in the date range
    //  what is the starting quantity, draw downs, additions, final quantity
    private void CalculateAssetAvailability(){
        
        date currCalcDate = c_startDate;
        quantityAvailable = GetInitialAvailability(currCalcDate);
        // Foreach Date in our window
        while(currCalcDate < c_endDate)
        {                
            AssetAvailability__b aa =  new AssetAvailability__b();
            // Key
            aa.Asset__c = c_assetId;
            aa.Date__c = currCalcDate;
            
            // Fields
            aa.Initial_Availability__c = quantityAvailable;
            aa.DailyDrawDown__c = GetDailyDrawDown(currCalcDate);
            aa.DailyAddition__c = GetDailyAddition(currCalcDate);
            aa.Daily_Final__c = aa.Initial_Availability__c - aa.DailyDrawDown__c + aa.DailyAddition__c; // GetFinalAvailability(asset_id, currCalcDate);
            
            c_assetAvailabilityList.add(aa);
            
            // Set Available for tomorrow, the Final for Today
            quantityAvailable = aa.Daily_Final__c;
            
            currCalcDate = currCalcDate.addDays(1);
        }
    }
    
    // Get initial quantity from yesterdays final quantity 
    //   or if that doesn't exist, straight from the asset quantity
    private double GetInitialAvailability(date calcDate){
        
        double retVal = 0;
        date dayBefore = calcDate.addDays(-1);
		// Check Yesterday's Final
        List<AssetAvailability__b> aa = [SELECT Daily_Final__c FROM AssetAvailability__b WHERE Asset__c = :c_assetId AND Date__c = :dayBefore LIMIT 1];
		if (aa.IsEmpty())
        {
            // Get Default Availability From Asset
            retVal = [SELECT Id, Quantity FROM Asset WHERE Id = :c_assetId].Quantity;
        }
        else
        {
            // Use Yesterday's Final
            retVal = aa[0].Daily_Final__c;
        }
        
        return retVal;
    }
    
    private double GetDailyDrawDown(date calcDate){
            
        double totalFromEvents = c_rentalByIdAndStartDate.get(calcDate);
    
        return (totalFromEvents == null) ? 0 : totalFromEvents;
        
    }
    
    private double GetDailyAddition(date calcDate){
        double totalFromEvents = c_rentalByIdAndEndDate.get(calcDate);
    
        return (totalFromEvents == null) ? 0 : totalFromEvents;
    }
    
    // Delete Calcuations for Asset
    private void DeleteOldAvailability(){
        List<AssetAvailability__b> assetsToDelete = [SELECT id, Asset__c, Date__c 
                                                     FROM AssetAvailability__b 
                                                     WHERE Asset__c = :c_assetId 
                                                     	AND Date__c >= :c_startDate 
                                                     	AND Date__c <= :c_endDate];
        database.deleteImmediate(assetsToDelete);
    }
    
    // Helper Functions
    private date GetOperationalWindowStart(){return system.today();}
    private date GetOperationalWindowEnd(){return system.today().addDays(NUMBER_OF_DAYS_TO_CALC);}
    
   // ************************************************************************************************************************
   // ************************************************************************************************************************
   // ************************************************************************************************************************
    private void SaveAssetsToDatabase()
    {
        database.insertImmediate(c_assetAvailabilityList);
    }
   // ************************************************************************************************************************
   // ************************************************************************************************************************
   // ************************************************************************************************************************
    
    public List<AssetAvailability__b> GetAssetAvailability()
    {
        List<AssetAvailability__b> aa = [SELECT Asset__c, Date__c, Initial_Availability__c, DailyDrawDown__c, DailyAddition__c, Daily_Final__c FROM AssetAvailability__b];
    	return aa;
    }
    
}