-- Server main entry point (intentionally minimal - logic lives in server/backend/*.lua)
LicensesAvailable = {};
local ok, licensesFramework = pcall( function() return exports["tugamars_sna_framework"]:getLicenseTypes()  end )

if(not ok ) then
    print("Failed to get license types from framework export. Check if tugamars_sna_framework is running and has the getLicenseTypes export.")
else
    LicensesAvailable = licensesFramework
end
